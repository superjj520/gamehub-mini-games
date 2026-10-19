param(
    [string]$BuildPath = "",
    [string]$EvidenceRoot = "",
    [int]$WaitSeconds = 5,
    [int]$MatrixTimeoutSeconds = 120,
    [int]$ExpandedTimeoutSeconds = 180,
    [string]$BuildManifestPath = "",
    [string]$AssetCatalogPath = "",
    [ValidateSet("完整候选", "原创边界候选")]
    [string]$BuildKind = "完整候选"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = Split-Path -Parent $scriptRoot
if ([string]::IsNullOrWhiteSpace($BuildPath)) {
    $defaultBuildName = if ($BuildKind -eq "原创边界候选") { "新时代觉醒者-原创边界候选.exe" } else { "新时代觉醒者-完整候选.exe" }
    $BuildPath = Join-Path $workspaceRoot ("build/windows/" + $defaultBuildName)
}
if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
    $defaultEvidenceDirectory = if ($BuildKind -eq "原创边界候选") { "candidate-windows-device-qa-original-only" } else { "candidate-windows-device-qa" }
    $EvidenceRoot = Join-Path $workspaceRoot ("reference-evidence/" + $defaultEvidenceDirectory)
}
if ([string]::IsNullOrWhiteSpace($AssetCatalogPath)) {
    $AssetCatalogPath = if ($BuildKind -eq "原创边界候选") {
        "res://content/asset-runtime-catalog-original-only.json"
    } else {
        "res://tests/asset-runtime-catalog-full-candidates.json"
    }
}
if (-not (Test-Path -LiteralPath $BuildPath -PathType Leaf)) {
    throw "$BuildKind Windows 构建不存在：$BuildPath"
}
if ($MatrixTimeoutSeconds -lt 30 -or $MatrixTimeoutSeconds -gt 600) {
    throw "MatrixTimeoutSeconds 必须在 30 至 600 秒之间"
}
if ($ExpandedTimeoutSeconds -lt 60 -or $ExpandedTimeoutSeconds -gt 900) {
    throw "ExpandedTimeoutSeconds 必须在 60 至 900 秒之间"
}

