import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const workspaceRoot = process.cwd();
const bundlePath = path.join(workspaceRoot, process.env.FULL_CANDIDATE_WINDOWS_QA_OUTPUT || "build/新时代觉醒者-完整候选-windows-qa.zip");
const buildManifestPath = path.join(workspaceRoot, process.env.FULL_CANDIDATE_WINDOWS_BUILD_MANIFEST || "reference-evidence/candidate-runtime/full-candidate-windows-build.json");
const qaScriptPath = path.join(workspaceRoot, "scripts/windows_device_qa.ps1");
const referenceMatrixScriptPath = path.join(workspaceRoot, "scripts/windows_reference_matrix_capture.ps1");
const expandedVisualScriptPath = path.join(workspaceRoot, "scripts/windows_expanded_visual_capture.ps1");
const expandedCaptureScriptPath = path.join(workspaceRoot, "scripts/capture_expanded_visual_matrix.gd");
const completeQaScriptPath = path.join(workspaceRoot, "scripts/windows_complete_qa.ps1");
const completeQaVerifierPath = path.join(workspaceRoot, "scripts/verify_windows_complete_qa.mjs");
const completeQaContractPath = path.join(workspaceRoot, "scripts/verify_windows_complete_qa_script_contract.mjs");
const outputPath = path.join(workspaceRoot, process.env.FULL_CANDIDATE_WINDOWS_QA_BUNDLE_MANIFEST || "reference-evidence/candidate-runtime/full-candidate-windows-qa-bundle.json");
const bundleRelativePath = path.relative(workspaceRoot, bundlePath).replaceAll(path.sep, "/");
const buildManifestRelativePath = path.relative(workspaceRoot, buildManifestPath).replaceAll(path.sep, "/");
const bundleExeName = process.env.FULL_CANDIDATE_WINDOWS_BUNDLE_EXE_NAME || "新时代觉醒者-完整候选.exe";
const bundleBuildManifestName = process.env.FULL_CANDIDATE_WINDOWS_BUNDLE_BUILD_MANIFEST_NAME || "full-candidate-windows-build.json";

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

if (!fs.existsSync(bundlePath)) throw new Error("缺少 Windows 内部 QA 包，请先执行对应的 Windows QA 打包命令");
if (!fs.existsSync(buildManifestPath)) throw new Error("缺少 Windows 构建清单");
if (!fs.existsSync(qaScriptPath)) throw new Error("缺少 Windows 设备 QA 脚本");
if (!fs.existsSync(referenceMatrixScriptPath)) throw new Error("缺少 Windows 参考矩阵采集脚本");
if (!fs.existsSync(expandedVisualScriptPath)) throw new Error("缺少 Windows 扩展视觉采集脚本");
if (!fs.existsSync(expandedCaptureScriptPath)) throw new Error("缺少扩展视觉 Godot 采集脚本");
if (!fs.existsSync(completeQaScriptPath)) throw new Error("缺少完整 Windows QA 编排脚本");
if (!fs.existsSync(completeQaVerifierPath)) throw new Error("缺少完整 Windows QA 编排核验脚本");
if (!fs.existsSync(completeQaContractPath)) throw new Error("缺少完整 Windows QA 编排契约核验脚本");

const buildManifest = JSON.parse(fs.readFileSync(buildManifestPath, "utf8"));
const assetCatalogPath = process.env.FULL_CANDIDATE_WINDOWS_ASSET_CATALOG?.trim()
  || (buildManifest.candidate_variant === "original_only"
    ? "res://content/asset-runtime-catalog-original-only.json"
    : "res://tests/asset-runtime-catalog-full-candidates.json");
const stat = fs.statSync(bundlePath);
const manifest = {
  schema_version: 1,
  status: "internal_candidate_windows_qa_bundle_generated",
  product_name: "新时代觉醒者",
  release_allowed: false,
  visual_status: "unverified",
  target_device_status: "unverified",
  asset_catalog_path: assetCatalogPath,
  bundle: {
    path: bundleRelativePath,
    bytes: stat.size,
    sha256: sha256(bundlePath),
  },
  executable: {
    path: buildManifest.build.path,
    bytes: buildManifest.build.bytes,
    sha256: buildManifest.build.sha256,
  },
  qa_script: {
    path: "scripts/windows_device_qa.ps1",
    bytes: fs.statSync(qaScriptPath).size,
    sha256: sha256(qaScriptPath),
  },
  reference_matrix_script: {
    path: "scripts/windows_reference_matrix_capture.ps1",
    bytes: fs.statSync(referenceMatrixScriptPath).size,
    sha256: sha256(referenceMatrixScriptPath),
  },
  expanded_visual_script: {
    path: "scripts/windows_expanded_visual_capture.ps1",
    bytes: fs.statSync(expandedVisualScriptPath).size,
    sha256: sha256(expandedVisualScriptPath),
  },
  expanded_capture_script: {
    path: "scripts/capture_expanded_visual_matrix.gd",
    bytes: fs.statSync(expandedCaptureScriptPath).size,
    sha256: sha256(expandedCaptureScriptPath),
  },
  complete_qa_script: {
    path: "scripts/windows_complete_qa.ps1",
    bytes: fs.statSync(completeQaScriptPath).size,
    sha256: sha256(completeQaScriptPath),
  },
  complete_qa_verifier: {
    path: "scripts/verify_windows_complete_qa.mjs",
    bytes: fs.statSync(completeQaVerifierPath).size,
    sha256: sha256(completeQaVerifierPath),
  },
  complete_qa_contract: {
    path: "scripts/verify_windows_complete_qa_script_contract.mjs",
    bytes: fs.statSync(completeQaContractPath).size,
    sha256: sha256(completeQaContractPath),
  },
  package: buildManifest.package,
  evidence_contract: {
    source: {
      sha256: buildManifest.package.source_sha256,
      file_count: buildManifest.package.source_file_count,
    },
    candidate_package: {
      sha256: buildManifest.package.sha256,
      file_count: buildManifest.package.file_count,
    },
  },
  included: [
    "CANDIDATE_PACKAGE_README.md",
    "WINDOWS_DEVICE_QA_RUNBOOK.md",
    `build/windows/${bundleExeName}`,
    "scripts/windows_device_qa.ps1",
    "scripts/windows_reference_matrix_capture.ps1",
    "scripts/windows_expanded_visual_capture.ps1",
    "scripts/capture_expanded_visual_matrix.gd",
    "scripts/windows_complete_qa.ps1",
    "scripts/verify_windows_complete_qa.mjs",
    "scripts/verify_windows_complete_qa_script_contract.mjs",
    `reference-evidence/candidate-runtime/${bundleBuildManifestName}`,
  ],
  manual_signoff: {
    visual: "pending",
    keyboard: "pending",
    gamepad: "pending",
    save_load: "pending",
    performance: "pending",
  },
};

fs.writeFileSync(outputPath, JSON.stringify(manifest, null, 2) + "\n", "utf8");
console.log("Windows 内部 QA 包清单已生成：" + path.relative(workspaceRoot, outputPath) + "；SHA-256 " + manifest.bundle.sha256);
