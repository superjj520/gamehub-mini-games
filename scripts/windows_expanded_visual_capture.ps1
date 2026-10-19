param(
    [string]$BuildPath = "",
    [string]$EvidenceRoot = "",
    [int]$TimeoutSeconds = 180,
    [string]$BuildManifestPath = "",
    [string]$AssetCatalogPath = "res://tests/asset-runtime-catalog-full-candidates.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = Split-Path -Parent $scriptRoot
if ([string]::IsNullOrWhiteSpace($BuildPath)) {
    $BuildPath = Join-Path $workspaceRoot "build/windows/新时代觉醒者-完整候选.exe"
}
if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
    $EvidenceRoot = Join-Path $workspaceRoot "reference-evidence/candidate-windows-device-qa"
}
if ($TimeoutSeconds -lt 60 -or $TimeoutSeconds -gt 900) {
    throw "TimeoutSeconds 必须在 60 至 900 秒之间"
}
if (-not (Test-Path -LiteralPath $BuildPath -PathType Leaf)) {
    throw "完整候选 Windows 构建不存在：$BuildPath"
}

$buildManifestPath = if ([string]::IsNullOrWhiteSpace($BuildManifestPath)) {
    Join-Path $workspaceRoot "reference-evidence/candidate-runtime/full-candidate-windows-build.json"
} else {
    $BuildManifestPath
}
if (-not (Test-Path -LiteralPath $buildManifestPath -PathType Leaf)) {
    throw "缺少完整候选 Windows 构建清单：$buildManifestPath"
}
$buildManifest = Get-Content -LiteralPath $buildManifestPath -Raw | ConvertFrom-Json
$expandedCaptureScriptPath = Join-Path $workspaceRoot "scripts/capture_expanded_visual_matrix.gd"
if (-not (Test-Path -LiteralPath $expandedCaptureScriptPath -PathType Leaf)) {
    throw "缺少扩展视觉 Godot 采集脚本：$expandedCaptureScriptPath"
}

$expectedIds = @(
    "launcher-cold-boot", "launcher-focus-navigation", "global-crash-recovery-prompt",
    "office-success-feedback", "office-search-loop", "office-failure-overlay", "office-checkpoint-recovery",
    "office-pause-overlay", "global-audio-disabled-fallback", "office-resolution-variants",
    "global-missing-asset-blocked", "city-store-transition", "city-crowd-variants", "city-traffic-near-miss",
    "city-neighborhood-extension", "city-weather-lighting-extension", "city-vehicle-damage-feedback",
    "city-delivery-completion"
)