$buildManifestPath = if ([string]::IsNullOrWhiteSpace($BuildManifestPath)) {
    $defaultBuildManifestName = if ($BuildKind -eq "原创边界候选") {
        "full-candidate-windows-original-only-build.json"
    } else {
        "full-candidate-windows-build.json"
    }
    Join-Path $workspaceRoot ("reference-evidence/candidate-runtime/" + $defaultBuildManifestName)
} else {
    $BuildManifestPath
}
if (-not (Test-Path -LiteralPath $buildManifestPath -PathType Leaf)) {
    throw "缺少 $BuildKind Windows 构建清单：$buildManifestPath"
}
$buildManifest = Get-Content -LiteralPath $buildManifestPath -Raw | ConvertFrom-Json

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-WorkspaceRelativePath([string]$Path) {
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = ([System.IO.Path]::GetFullPath($workspaceRoot)).TrimEnd([char[]]@('\', '/'))
    if ($fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = $fullPath.Substring($fullRoot.Length).TrimStart([char[]]@('\', '/'))
        return ($relative -replace '\\', '/')
    }
    return ($fullPath -replace '\\', '/')
}

function Get-NewestRun([string]$Prefix) {
    if (-not (Test-Path -LiteralPath $EvidenceRoot -PathType Container)) {
        return $null
    }
    $directory = Get-ChildItem -LiteralPath $EvidenceRoot -Directory |
        Where-Object { $_.Name.StartsWith($Prefix) } |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($null -eq $directory) { return $null }
    return $directory.FullName
}

function Invoke-QaStage([string]$Name, [string]$ScriptName, [string[]]$Arguments, [string]$RunPrefix) {
    $stage = [ordered]@{
        name = $Name
        script = "scripts/$ScriptName"
        status = "pending"
        started_at = (Get-Date).ToUniversalTime().ToString("o")
        run_directory = $null
        error = $null
    }
    try {
        $scriptPath = Join-Path $scriptRoot $ScriptName
        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
            throw "缺少 QA 子脚本：$scriptPath"
        }
        $powershell = Get-Command powershell.exe -ErrorAction SilentlyContinue
        if ($null -eq $powershell) {
            $powershell = Get-Command powershell -ErrorAction SilentlyContinue
        }
        if ($null -eq $powershell) {
            throw "找不到 Windows PowerShell"
        }
        & $powershell.Source -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
        if ($exitCode -ne 0) {
            throw "$ScriptName 退出码为 $exitCode"
        }
        $stage.status = "passed_unverified"
    } catch {
        $stage.status = "failed_unverified"
        $stage.error = $_.Exception.Message
    } finally {
        $stage.ended_at = (Get-Date).ToUniversalTime().ToString("o")
        $newestRun = Get-NewestRun $RunPrefix
        if ($null -ne $newestRun) {
            $stage.run_directory = Get-WorkspaceRelativePath $newestRun
        }
    }
    return $stage
}

New-Item -ItemType Directory -Force -Path $EvidenceRoot | Out-Null
$runId = "complete-run-" + (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssfffZ") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
$completeRunDirectory = Join-Path $EvidenceRoot $runId
New-Item -ItemType Directory -Force -Path $completeRunDirectory | Out-Null

$stages = New-Object System.Collections.ArrayList
[void]$stages.Add((Invoke-QaStage "runtime_device_qa" "windows_device_qa.ps1" @(
        "-BuildPath", $BuildPath,
        "-EvidenceRoot", $EvidenceRoot,
        "-WaitSeconds", [string]$WaitSeconds,
        "-BuildManifestPath", $buildManifestPath,
        "-BuildKind", $BuildKind
    ) "run-"))
[void]$stages.Add((Invoke-QaStage "reference_matrix" "windows_reference_matrix_capture.ps1" @(
        "-BuildPath", $BuildPath,
        "-EvidenceRoot", $EvidenceRoot,
        "-TimeoutSeconds", [string]$MatrixTimeoutSeconds,
        "-BuildManifestPath", $buildManifestPath,
        "-AssetCatalogPath", $AssetCatalogPath
    ) "matrix-run-"))
[void]$stages.Add((Invoke-QaStage "expanded_visual_matrix" "windows_expanded_visual_capture.ps1" @(
        "-BuildPath", $BuildPath,
        "-EvidenceRoot", $EvidenceRoot,
        "-TimeoutSeconds", [string]$ExpandedTimeoutSeconds,
        "-BuildManifestPath", $buildManifestPath,
        "-AssetCatalogPath", $AssetCatalogPath
    ) "expanded-run-"))

$failedStageCount = @($stages | Where-Object { $_.status -eq "failed_unverified" }).Count
$actualBuild = Get-Item -LiteralPath $BuildPath
$record = [ordered]@{
    schema_version = 1
    status = if ($failedStageCount -eq 0) { "stages_completed_unverified" } else { "stages_failed_unverified" }
    product_name = "新时代觉醒者"
    visual_status = "unverified"
    target_device_status = "unverified"
    asset_catalog_path = $AssetCatalogPath
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    run_directory = Get-WorkspaceRelativePath $completeRunDirectory
    build = [ordered]@{
        path = [string]$buildManifest.build.path
        bytes = [int64]$actualBuild.Length
        sha256 = Get-Sha256 $BuildPath
    }
    evidence_contract = [ordered]@{
        build_manifest = Get-WorkspaceRelativePath $buildManifestPath
        source = [ordered]@{
            sha256 = [string]$buildManifest.package.source_sha256
            file_count = [int]$buildManifest.package.source_file_count
        }
        candidate_package = [ordered]@{
            sha256 = [string]$buildManifest.package.sha256
            file_count = [int]$buildManifest.package.file_count
        }
    }
    stages = @($stages)
    manual_signoff = [ordered]@{
        visual = "pending"
        keyboard = "pending"
        gamepad = "pending"
        save_load = "pending"
        performance = "pending"
    }
    policy = "编排器只收集当前构建的真实 Windows 证据，不自动通过视觉、输入、存档、性能或发布门禁"
}
$recordPath = Join-Path $completeRunDirectory "windows-complete-qa.json"
$record | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $recordPath -Encoding UTF8
Write-Output "完整 Windows QA 编排记录已写入：$recordPath"
Write-Output "阶段完成：$(@($stages | Where-Object { $_.status -eq 'passed_unverified' }).Count)/$($stages.Count)；视觉状态保持 unverified"
if ($failedStageCount -gt 0) {
    throw "完整 Windows QA 有 $failedStageCount 个阶段失败；详见：$recordPath"
}
