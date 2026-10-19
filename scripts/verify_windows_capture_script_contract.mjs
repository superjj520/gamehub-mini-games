import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const scripts = [
  {
    path: "scripts/windows_reference_matrix_capture.ps1",
    captureContract: "asset_catalog_path = $AssetCatalogPath\n                sha256 = Get-Sha256 $outputPath",
    expectedCatalog: "res://tests/asset-runtime-catalog-full-candidates.json",
  },
  {
    path: "scripts/windows_expanded_visual_capture.ps1",
    captureContract: "asset_catalog_path = $AssetCatalogPath\n        scene = if ($null -ne $rawCapture)",
    expectedCatalog: "res://tests/asset-runtime-catalog-full-candidates.json",
  },
];

for (const entry of scripts) {
  const absolutePath = path.join(root, entry.path);
  const source = fs.readFileSync(absolutePath, "utf8");
  if (!source.includes("asset_catalog_path = $AssetCatalogPath")) {
    throw new Error(`${entry.path} 缺少运行记录资产目录绑定`);
  }
  const bindingCount = (source.match(/asset_catalog_path = \$AssetCatalogPath/g) ?? []).length;
  if (bindingCount < 2) {
    throw new Error(`${entry.path} 没有同时绑定运行记录根节点与逐项截图记录`);
  }
  if (!source.includes(entry.captureContract)) {
    throw new Error(`${entry.path} 的逐项截图记录没有在哈希/状态字段前写入资产目录绑定`);
  }
  if (!source.includes(entry.expectedCatalog)) {
    throw new Error(`${entry.path} 缺少完整候选资产目录默认值`);
  }
  if (!source.includes('$env:REFERENCE_MATRIX_REQUIRE_SOURCE_BINDING = "1"')) {
    throw new Error(`${entry.path} 没有强制开启源码指纹绑定`);
  }
  if (!source.includes('$env:REFERENCE_MATRIX_SOURCE_FINGERPRINT = [string]$buildManifest.package.source_sha256')) {
    throw new Error(`${entry.path} 没有把构建清单源码指纹注入运行时`);
  }
  if (!source.includes('$env:REFERENCE_MATRIX_SOURCE_FILE_COUNT = [string]$buildManifest.package.source_file_count')) {
    throw new Error(`${entry.path} 没有把构建清单源码文件数注入运行时`);
  }
}

console.log(`Windows 视觉采集脚本契约通过：${scripts.length} 个脚本；运行记录与逐项截图均绑定资产目录`);
