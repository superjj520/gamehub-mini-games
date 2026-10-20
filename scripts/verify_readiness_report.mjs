import fs from "node:fs";
import {resolveScope} from "./release_scope.mjs";

const report = JSON.parse(fs.readFileSync("docs/readiness-report.json", "utf8"));
const releaseManifest = JSON.parse(fs.readFileSync("docs/release-manifest.json", "utf8"));
const matrix = JSON.parse(fs.readFileSync("reference-evidence/runtime-matrix/manifest.json", "utf8"));
const acceptance = JSON.parse(fs.readFileSync("reference-evidence/acceptance-status.json", "utf8"));
const productDecision = JSON.parse(fs.readFileSync("docs/product-baseline-decision.json", "utf8"));
const requestedScope = resolveScope(productDecision.launch_scope);
const expectedSegmentIds = new Set(requestedScope?.segmentIds ?? acceptance.segments.map((segment) => segment.id));
const expectedAssetIds = new Set(requestedScope?.assetIds ?? []);

if (report.schema_version !== 1) throw new Error("发布准备报告 schema 版本不受支持");
if (report.status !== "internal_no_go" || report.decision !== "仅允许内部开发验证") {
  throw new Error("发布准备报告错误地脱离 internal_no_go 状态");
}
if (report.build_identity?.source_sha256 !== releaseManifest.source?.sha256) {
  throw new Error("发布准备报告与候选发布清单源指纹不一致");
}
if (report.build_identity?.source_file_count !== releaseManifest.source?.file_count) {
  throw new Error("发布准备报告与候选发布清单文件数不一致");
}
if (productDecision.schema_version !== 1) throw new Error("产品基线决策文件 schema 版本不受支持");
if (report.product_decision?.status !== productDecision.status) throw new Error("发布准备报告与产品基线决策状态不一致");
if (report.launch_scope?.id !== (productDecision.launch_scope?.[0] ?? null)) throw new Error("发布准备报告与产品基线首发范围不一致");
if (requestedScope) {
  if (JSON.stringify(report.launch_scope.segment_ids) !== JSON.stringify(requestedScope.segmentIds)) throw new Error("发布准备报告首发分段映射不一致");
  if (JSON.stringify(report.launch_scope.asset_ids) !== JSON.stringify(requestedScope.assetIds)) throw new Error("发布准备报告首发资产映射不一致");
}
const productGate = report.gates.find((gate) => gate.id === "product_baseline");
if (productDecision.status === "pending_user_confirmation") {
  if (productGate?.status !== "blocked_user_confirmation") throw new Error("待用户确认的产品基线不得标记为通过");
} else if (productDecision.status === "approved") {
  const requiredFields = ["product_name", "visual_direction", "copyright_boundary", "commercialization", "budget_or_person_weeks", "target_launch_window"];
  for (const field of requiredFields) {
    const value = productDecision[field];
    if (value === null || value === "" || (Array.isArray(value) && value.length === 0)) {
      throw new Error(`已批准产品基线缺少字段：${field}`);
    }
  }
  if (!Array.isArray(productDecision.launch_platforms) || productDecision.launch_platforms.length === 0) throw new Error("已批准产品基线缺少首发平台");
  if (!Array.isArray(productDecision.launch_scope) || productDecision.launch_scope.length === 0) throw new Error("已批准产品基线缺少首发范围");
  if (productGate?.status !== "approved") throw new Error("已批准产品基线没有同步到发布准备门禁");
} else {
  throw new Error(`未知产品基线状态：${productDecision.status}`);
}
if (matrix.captures.filter((capture) => expectedSegmentIds.has(capture.id)).length !== expectedSegmentIds.size || acceptance.segments.filter((segment) => expectedSegmentIds.has(segment.id)).length !== expectedSegmentIds.size) {
  throw new Error("发布准备报告的矩阵数量与参考分段数量不一致");
}
const selectedBehavior = acceptance.segments.filter((segment) => expectedSegmentIds.has(segment.id));
const behaviorPassed = selectedBehavior.filter((segment) => segment.behavior_status === "passed").length;
const behaviorGraybox = selectedBehavior.filter((segment) => segment.behavior_status === "graybox").length;
const behaviorGate = report.gates.find((gate) => gate.id === "behavior_matrix");
const expectedBehaviorGateStatus = behaviorPassed === selectedBehavior.length
  ? "passed"
  : (behaviorPassed + behaviorGraybox === selectedBehavior.length ? "passed_graybox" : "blocked_incomplete");
if (behaviorGate?.status !== expectedBehaviorGateStatus) {
  throw new Error(`发布准备报告行为门禁状态不一致：期望 ${expectedBehaviorGateStatus}`);
}
const selectedVisualPending = acceptance.segments.some((segment) => expectedSegmentIds.has(segment.id) && segment.visual_status !== "passed");
const visualGate = report.gates.find((gate) => gate.id === "visual_matrix");
if (selectedVisualPending && visualGate?.status !== "blocked_unverified") {
  throw new Error("发布准备报告没有明确阻断首发范围内未验证视觉矩阵");
}
if (!selectedVisualPending && visualGate?.status !== "passed") {
  throw new Error("首发范围视觉矩阵已通过但报告没有同步为 passed");
}
const requiredCoverage = new Set([
  "third_person_player",
  "third_person_camera",
  "npc_perception",
  "mission_state_machine",
  "city_world",
  "interaction",
  "vehicle",
  "hud_and_pause",
  "save_and_recovery",
  "qa_and_release",
]);
if (!Array.isArray(report.objective_coverage) || report.objective_coverage.length !== requiredCoverage.size) {
  throw new Error("发布准备报告的目标覆盖项不完整");
}
for (const item of report.objective_coverage) {
  if (!requiredCoverage.has(item.id)) throw new Error(`发布准备报告存在未知目标覆盖项：${item.id}`);
  if (item.behavior_status !== "graybox" || item.visual_status !== "unverified") {
    throw new Error(`目标覆盖项错误地标记为完成：${item.id}`);
  }
  if (!Array.isArray(item.evidence) || item.evidence.length === 0) throw new Error(`目标覆盖项缺少证据：${item.id}`);
}
if (report.waivers.length !== 0) throw new Error("当前不允许存在未审核豁免");
console.log(`发布准备报告验证通过：状态 ${report.status}，源指纹匹配 ${report.build_identity.source_file_count} 个文件，豁免 ${report.waivers.length} 个`);
