import {execFileSync} from "node:child_process";
import fs from "node:fs";
import {resolveScope} from "./release_scope.mjs";
import {rightsAssetsForScope} from "./release_rights_scope.mjs";

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(relativePath, "utf8"));
}

const report = readJson("docs/readiness-report.json");
const productDecision = readJson("docs/product-baseline-decision.json");
const assets = readJson("docs/asset-production-manifest.json");
const acceptance = readJson("reference-evidence/acceptance-status.json");
const matrix = readJson("reference-evidence/runtime-matrix/manifest.json");
const rights = readJson("gta-reference-runtime/content/rights-manifest.json");
const graphicalCapture = readJson("reference-evidence/candidate-runtime/graphical-capture-readiness.json");
const blockers = [];
const originalOnlyBuildManifest = "reference-evidence/candidate-runtime/full-candidate-windows-original-only-build.json";
const originalOnlyQaBundleManifest = "reference-evidence/candidate-runtime/full-candidate-windows-original-only-qa-bundle.json";
const originalOnlyPackageRoot = "build/internal-full-candidate-original-only";
const requestedScope = resolveScope(productDecision.launch_scope);
if (productDecision.status === "approved" && !requestedScope) {
  blockers.push("已确认产品基线的首发范围不是受支持的机器范围");
}
const selectedAssetIds = new Set(requestedScope?.assetIds ?? assets.slots.map((slot) => slot.id));
const selectedSegmentIds = new Set(requestedScope?.segmentIds ?? acceptance.segments.map((segment) => segment.id));
const selectedAssets = assets.slots.filter((slot) => selectedAssetIds.has(slot.id));
const selectedAcceptance = acceptance.segments.filter((segment) => selectedSegmentIds.has(segment.id));
const selectedCaptures = matrix.captures.filter((capture) => selectedSegmentIds.has(capture.id));

if (requestedScope && selectedAssets.length !== requestedScope.assetIds.length) blockers.push("首发范围引用的资产槽位不完整");
if (requestedScope && selectedAcceptance.length !== requestedScope.segmentIds.length) blockers.push("首发范围引用的参考验收分段不完整");
if (requestedScope && selectedCaptures.length !== requestedScope.segmentIds.length) blockers.push("首发范围引用的运行时截图分段不完整");

if (productDecision.status !== "approved") blockers.push("产品基线尚未获得用户确认");
if (!Array.isArray(productDecision.launch_platforms) || productDecision.launch_platforms.length === 0) blockers.push("首发平台为空");
if (!Array.isArray(productDecision.launch_scope) || productDecision.launch_scope.length === 0) blockers.push("首发范围为空");
if (selectedAssets.some((slot) => slot.status !== "release_candidate" || slot.release_allowed !== true)) blockers.push("首发范围仍有灰盒或未授权资产槽位");
if (selectedAcceptance.some((segment) => segment.visual_status !== "passed")) blockers.push("首发范围仍有参考视觉分段未通过");
if (selectedCaptures.some((capture) => capture.visual_status !== "passed")) blockers.push("首发范围仍有运行时截图未验证项目");
if (graphicalCapture.status === "blocked_by_graphics_capture" || graphicalCapture.summary?.current_matrix_pngs !== graphicalCapture.summary?.required_matrix_pngs) {
  blockers.push("当前版本尚未完成 21 段与源指纹绑定的真实图形 PNG 采集");
}
const launchScopeId = productDecision.launch_scope?.[0];
const requiredRightsAssets = rightsAssetsForScope(rights.assets, launchScopeId);
const blockedRightsAssets = requiredRightsAssets.filter((asset) => asset.release_allowed !== true);
if (blockedRightsAssets.length > 0) {
  blockers.push(`首发范围 ${launchScopeId} 的必需资产仍有未解决的权利阻断：${blockedRightsAssets.map((asset) => asset.id).join("、")}`);
}
if (report.status !== "release_go") blockers.push(`发布准备报告状态为 ${report.status}，不是 release_go`);
if (report.gates.some((gate) => !["passed", "approved"].includes(gate.status))) blockers.push("发布准备报告仍有未通过门禁");

function runStaticCheck(label, script, args, extraEnv = {}) {
  try {
    execFileSync(process.execPath, [script, ...args], {
      cwd: process.cwd(),
      env: {...process.env, ...extraEnv},
      stdio: ["ignore", "pipe", "pipe"],
      encoding: "utf8",
    });
  } catch (error) {
    blockers.push(`${label}未通过`);
    const detail = String(error.stderr ?? error.stdout ?? "").trim().split("\n").filter(Boolean).pop();
    if (detail) console.error(`${label}详情：${detail}`);
  }
}

runStaticCheck("参考媒体证据验证", "scripts/verify_reference_media.mjs", []);
runStaticCheck(
  "原创边界候选包验证",
  "scripts/verify_original_only_candidate_package.mjs",
  [],
  {FULL_CANDIDATE_PACKAGE_ROOT: originalOnlyPackageRoot},
);
runStaticCheck(
  "原创边界 Windows 构建身份验证",
  "scripts/verify_full_candidate_windows_build.mjs",
  [],
  {FULL_CANDIDATE_WINDOWS_MANIFEST: originalOnlyBuildManifest},
);
runStaticCheck(
  "原创边界 Windows QA 包身份验证",
  "scripts/verify_candidate_windows_qa_bundle.mjs",
  [],
  {
    FULL_CANDIDATE_WINDOWS_QA_BUNDLE_MANIFEST: originalOnlyQaBundleManifest,
    FULL_CANDIDATE_WINDOWS_BUILD_MANIFEST: originalOnlyBuildManifest,
    FULL_CANDIDATE_PACKAGE_ROOT: originalOnlyPackageRoot,
  },
);

try {
  execFileSync(process.execPath, ["scripts/verify_store_materials.mjs", "--strict"], {
    cwd: process.cwd(),
    stdio: ["ignore", "pipe", "pipe"],
    encoding: "utf8",
  });
} catch (error) {
  blockers.push("Steam 商店材料严格门禁未通过");
  const detail = String(error.stderr ?? error.stdout ?? "").trim().split("\n").filter(Boolean).pop();
  if (detail) console.error(`商店材料严格核验详情：${detail}`);
}

try {
  execFileSync(process.execPath, ["scripts/verify_windows_device_qa.mjs", "--strict"], {
    cwd: process.cwd(),
    stdio: ["ignore", "pipe", "pipe"],
    encoding: "utf8",
  });
} catch (error) {
  blockers.push("Windows 10/11 目标设备 QA 缺失或尚未完成严格人工签收");
  const detail = String(error.stderr ?? error.stdout ?? "").trim().split("\n").filter(Boolean).pop();
  if (detail) console.error(`Windows 目标设备 QA 严格核验详情：${detail}`);
}

if (blockers.length > 0) {
  console.error(`正式发布前置检查阻断：${blockers.length} 项`);
  for (const blocker of blockers) console.error(`- ${blocker}`);
  process.exit(1);
}

console.log(`正式发布前置检查通过：允许进入已确认平台的导出流程（范围 ${productDecision.launch_scope[0]}）`);