$runId = "expanded-run-" + (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssfffZ") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
$runDirectory = Join-Path $EvidenceRoot $runId
$expandedDirectory = Join-Path $runDirectory "reference-evidence/expanded-runtime-matrix"
New-Item -ItemType Directory -Force -Path $expandedDirectory | Out-Null

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-PngDimensions([string]$Path) {
    $image = [System.Drawing.Image]::FromFile($Path)
    try {
        return [ordered]@{ width = $image.Width; height = $image.Height }
    } finally {
        $image.Dispose()
    }
}

function Quote-ProcessArgument([string]$Value) {
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Write-RunRecord($Status, $FailureMessage, $Captures) {
    $record = [ordered]@{
        schema_version = 1
        status = $Status
        product_name = "新时代觉醒者"
        visual_status = "unverified"
        build = [ordered]@{
            path = [string]$buildManifest.build.path
            bytes = [int64](Get-Item -LiteralPath $BuildPath).Length
            sha256 = Get-Sha256 $BuildPath
        }
        evidence_contract = [ordered]@{
            source = [ordered]@{
                sha256 = [string]$buildManifest.package.source_sha256
                file_count = [int]$buildManifest.package.source_file_count
            }
            candidate_package = [ordered]@{
                sha256 = [string]$buildManifest.package.sha256
                file_count = [int]$buildManifest.package.file_count
            }
        }
    asset_catalog_path = $AssetCatalogPath
        captured_at = (Get-Date).ToUniversalTime().ToString("o")
        run_directory = $runDirectory
        expanded_matrix_directory = $expandedDirectory
        expected_capture_count = $expectedIds.Count
        captures = @($Captures)
        failure = $FailureMessage
        manual_visual_signoff = "pending"
    }
    $recordPath = Join-Path $runDirectory "windows-expanded-visual-run.json"
    $record | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $recordPath -Encoding UTF8
    return $recordPath
}

$actualBuild = Get-Item -LiteralPath $BuildPath
if ([int64]$actualBuild.Length -ne [int64]$buildManifest.build.bytes) {
    throw "Windows 构建字节数与当前清单不一致：实际 $($actualBuild.Length)；清单 $($buildManifest.build.bytes)"
}
$actualBuildSha256 = Get-Sha256 $BuildPath
if ($actualBuildSha256 -ne ([string]$buildManifest.build.sha256).ToLowerInvariant()) {
    throw "Windows 构建 SHA-256 与当前清单不一致：实际 $actualBuildSha256；清单 $($buildManifest.build.sha256)"
}

$originalExpandedOutput = $env:EXPANDED_VISUAL_OUTPUT_DIR
$originalAssetCatalogPath = $env:REFERENCE_ASSET_CATALOG_PATH
$originalRequireSourceBinding = $env:REFERENCE_MATRIX_REQUIRE_SOURCE_BINDING
$originalSourceFingerprint = $env:REFERENCE_MATRIX_SOURCE_FINGERPRINT
$originalSourceFileCount = $env:REFERENCE_MATRIX_SOURCE_FILE_COUNT
$process = $null
$failureMessage = $null
$rawRecords = $null
try {
    $env:EXPANDED_VISUAL_OUTPUT_DIR = $expandedDirectory
    $env:REFERENCE_ASSET_CATALOG_PATH = $AssetCatalogPath
    $env:REFERENCE_MATRIX_REQUIRE_SOURCE_BINDING = "1"
    $env:REFERENCE_MATRIX_SOURCE_FINGERPRINT = [string]$buildManifest.package.source_sha256
    $env:REFERENCE_MATRIX_SOURCE_FILE_COUNT = [string]$buildManifest.package.source_file_count
    $stdoutPath = Join-Path $runDirectory "expanded-capture.stdout.log"
    $stderrPath = Join-Path $runDirectory "expanded-capture.stderr.log"
    # Start-Process 在 Windows PowerShell 5 中会把参数数组重新拼接成一条命令行；
    # 脚本路径可能位于带空格的解压目录，因此必须显式引用。
    $arguments = @("--script", (Quote-ProcessArgument $expandedCaptureScriptPath), "--quit-after", "1800")
    $process = Start-Process -FilePath $BuildPath -ArgumentList $arguments -WorkingDirectory (Split-Path -Parent $BuildPath) -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
    $finished = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $finished) {
        try { $process.Kill() } catch { }
        throw "扩展视觉采集进程超时：$TimeoutSeconds 秒"
    }
    if ($process.ExitCode -ne 0) {
        throw "扩展视觉采集进程退出码异常：$($process.ExitCode)"
    }
    $rawRecordsPath = Join-Path $expandedDirectory "capture-records.json"
    if (-not (Test-Path -LiteralPath $rawRecordsPath -PathType Leaf)) {
        throw "扩展视觉采集没有生成 capture-records.json"
    }
    $rawRecords = Get-Content -LiteralPath $rawRecordsPath -Raw | ConvertFrom-Json
    if ($null -eq $rawRecords.captures) {
        throw "扩展视觉采集记录缺少 captures 数组"
    }
    $rawIds = @{}
    foreach ($rawCapture in @($rawRecords.captures)) {
        $rawId = [string]$rawCapture.id
        if ([string]::IsNullOrWhiteSpace($rawId)) {
            throw "扩展视觉采集记录存在空 id"
        }
        if ($rawIds.ContainsKey($rawId)) {
            throw "扩展视觉采集记录存在重复 id：$rawId"
        }
        $rawIds[$rawId] = $true
    }
    if ($rawIds.Count -ne $expectedIds.Count) {
        throw "扩展视觉采集原始记录数量异常：实际 $($rawIds.Count)，预期 $($expectedIds.Count)"
    }
    foreach ($expectedId in $expectedIds) {
        if (-not $rawIds.ContainsKey($expectedId)) {
            throw "扩展视觉采集原始记录缺少 id：$expectedId"
        }
    }
} catch {
    $failureMessage = $_.Exception.Message
} finally {
    if ($null -eq $originalExpandedOutput) {
        Remove-Item Env:EXPANDED_VISUAL_OUTPUT_DIR -ErrorAction SilentlyContinue
    } else {
        $env:EXPANDED_VISUAL_OUTPUT_DIR = $originalExpandedOutput
    }
    if ($null -eq $originalAssetCatalogPath) {
        Remove-Item Env:REFERENCE_ASSET_CATALOG_PATH -ErrorAction SilentlyContinue
    } else {
        $env:REFERENCE_ASSET_CATALOG_PATH = $originalAssetCatalogPath
    }
    if ($null -eq $originalRequireSourceBinding) {
        Remove-Item Env:REFERENCE_MATRIX_REQUIRE_SOURCE_BINDING -ErrorAction SilentlyContinue
    } else {
        $env:REFERENCE_MATRIX_REQUIRE_SOURCE_BINDING = $originalRequireSourceBinding
    }
    if ($null -eq $originalSourceFingerprint) {
        Remove-Item Env:REFERENCE_MATRIX_SOURCE_FINGERPRINT -ErrorAction SilentlyContinue
    } else {
        $env:REFERENCE_MATRIX_SOURCE_FINGERPRINT = $originalSourceFingerprint
    }
    if ($null -eq $originalSourceFileCount) {
        Remove-Item Env:REFERENCE_MATRIX_SOURCE_FILE_COUNT -ErrorAction SilentlyContinue
    } else {
        $env:REFERENCE_MATRIX_SOURCE_FILE_COUNT = $originalSourceFileCount
    }
}

if ($null -ne $failureMessage) {
    $recordPath = Write-RunRecord "failed_capture_unverified" $failureMessage @()
    throw "$failureMessage；记录已写入：$recordPath"
}

Add-Type -AssemblyName System.Drawing
$rawById = @{}
foreach ($rawCapture in @($rawRecords.captures)) {
    $rawById[[string]$rawCapture.id] = $rawCapture
}
$captures = New-Object System.Collections.ArrayList
foreach ($captureId in $expectedIds) {
    $pngPath = Join-Path $expandedDirectory "$captureId.png"
    if (-not (Test-Path -LiteralPath $pngPath -PathType Leaf)) {
        $failureMessage = "扩展视觉截图缺失：$captureId"
        break
    }
    $dimensions = Get-PngDimensions $pngPath
    if ($dimensions.width -ne 1280 -or $dimensions.height -ne 720) {
        $failureMessage = "扩展视觉截图尺寸异常：$captureId -> $($dimensions.width)x$($dimensions.height)"
        break
    }
    $rawCapture = $rawById[$captureId]
    [void]$captures.Add([ordered]@{
        id = $captureId
        path = "reference-evidence/expanded-runtime-matrix/$captureId.png"
        asset_catalog_path = $AssetCatalogPath
        scene = if ($null -ne $rawCapture) { [string]$rawCapture.scene } else { "unknown" }
        state_setup = if ($null -ne $rawCapture) { [string]$rawCapture.state_setup } else { "" }
        trace_event_types = if ($null -ne $rawCapture) { @($rawCapture.trace_event_types) } else { @() }
        sha256 = Get-Sha256 $pngPath
        width = $dimensions.width
        height = $dimensions.height
        bytes = [int64](Get-Item -LiteralPath $pngPath).Length
        visual_status = "unverified"
    })
}

if ($null -ne $failureMessage) {
    $recordPath = Write-RunRecord "failed_capture_unverified" $failureMessage @($captures)
    throw "$failureMessage；记录已写入：$recordPath"
}

$normalizedRecords = [ordered]@{
    version = 1
    source = "Windows 真实 Godot 图形运行时扩展状态采集"
    visual_status = "unverified"
    captures = @($captures)
}
$normalizedRecords | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $expandedDirectory "capture-records.json") -Encoding UTF8
$recordPath = Write-RunRecord "unverified_pending_visual_signoff" "" @($captures)
Write-Output "Windows 扩展视觉采集记录已写入：$recordPath"
Write-Output "成功：$($captures.Count)/$($expectedIds.Count)；视觉状态保持 unverified"
