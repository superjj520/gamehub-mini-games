param(
    [string]$BuildPath = "",
    [string]$EvidenceRoot = "",
    [int]$WaitSeconds = 5,
    [string]$BuildManifestPath = "",
    [ValidateSet("首发候选", "完整候选", "原创边界候选")]
    [string]$BuildKind = "首发候选"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = Split-Path -Parent $scriptRoot
if ([string]::IsNullOrWhiteSpace($BuildPath)) {
    $defaultBuildName = if ($BuildKind -eq "完整候选") {
        "新时代觉醒者-完整候选.exe"
    } elseif ($BuildKind -eq "原创边界候选") {
        "新时代觉醒者-原创边界候选.exe"
    } else {
        "新时代觉醒者-首发候选.exe"
    }
    $BuildPath = Join-Path $workspaceRoot ("build/windows/" + $defaultBuildName)
}
if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
    $defaultEvidenceDirectory = if ($BuildKind -eq "完整候选") {
        "candidate-windows-device-qa"
    } elseif ($BuildKind -eq "原创边界候选") {
        "candidate-windows-device-qa-original-only"
    } else {
        "windows-device-qa"
    }
    $EvidenceRoot = Join-Path $workspaceRoot ("reference-evidence/" + $defaultEvidenceDirectory)
}

