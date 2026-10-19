import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const manifestPath = path.join(root, process.env.FULL_CANDIDATE_WINDOWS_QA_BUNDLE_MANIFEST || "reference-evidence/candidate-runtime/full-candidate-windows-qa-bundle.json");
const buildManifestPath = path.join(root, process.env.FULL_CANDIDATE_WINDOWS_BUILD_MANIFEST || "reference-evidence/candidate-runtime/full-candidate-windows-build.json");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const buildManifest = JSON.parse(fs.readFileSync(buildManifestPath, "utf8"));
const expectedAssetCatalogPathByVariant = {
  makehuman: "res://tests/asset-runtime-catalog-full-candidates.json",
  original: "res://tests/asset-runtime-catalog-full-candidates.json",
  original_only: "res://content/asset-runtime-catalog-original-only.json",
};
const expectedAssetCatalogPath = expectedAssetCatalogPathByVariant[buildManifest.candidate_variant]
  || expectedAssetCatalogPathByVariant.makehuman;
const bundledBuildManifestRelativePath = (manifest.included ?? []).find((item) => item.startsWith("reference-evidence/candidate-runtime/") && item.endsWith("-build.json")) || "reference-evidence/candidate-runtime/full-candidate-windows-build.json";
const bundledBuildManifestPath = path.resolve(root, bundledBuildManifestRelativePath);

