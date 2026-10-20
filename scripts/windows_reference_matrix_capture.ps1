param(
    [string]$BuildPath = "",
    [string]$EvidenceRoot = "",
    [int]$TimeoutSeconds = 120,
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
if (-not (Test-Path -LiteralPath $BuildPath -PathType Leaf)) {
    throw "完整候选 Windows 构建不存在：$BuildPath"
}
if ($TimeoutSeconds -lt 30 -or $TimeoutSeconds -gt 600) {
    throw "TimeoutSeconds 必须在 30 至 600 秒之间"
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

$runId = "matrix-run-" + (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssfffZ") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
$runDirectory = Join-Path $EvidenceRoot $runId
$matrixDirectory = Join-Path $runDirectory "runtime-matrix"
New-Item -ItemType Directory -Force -Path $matrixDirectory | Out-Null

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

$actualBuild = Get-Item -LiteralPath $BuildPath
if ([int64]$actualBuild.Length -ne [int64]$buildManifest.build.bytes) {
    throw "Windows 构建字节数与当前清单不一致：实际 $($actualBuild.Length)；清单 $($buildManifest.build.bytes)"
}
$actualBuildSha256 = Get-Sha256 $BuildPath
if ($actualBuildSha256 -ne ([string]$buildManifest.build.sha256).ToLowerInvariant()) {
    throw "Windows 构建 SHA-256 与当前清单不一致：实际 $actualBuildSha256；清单 $($buildManifest.build.sha256)"
}

$segments = @(
    "city-01", "city-02", "city-03", "city-04", "city-05", "city-06", "city-07", "city-08", "city-09", "city-10", "city-11",
    "office-01", "office-02", "office-03", "office-04", "office-05", "office-06", "office-07", "office-08", "office-09", "office-10"
)

$originalFilter = $env:REFERENCE_MATRIX_FILTER
$originalOutput = $env:REFERENCE_MATRIX_OUTPUT_DIR
$originalRequiredGraphics = $env:REFERENCE_MATRIX_REQUIRED_GRAPHICS
$originalAssetCatalogPath = $env:REFERENCE_ASSET_CATALOG_PATH
$originalRequireSourceBinding = $env:REFERENCE_MATRIX_REQUIRE_SOURCE_BINDING
$originalSourceFingerprint = $env:REFERENCE_MATRIX_SOURCE_FINGERPRINT
$originalSourceFileCount = $env:REFERENCE_MATRIX_SOURCE_FILE_COUNT
$captures = New-Object System.Collections.ArrayList
$failures = New-Object System.Collections.ArrayList

try {
    Add-Type -AssemblyName System.Drawing
    foreach ($segment in $segments) {
        $outputPath = Join-Path $matrixDirectory "$segment.png"
        $stdoutPath = Join-Path $matrixDirectory "$segment.stdout.log"
        $stderrPath = Join-Path $matrixDirectory "$segment.stderr.log"
        Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue

        $env:REFERENCE_MATRIX_FILTER = $segment
        $env:REFERENCE_MATRIX_OUTPUT_DIR = $matrixDirectory
        $env:REFERENCE_MATRIX_REQUIRED_GRAPHICS = "1"
        $env:REFERENCE_ASSET_CATALOG_PATH = $AssetCatalogPath
        $env:REFERENCE_MATRIX_REQUIRE_SOURCE_BINDING = "1"
        $env:REFERENCE_MATRIX_SOURCE_FINGERPRINT = [string]$buildManifest.package.source_sha256
        $env:REFERENCE_MATRIX_SOURCE_FILE_COUNT = [string]$buildManifest.package.source_file_count
        $arguments = @("--script", "res://tests/reference_capture_matrix.gd", "--quit-after", "600")
        $process = Start-Process -FilePath $BuildPath -ArgumentList $arguments -WorkingDirectory (Split-Path -Parent $BuildPath) -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
        $finished = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $finished) {
            try { $process.Kill() } catch { }
            [void]$failures.Add([ordered]@{ id = $segment; reason = "process_timeout" })
            continue
        }
        if ($process.ExitCode -ne 0) {
            [void]$failures.Add([ordered]@{ id = $segment; reason = "process_exit_$($process.ExitCode)" })
            continue
        }
        if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
            [void]$failures.Add([ordered]@{ id = $segment; reason = "png_missing" })
            continue
        }
        $dimensions = Get-PngDimensions $outputPath
        if ($dimensions.width -ne 1280 -or $dimensions.height -ne 720) {
            [void]$failures.Add([ordered]@{ id = $segment; reason = "png_dimensions_$($dimensions.width)x$($dimensions.height)" })
            continue
        }
        [void]$captures.Add([ordered]@{
                id = $segment
                path = "runtime-matrix/$segment.png"
                asset_catalog_path = $AssetCatalogPath
                sha256 = Get-Sha256 $outputPath
                width = $dimensions.width
                height = $dimensions.height
                visual_status = "unverified"
            })
    }
} finally {
    if ($null -eq $originalFilter) { Remove-Item Env:REFERENCE_MATRIX_FILTER -ErrorAction SilentlyContinue } else { $env:REFERENCE_MATRIX_FILTER = $originalFilter }
    if ($null -eq $originalOutput) { Remove-Item Env:REFERENCE_MATRIX_OUTPUT_DIR -ErrorAction SilentlyContinue } else { $env:REFERENCE_MATRIX_OUTPUT_DIR = $originalOutput }
    if ($null -eq $originalRequiredGraphics) { Remove-Item Env:REFERENCE_MATRIX_REQUIRED_GRAPHICS -ErrorAction SilentlyContinue } else { $env:REFERENCE_MATRIX_REQUIRED_GRAPHICS = $originalRequiredGraphics }
    if ($null -eq $originalAssetCatalogPath) { Remove-Item Env:REFERENCE_ASSET_CATALOG_PATH -ErrorAction SilentlyContinue } else { $env:REFERENCE_ASSET_CATALOG_PATH = $originalAssetCatalogPath }
    if ($null -eq $originalRequireSourceBinding) { Remove-Item Env:REFERENCE_MATRIX_REQUIRE_SOURCE_BINDING -ErrorAction SilentlyContinue } else { $env:REFERENCE_MATRIX_REQUIRE_SOURCE_BINDING = $originalRequireSourceBinding }
    if ($null -eq $originalSourceFingerprint) { Remove-Item Env:REFERENCE_MATRIX_SOURCE_FINGERPRINT -ErrorAction SilentlyContinue } else { $env:REFERENCE_MATRIX_SOURCE_FINGERPRINT = $originalSourceFingerprint }
    if ($null -eq $originalSourceFileCount) { Remove-Item Env:REFERENCE_MATRIX_SOURCE_FILE_COUNT -ErrorAction SilentlyContinue } else { $env:REFERENCE_MATRIX_SOURCE_FILE_COUNT = $originalSourceFileCount }
}

$record = [ordered]@{
    schema_version = 1
    status = if ($failures.Count -eq 0) { "unverified_pending_visual_signoff" } else { "failed_capture_unverified" }
    build = [ordered]@{
        path = [string]$buildManifest.build.path
        bytes = [int64]$actualBuild.Length
        sha256 = $actualBuildSha256
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
    captures = @($captures)
    failures = @($failures)
    manual_visual_signoff = "pending"
}
$recordPath = Join-Path $runDirectory "windows-reference-matrix.json"
$record | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $recordPath -Encoding UTF8
Write-Output "Windows 参考矩阵采集记录已写入：$recordPath"
Write-Output "成功：$($captures.Count)/$($segments.Count)；失败：$($failures.Count)；视觉状态保持 unverified"
if ($failures.Count -gt 0) {
    throw "Windows 参考矩阵采集未完成，详见：$recordPath"
}