$evidenceBase = $EvidenceRoot
$runId = "run-" + (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssfffZ") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
$EvidenceRoot = Join-Path $evidenceBase $runId
$script:cleanupFailures = New-Object System.Collections.ArrayList

if (-not (Test-Path -LiteralPath $BuildPath -PathType Leaf)) {
    throw "Windows $BuildKind 构建不存在：$BuildPath"
}
New-Item -ItemType Directory -Force -Path $EvidenceRoot | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class WindowsDeviceQaNative {
    [StructLayout(LayoutKind.Sequential)]
    public struct Point {
        public int X;
        public int Y;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct Rect {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr hWnd, out Rect rect);
    [DllImport("user32.dll")]
    public static extern bool ClientToScreen(IntPtr hWnd, ref Point point);
}
"@

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-WindowClientBounds($Process) {
    $Process.Refresh()
    if ($Process.MainWindowHandle -eq 0) {
        throw "游戏窗口句柄不可用"
    }
    $clientRect = New-Object WindowsDeviceQaNative+Rect
    if (-not [WindowsDeviceQaNative]::GetClientRect($Process.MainWindowHandle, [ref]$clientRect)) {
        throw "无法读取游戏窗口客户区"
    }
    $origin = New-Object WindowsDeviceQaNative+Point
    if (-not [WindowsDeviceQaNative]::ClientToScreen($Process.MainWindowHandle, [ref]$origin)) {
        throw "无法将游戏窗口客户区转换为屏幕坐标"
    }
    $width = $clientRect.Right - $clientRect.Left
    $height = $clientRect.Bottom - $clientRect.Top
    if ($width -lt 640 -or $height -lt 360) {
        throw "游戏窗口客户区尺寸异常：${width}x${height}"
    }
    return [ordered]@{ x = $origin.X; y = $origin.Y; width = $width; height = $height }
}

function Capture-GameWindow($Process, [string]$Path) {
    $bounds = Get-WindowClientBounds $Process
    $bitmap = New-Object System.Drawing.Bitmap($bounds.width, $bounds.height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($bounds.x, $bounds.y, 0, 0, [System.Drawing.Size]::new($bounds.width, $bounds.height))
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
        $image = [System.Drawing.Image]::FromFile($Path)
        try {
            if ($image.Width -ne $bounds.width -or $image.Height -ne $bounds.height) {
                throw "截图尺寸校验失败：$Path"
            }
        } finally {
            $image.Dispose()
        }
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
    return $bounds
}

function Focus-Process($Process) {
    $shell = New-Object -ComObject WScript.Shell
    for ($index = 0; $index -lt 20; $index++) {
        $Process.Refresh()
        if ($Process.HasExited) { return $false }
        if ($Process.MainWindowHandle -ne 0) {
            $activated = $shell.AppActivate($Process.Id)
            Start-Sleep -Milliseconds 250
            $foreground = [WindowsDeviceQaNative]::GetForegroundWindow()
            return [bool]$activated -and $foreground -eq $Process.MainWindowHandle
        }
        Start-Sleep -Milliseconds 250
    }
    return $false
}

function Send-Action($Process, [string]$Action, [string]$EvidenceName, [System.Collections.IDictionary]$Record) {
    $focused = Focus-Process $Process
    if (-not $focused) {
        $Record.actions += [ordered]@{ action = $Action; status = "window_not_focused" }
        return
    }
    [System.Windows.Forms.SendKeys]::SendWait($Action)
    Start-Sleep -Milliseconds 500
    $screenshotPath = Join-Path $EvidenceRoot "$EvidenceName.png"
    $screenshotBounds = Capture-GameWindow $Process $screenshotPath
    $Record.actions += [ordered]@{
        action = $Action
        status = "sent"
        screenshot = $screenshotPath
        screenshot_sha256 = Get-Sha256 $screenshotPath
        screenshot_width = $screenshotBounds.width
        screenshot_height = $screenshotBounds.height
    }
}

function Start-Game([System.Collections.IDictionary]$Record, [string]$Scenario, [string]$Shortcut) {
    $process = $null
    try {
        $process = Start-Process -FilePath $BuildPath -PassThru
        $Record.processes += [ordered]@{
            scenario = $Scenario
            pid = $process.Id
            started_at = (Get-Date).ToString("o")
        }
        Start-Sleep -Seconds $WaitSeconds
        $process.Refresh()
        if ($process.HasExited) {
            throw "构建启动后异常退出：$Scenario，退出码 $($process.ExitCode)"
        }
        if (-not (Focus-Process $process)) {
            throw "无法确认 $Scenario 启动器窗口位于前台"
        }
        $launcherPath = Join-Path $EvidenceRoot "$Scenario-launcher.png"
        $launcherBounds = Capture-GameWindow $process $launcherPath
        $scenarioRecord = [ordered]@{
            scenario = $Scenario
            shortcut = $Shortcut
            launcher_screenshot = $launcherPath
            launcher_screenshot_sha256 = Get-Sha256 $launcherPath
            launcher_screenshot_width = $launcherBounds.width
            launcher_screenshot_height = $launcherBounds.height
            actions = @()
        }
        Send-Action $process $Shortcut "$Scenario-scene" $scenarioRecord
        Send-Action $process "w" "$Scenario-move" $scenarioRecord
        Send-Action $process "c" "$Scenario-crouch" $scenarioRecord
        Send-Action $process "e" "$Scenario-interact" $scenarioRecord
        Send-Action $process "r" "$Scenario-restart" $scenarioRecord
        Send-Action $process "l" "$Scenario-load" $scenarioRecord
        Send-Action $process "{ESC}" "$Scenario-pause" $scenarioRecord
        $process.Refresh()
        $scenarioRecord.process_alive_after_actions = -not $process.HasExited
        $Record.scenarios += $scenarioRecord
        return $process
    } catch {
        Stop-Safely $process
        throw
    }
}

function Stop-Safely($Process) {
    if ($null -eq $Process) { return }
    try {
        $Process.Refresh()
        if (-not $Process.HasExited) {
            Stop-Process -Id $Process.Id -Force
            $Process.WaitForExit(5000)
            $Process.Refresh()
            if (-not $Process.HasExited) {
                [void]$script:cleanupFailures.Add("进程未能在 5 秒内结束：$($Process.Id)")
            }
        }
    } catch {
        [void]$script:cleanupFailures.Add("进程清理失败：$($Process.Id)；$($_.Exception.Message)")
    }
}

$record = [ordered]@{
    schema_version = 1
    status = "unverified_manual_signoff_required"
    evidence_contract = $null
    build = [ordered]@{
        kind = $BuildKind
        path = $BuildPath
        sha256 = Get-Sha256 $BuildPath
        bytes = (Get-Item -LiteralPath $BuildPath).Length
    }
    system = [ordered]@{
        captured_at = (Get-Date).ToString("o")
        os = [System.Environment]::OSVersion.VersionString
        computer = $env:COMPUTERNAME
        screen = [ordered]@{
            width = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
            height = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
            target_1080p = ([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width -eq 1920 -and [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height -eq 1080)
            scale = $null
        }
        input_devices = @(
            Get-CimInstance Win32_PnPEntity |
                Where-Object { $_.Name -match "gamepad|controller|xbox|dualshock|playstation" } |
                Select-Object -ExpandProperty Name
        )
    }
    processes = @()
    scenarios = @()
    crash_recovery = $null
    manual_signoff = [ordered]@{
        required = $true
        visual = "pending"
        keyboard = "pending"
        gamepad = "pending"
        save_load = "pending"
        performance = "pending"
    }
}

$candidateBuildManifestPath = if ([string]::IsNullOrWhiteSpace($BuildManifestPath)) {
    $defaultBuildManifestName = if ($BuildKind -eq "原创边界候选") {
        "full-candidate-windows-original-only-build.json"
    } else {
        "full-candidate-windows-build.json"
    }
    Join-Path $workspaceRoot ("reference-evidence/candidate-runtime/" + $defaultBuildManifestName)
} else {
    $BuildManifestPath
}
$candidateBuildManifestPath = [System.IO.Path]::GetFullPath($candidateBuildManifestPath)
$workspaceRootFullPath = ([System.IO.Path]::GetFullPath($workspaceRoot)).TrimEnd([char[]]@('\', '/'))
if (-not (Test-Path -LiteralPath $candidateBuildManifestPath -PathType Leaf)) {
    throw "Windows 构建清单不存在：$candidateBuildManifestPath"
}
if (Test-Path -LiteralPath $candidateBuildManifestPath -PathType Leaf) {
    $candidateBuildManifest = Get-Content -LiteralPath $candidateBuildManifestPath -Raw | ConvertFrom-Json
    if ($null -eq $candidateBuildManifest.build -or [string]::IsNullOrWhiteSpace([string]$candidateBuildManifest.build.path)) {
        throw "Windows 构建清单缺少 build.path：$candidateBuildManifestPath"
    }
    if ($null -eq $candidateBuildManifest.build.bytes -or [string]::IsNullOrWhiteSpace([string]$candidateBuildManifest.build.sha256)) {
        throw "Windows 构建清单缺少 build.bytes 或 build.sha256：$candidateBuildManifestPath"
    }
    $actualBuildPath = [System.IO.Path]::GetFullPath($BuildPath)
    $manifestBuildPath = [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot ([string]$candidateBuildManifest.build.path)))
    if (-not [string]::Equals($actualBuildPath, $manifestBuildPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "实际运行构建与清单路径不一致：实际 $actualBuildPath；清单 $manifestBuildPath"
    }
    $actualBuild = Get-Item -LiteralPath $BuildPath
    if ([int64]$actualBuild.Length -ne [int64]$candidateBuildManifest.build.bytes) {
        throw "Windows 构建字节数与清单不一致：实际 $($actualBuild.Length)；清单 $($candidateBuildManifest.build.bytes)"
    }
    $actualBuildSha256 = Get-Sha256 $BuildPath
    if ($actualBuildSha256 -ne ([string]$candidateBuildManifest.build.sha256).ToLowerInvariant()) {
        throw "Windows 构建 SHA-256 与清单不一致：实际 $actualBuildSha256；清单 $($candidateBuildManifest.build.sha256)"
    }
    $buildManifestRecordPath = $candidateBuildManifestPath
    if ($candidateBuildManifestPath.StartsWith($workspaceRootFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $buildManifestRecordPath = $candidateBuildManifestPath.Substring($workspaceRootFullPath.Length).TrimStart([char[]]@('\', '/')) -replace '\\', '/'
    }
    $record.evidence_contract = [ordered]@{
        build_manifest = $buildManifestRecordPath
        source = [ordered]@{
            sha256 = [string]$candidateBuildManifest.package.source_sha256
            file_count = [int]$candidateBuildManifest.package.source_file_count
        }
        candidate_package = [ordered]@{
            sha256 = [string]$candidateBuildManifest.package.sha256
            file_count = [int]$candidateBuildManifest.package.file_count
        }
    }
}

$officeProcess = $null
$cityProcess = $null
$crashProcess = $null
$recoveryProcess = $null
$qaError = $null
try {
    $officeProcess = Start-Game $record "office" "1"
    Stop-Safely $officeProcess

    $cityProcess = Start-Game $record "city" "2"
    Stop-Safely $cityProcess

    $crashProcess = Start-Process -FilePath $BuildPath -PassThru
    Start-Sleep -Seconds $WaitSeconds
    $crashPid = $crashProcess.Id
    Stop-Safely $crashProcess
    if ($script:cleanupFailures.Count -gt 0) {
        throw "崩溃探针进程清理失败，跳过恢复启动"
    }
    Start-Sleep -Seconds 1
    $recoveryProcess = Start-Process -FilePath $BuildPath -PassThru
    try {
        Start-Sleep -Seconds $WaitSeconds
        if (-not (Focus-Process $recoveryProcess)) {
            throw "无法确认异常恢复启动器窗口位于前台"
        }
        $recoveryScreenshot = Join-Path $EvidenceRoot "crash-recovery-launcher.png"
        $recoveryBounds = Capture-GameWindow $recoveryProcess $recoveryScreenshot
        $record.crash_recovery = [ordered]@{
            killed_pid = $crashPid
            relaunched_pid = $recoveryProcess.Id
            screenshot = $recoveryScreenshot
            screenshot_sha256 = Get-Sha256 $recoveryScreenshot
            screenshot_width = $recoveryBounds.width
            screenshot_height = $recoveryBounds.height
            process_alive = -not $recoveryProcess.HasExited
        }
    } finally {
        Stop-Safely $recoveryProcess
    }
} catch {
    $qaError = $_.Exception.Message
} finally {
    foreach ($process in @($officeProcess, $cityProcess, $crashProcess, $recoveryProcess)) { Stop-Safely $process }
}

$record.cleanup_failures = @($script:cleanupFailures)
if ($null -ne $qaError) {
    $record.status = "failed_qa_unverified"
    $record.error = $qaError
} elseif ($script:cleanupFailures.Count -gt 0) {
    $record.status = "failed_cleanup_unverified"
}
$recordPath = Join-Path $EvidenceRoot "windows-device-qa.json"
$record | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $recordPath -Encoding UTF8
Write-Output "Windows 设备 QA 证据已写入：$recordPath"
if ($null -ne $qaError) {
    Write-Output "状态为 failed_qa_unverified：$qaError"
    throw "Windows 设备 QA 失败，详见：$recordPath"
}
if ($script:cleanupFailures.Count -gt 0) {
    Write-Output "状态为 failed_cleanup_unverified；详见：$recordPath"
    throw "Windows 设备 QA 进程清理出现问题，详见：$recordPath"
}
Write-Output "状态保持 unverified_manual_signoff_required；请在 Windows 10/11 目标设备完成人工视觉、输入、存档和性能签收"