function hash(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

assert(manifest.schema_version === 1, "QA 包清单 schema_version 必须为 1");
assert(manifest.status === "internal_candidate_windows_qa_bundle_generated", "QA 包清单状态不正确");
assert(manifest.release_allowed === false, "QA 包不得标记为可发布");
assert(manifest.visual_status === "unverified", "QA 包视觉状态必须保持 unverified");
assert(manifest.target_device_status === "unverified", "QA 包目标设备状态必须保持 unverified");
assert(manifest.asset_catalog_path === expectedAssetCatalogPath, "QA 包没有声明包内候选资产目录");

const bundlePath = path.resolve(root, manifest.bundle.path);
const buildPath = path.resolve(root, manifest.executable.path);
const qaScriptPath = path.resolve(root, manifest.qa_script.path);
const referenceMatrixScriptPath = path.resolve(root, manifest.reference_matrix_script.path);
const expandedVisualScriptPath = path.resolve(root, manifest.expanded_visual_script.path);
const expandedCaptureScriptPath = path.resolve(root, manifest.expanded_capture_script.path);
const completeQaScriptPath = path.resolve(root, manifest.complete_qa_script.path);
const completeQaVerifierPath = path.resolve(root, manifest.complete_qa_verifier.path);
const completeQaContractPath = path.resolve(root, manifest.complete_qa_contract.path);
const candidateReadmePath = path.join(root, process.env.FULL_CANDIDATE_PACKAGE_ROOT || "build/internal-full-candidate", "CANDIDATE_PACKAGE_README.md");
assert(fs.existsSync(bundlePath), `QA 压缩包不存在：${manifest.bundle.path}`);
assert(fs.existsSync(buildPath), `QA 包记录的可执行文件不存在：${manifest.executable.path}`);
assert(fs.existsSync(qaScriptPath), `QA 包记录的脚本不存在：${manifest.qa_script.path}`);
assert(fs.existsSync(referenceMatrixScriptPath), `QA 包记录的参考矩阵脚本不存在：${manifest.reference_matrix_script.path}`);
assert(fs.existsSync(expandedVisualScriptPath), `QA 包记录的扩展视觉脚本不存在：${manifest.expanded_visual_script.path}`);
assert(fs.existsSync(expandedCaptureScriptPath), `QA 包记录的扩展视觉 Godot 脚本不存在：${manifest.expanded_capture_script.path}`);
assert(fs.existsSync(completeQaScriptPath), `QA 包记录的完整编排脚本不存在：${manifest.complete_qa_script.path}`);
assert(fs.existsSync(completeQaVerifierPath), `QA 包记录的完整编排核验器不存在：${manifest.complete_qa_verifier.path}`);
assert(fs.existsSync(completeQaContractPath), `QA 包记录的完整编排契约核验器不存在：${manifest.complete_qa_contract.path}`);
const referenceMatrixScriptText = fs.readFileSync(referenceMatrixScriptPath, "utf8");
const expandedVisualScriptText = fs.readFileSync(expandedVisualScriptPath, "utf8");
const expandedCaptureScriptText = fs.readFileSync(expandedCaptureScriptPath, "utf8");
const completeQaScriptText = fs.readFileSync(completeQaScriptPath, "utf8");
assert(referenceMatrixScriptText.includes("AssetCatalogPath") && referenceMatrixScriptText.includes("REFERENCE_ASSET_CATALOG_PATH"), "Windows 参考矩阵脚本没有把资产目录传入 Godot");
assert(expandedVisualScriptText.includes("AssetCatalogPath") && expandedVisualScriptText.includes("REFERENCE_ASSET_CATALOG_PATH"), "Windows 扩展视觉脚本没有把资产目录传入 Godot");
assert(expandedCaptureScriptText.includes("REFERENCE_ASSET_CATALOG_PATH"), "扩展视觉 Godot 脚本没有读取资产目录环境变量");
assert(completeQaScriptText.includes("AssetCatalogPath") && completeQaScriptText.includes("-AssetCatalogPath"), "完整 Windows QA 编排器没有把资产目录传给子阶段");
assert(fs.existsSync(bundledBuildManifestPath), `QA 包清单列出的构建清单不存在：${bundledBuildManifestRelativePath}`);
assert(fs.statSync(bundlePath).size === manifest.bundle.bytes, "QA 压缩包字节数与清单不一致");
assert(hash(bundlePath) === manifest.bundle.sha256, "QA 压缩包 SHA-256 与清单不一致");
assert(fs.statSync(buildPath).size === manifest.executable.bytes, "QA 可执行文件字节数与清单不一致");
assert(hash(buildPath) === manifest.executable.sha256, "QA 可执行文件 SHA-256 与清单不一致");
assert(fs.statSync(qaScriptPath).size === manifest.qa_script.bytes, "QA 脚本字节数与清单不一致");
assert(hash(qaScriptPath) === manifest.qa_script.sha256, "QA 脚本 SHA-256 与清单不一致");
assert(fs.statSync(referenceMatrixScriptPath).size === manifest.reference_matrix_script.bytes, "参考矩阵脚本字节数与清单不一致");
assert(hash(referenceMatrixScriptPath) === manifest.reference_matrix_script.sha256, "参考矩阵脚本 SHA-256 与清单不一致");
assert(fs.statSync(expandedVisualScriptPath).size === manifest.expanded_visual_script.bytes, "扩展视觉脚本字节数与清单不一致");
assert(hash(expandedVisualScriptPath) === manifest.expanded_visual_script.sha256, "扩展视觉脚本 SHA-256 与清单不一致");
assert(fs.statSync(expandedCaptureScriptPath).size === manifest.expanded_capture_script.bytes, "扩展视觉 Godot 脚本字节数与清单不一致");
assert(hash(expandedCaptureScriptPath) === manifest.expanded_capture_script.sha256, "扩展视觉 Godot 脚本 SHA-256 与清单不一致");
assert(fs.statSync(completeQaScriptPath).size === manifest.complete_qa_script.bytes, "完整编排脚本字节数与清单不一致");
assert(hash(completeQaScriptPath) === manifest.complete_qa_script.sha256, "完整编排脚本 SHA-256 与清单不一致");
assert(fs.statSync(completeQaVerifierPath).size === manifest.complete_qa_verifier.bytes, "完整编排核验器字节数与清单不一致");
assert(hash(completeQaVerifierPath) === manifest.complete_qa_verifier.sha256, "完整编排核验器 SHA-256 与清单不一致");
assert(fs.statSync(completeQaContractPath).size === manifest.complete_qa_contract.bytes, "完整编排契约核验器字节数与清单不一致");
assert(hash(completeQaContractPath) === manifest.complete_qa_contract.sha256, "完整编排契约核验器 SHA-256 与清单不一致");

assert(manifest.package?.sha256 === buildManifest.package?.sha256, "QA 包候选包指纹与 Windows 构建清单不一致");
assert(manifest.package?.file_count === buildManifest.package?.file_count, "QA 包候选包文件数与 Windows 构建清单不一致");
assert(manifest.package?.source_sha256 === buildManifest.package?.source_sha256, "QA 包正式源指纹与 Windows 构建清单不一致");
assert(manifest.package?.source_file_count === buildManifest.package?.source_file_count, "QA 包正式源文件数与 Windows 构建清单不一致");
assert(manifest.evidence_contract?.source?.sha256 === buildManifest.package?.source_sha256, "QA 包 evidence_contract 源指纹不一致");
assert(manifest.evidence_contract?.candidate_package?.sha256 === buildManifest.package?.sha256, "QA 包 evidence_contract 候选包指纹不一致");
assert(manifest.executable.sha256 === buildManifest.build.sha256, "QA 包可执行文件与 Windows 构建清单不一致");

for (const relativePath of manifest.included ?? []) {
  const workspacePath = relativePath === "CANDIDATE_PACKAGE_README.md"
    ? candidateReadmePath
    : relativePath === "WINDOWS_DEVICE_QA_RUNBOOK.md"
      ? path.join(root, "docs/windows-device-qa-runbook.md")
    : path.resolve(root, relativePath);
  assert(fs.existsSync(workspacePath), `QA 包清单列出的输入文件不存在：${relativePath}`);
}

const bundledBuildManifest = JSON.parse(fs.readFileSync(bundledBuildManifestPath, "utf8"));
assert(bundledBuildManifest.build?.sha256 === manifest.executable.sha256, "QA 包内 Windows 构建清单与 QA 包可执行文件不一致");
assert(bundledBuildManifest.package?.sha256 === manifest.package?.sha256, "QA 包内候选包指纹与 QA 包清单不一致");
const runbookPath = path.join(root, "docs/windows-device-qa-runbook.md");
const runbookText = fs.readFileSync(runbookPath, "utf8");
assert(runbookText.includes(`当前源码指纹：\`${manifest.package.source_sha256} / ${manifest.package.source_file_count}\``), "Windows 真机手册源码指纹与 QA 包清单不一致");
assert(runbookText.includes("程序 SHA-256 和 QA 包自身 SHA-256 均只以对应候选包内的 Windows 构建清单与包外 QA 清单为准"), "Windows 真机手册没有声明变体构建清单为哈希权威");
const packageHashLine = runbookText.split("\n").find((line) => line.includes("候选包指纹：")) || "";
const executableHashLine = runbookText.split("\n").find((line) => line.includes("程序 SHA-256：")) || "";
assert(packageHashLine.includes("package.sha256") && packageHashLine.includes("手册不重复硬编码候选包哈希"), "Windows 真机手册没有把候选包哈希绑定到构建清单");
assert(executableHashLine.includes("build.sha256") && executableHashLine.includes("手册不重复硬编码程序哈希"), "Windows 真机手册没有把程序哈希绑定到构建清单");
assert(!/候选包指纹：.*\b[a-f0-9]{64}\b/i.test(packageHashLine), "Windows 真机手册仍在候选包哈希字段硬编码 64 位十六进制哈希");
assert(!/程序 SHA-256：.*\b[a-f0-9]{64}\b/i.test(executableHashLine), "Windows 真机手册仍在程序哈希字段硬编码 64 位十六进制哈希");
const candidateReadme = fs.readFileSync(candidateReadmePath, "utf8");
const variantSpecs = {
  makehuman: {label: "完整候选", executable: "新时代觉醒者-完整候选.exe"},
  original: {label: "原创角色候选", executable: "新时代觉醒者-原创角色候选.exe"},
  original_only: {label: "原创边界候选", executable: "新时代觉醒者-原创边界候选.exe"},
};
const variantSpec = variantSpecs[buildManifest.candidate_variant];
if (variantSpec) {
  assert(candidateReadme.includes(`# 《新时代觉醒者》${variantSpec.label}运行包`), "候选包说明标题与构建变体不一致");
  assert(candidateReadme.includes(`build/windows/${variantSpec.executable}`), "候选包说明中的 Windows 程序名称与构建变体不一致");
}

console.log(`Windows 内部 QA 包清单验证通过：${manifest.bundle.path}；候选包 ${manifest.package.file_count} 个文件；release_allowed=false；目标设备仍为 unverified`);
