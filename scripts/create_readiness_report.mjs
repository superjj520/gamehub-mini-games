import fs from "node:fs";
import path from "node:path";
import {resolveScope} from "./release_scope.mjs";
import {rightsAssetsForScope} from "./release_rights_scope.mjs";

const workspaceRoot = path.resolve(".");
const outputPath = path.join(workspaceRoot, "docs", "readiness-report.json");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(workspaceRoot, relativePath), "utf8"));
}

const releaseManifest = readJson("docs/release-manifest.json");
const productDecision = readJson("docs/product-baseline-decision.json");
const rightsManifest = readJson("gta-reference-runtime/content/rights-manifest.json");
const acceptance = readJson("reference-evidence/acceptance-status.json");
const matrix = readJson("reference-evidence/runtime-matrix/manifest.json");
const assetProduction = readJson("docs/asset-production-manifest.json");
const requestedScope = resolveScope(productDecision.launch_scope);
const selectedSegmentIds = new Set(requestedScope?.segmentIds ?? acceptance.segments.map((segment) => segment.id));
const selectedAssetIds = new Set(requestedScope?.assetIds ?? assetProduction.slots.map((slot) => slot.id));
const selectedAcceptance = acceptance.segments.filter((segment) => selectedSegmentIds.has(segment.id));
const selectedCaptures = matrix.captures.filter((capture) => selectedSegmentIds.has(capture.id));
const selectedAssets = assetProduction.slots.filter((slot) => selectedAssetIds.has(slot.id));

const behaviorTotal = selectedAcceptance.length;
const behaviorGraybox = selectedAcceptance.filter((segment) => segment.behavior_status === "graybox").length;
const behaviorPassed = selectedAcceptance.filter((segment) => segment.behavior_status === "passed").length;
const visualPassed = selectedAcceptance.filter((segment) => segment.visual_status === "passed").length;
const matrixVisualUnverified = selectedCaptures.filter((capture) => capture.visual_status === "unverified").length;
const grayboxAssets = selectedAssets.filter((slot) => slot.status === "graybox").length;
const scopedRightsAssets = rightsAssetsForScope(rightsManifest.assets, productDecision.launch_scope?.[0]);
const blockedAssets = scopedRightsAssets.filter((asset) => asset.release_allowed !== true).map((asset) => asset.id);
const excludedInternalAssets = rightsManifest.assets.filter((asset) => asset.release_candidate_required === false).map((asset) => asset.id);
const productBaselineApproved = productDecision.status === "approved";
const platformConfigured = fs.existsSync(path.join(workspaceRoot, "gta-reference-runtime", "export_presets.cfg"));
const rollbackEvidencePath = "reference-evidence/release-rollback-rehearsal.json";
const rollbackEvidenceExists = fs.existsSync(path.join(workspaceRoot, rollbackEvidencePath));

const coverage = [
  { id: "third_person_player", behavior_status: "graybox", visual_status: "unverified", evidence: ["gta-reference-runtime/scripts/player_controller.gd", "gta-reference-runtime/tests/office_integration_test.gd"] },
  { id: "third_person_camera", behavior_status: "graybox", visual_status: "unverified", evidence: ["gta-reference-runtime/scripts/third_person_camera.gd", "gta-reference-runtime/tests/city_integration_test.gd"] },
  { id: "npc_perception", behavior_status: "graybox", visual_status: "unverified", evidence: ["gta-reference-runtime/scripts/perception_state.gd", "gta-reference-runtime/tests/office_integration_test.gd"] },
  { id: "mission_state_machine", behavior_status: "graybox", visual_status: "unverified", evidence: ["gta-reference-runtime/scripts/mission_state.gd", "gta-reference-runtime/scripts/mission_chain.gd", "gta-reference-runtime/tests/smoke_test.gd"] },
  { id: "city_world", behavior_status: "graybox", visual_status: "unverified", evidence: ["gta-reference-runtime/scripts/city_demo.gd", "gta-reference-runtime/tests/city_integration_test.gd"] },
  { id: "interaction", behavior_status: "graybox", visual_status: "unverified", evidence: ["gta-reference-runtime/scripts/interaction_target.gd", "gta-reference-runtime/tests/smoke_test.gd"] },
  { id: "vehicle", behavior_status: "graybox", visual_status: "unverified", evidence: ["gta-reference-runtime/scripts/vehicle_controller.gd", "gta-reference-runtime/tests/city_integration_test.gd"] },
  { id: "hud_and_pause", behavior_status: "graybox", visual_status: "unverified", evidence: ["gta-reference-runtime/scripts/benchmark_scene.gd", "gta-reference-runtime/scripts/city_demo.gd", "gta-reference-runtime/tests/pause_integration_test.gd"] },
  { id: "save_and_recovery", behavior_status: "graybox", visual_status: "unverified", evidence: ["gta-reference-runtime/scripts/save_store.gd", "gta-reference-runtime/scripts/session_journal.gd", "scripts/verify_session_crash_recovery.mjs"] },
  { id: "qa_and_release", behavior_status: "graybox", visual_status: "unverified", evidence: ["scripts/verify_reference_runtime.sh", "docs/release-acceptance-protocol.md", "scripts/verify_readiness_report.mjs"] },
];
for (const item of coverage) {
  for (const evidencePath of item.evidence) {
    if (!fs.existsSync(path.join(workspaceRoot, evidencePath))) {
      throw new Error(`完成度覆盖项证据不存在：${item.id} -> ${evidencePath}`);
    }
  }
}

const report = {
  schema_version: 1,
  status: "internal_no_go",
  decision: "仅允许内部开发验证",
  build_identity: {
    project_version: releaseManifest.project.version,
    engine: releaseManifest.project.engine,
    source_sha256: releaseManifest.source.sha256,
    source_file_count: releaseManifest.source.file_count,
  },
  launch_scope: {
    id: productDecision.launch_scope?.[0] ?? null,
    segment_ids: requestedScope?.segmentIds ?? [...selectedSegmentIds],
    asset_ids: requestedScope?.assetIds ?? [...selectedAssetIds],
  },
  gates: [
    {
      id: "product_baseline",
      status: productBaselineApproved ? "approved" : "blocked_user_confirmation",
      owner: "产品负责人",
      evidence: "docs/product-baseline-decision.json",
      reason: productBaselineApproved ? "用户已提交机器可读产品基线" : "首发平台、范围、品牌、美术方向和预算尚未定稿",
    },
    {
      id: "runtime_graybox",
      status: "passed_graybox",
      owner: "工程负责人",
      evidence: "scripts/verify_reference_runtime.sh",
      reason: "角色、镜头、任务、NPC、城市、载具、存档和异常恢复自动化通过",
    },
    {
      id: "behavior_matrix",
      status: behaviorPassed === behaviorTotal ? "passed" : (behaviorGraybox + behaviorPassed === behaviorTotal ? "passed_graybox" : "blocked_incomplete"),
      owner: "QA负责人",
      evidence: "reference-evidence/acceptance-status.json",
      counts: { total: behaviorTotal, graybox: behaviorGraybox, passed: behaviorPassed },
    },
    {
      id: "visual_matrix",
      status: visualPassed === behaviorTotal ? "passed" : "blocked_unverified",
      owner: "视觉负责人",
      evidence: "reference-evidence/runtime-matrix/manifest.json",
      counts: { total: selectedCaptures.length, unverified: matrixVisualUnverified, passed: visualPassed },
      reason: "当前仅有低码率参考视频和灰盒截图，未完成最终逐帧签收",
    },
    {
      id: "final_assets",
      status: grayboxAssets === assetProduction.slots.length ? "blocked_graybox" : "blocked_incomplete",
      owner: "美术/音频负责人",
      evidence: "docs/asset-production-manifest.json",
      counts: { total: selectedAssets.length, graybox: grayboxAssets },
      reason: "最终角色、动画、环境、载具和音频资产尚未生产并完成权利签收",
    },
    {
      id: "rights_boundary",
      status: blockedAssets.length > 0 ? "blocked_assets" : "passed",
      owner: "权利负责人",
      evidence: "gta-reference-runtime/content/rights-manifest.json",
      blocked_assets: blockedAssets,
      excluded_internal_assets: excludedInternalAssets,
    },
    {
      id: "target_platform",
      status: productBaselineApproved
        ? (platformConfigured ? "blocked_target_device_unverified" : "blocked_export_not_configured")
        : "blocked_unconfirmed",
      owner: "发布工程负责人",
      evidence: ["docs/steam-windows-export-plan.md", "gta-reference-runtime/project.godot", "gta-reference-runtime/export_presets.cfg"],
      reason: productBaselineApproved
        ? (platformConfigured ? "Steam Windows 导出预设已存在，但目标设备回归尚未完成" : "Steam Windows 已确认，但尚未配置并验证 Godot 导出预设")
        : "目标平台、设备和发行地区尚未确认",
    },
    {
      id: "store_compliance",
      status: "blocked_draft_only",
      owner: "法务/运营负责人",
      evidence: ["docs/privacy-data-inventory.md", "docs/privacy-policy-draft-zh-CN.md", "docs/support-and-rollback-plan.md", "scripts/verify_privacy_data_boundary.mjs", "docs/store-submission-checklist.md"],
      reason: "开发基线已明确无网络数据收集并通过静态边界验证；隐私与客服已有内部草案，但正式政策、客服入口、年龄分级和平台商店字段仍未定稿",
    },
    {
      id: "rollback",
      status: rollbackEvidenceExists ? "internal_rehearsal_passed_target_platform_pending" : "not_started",
      owner: "发布工程负责人",
      evidence: rollbackEvidenceExists ? [rollbackEvidencePath, "docs/support-and-rollback-plan.md"] : "docs/release-acceptance-protocol.md",
      reason: rollbackEvidenceExists ? "已完成本地文件级候选构建切换与恢复；Steam 分支/Depot 和 Windows 真机回滚仍未验证" : "尚未建立目标平台发布流水线和回滚演练",
    },
  ],
  objective_coverage: coverage,
  product_decision: productDecision,
  blockers: releaseManifest.release_blockers,
  waivers: [],
  policy: "任何门禁没有同一构建的直接证据，都不得改为通过；本报告不改变任何验收状态。",
};

fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`, "utf8");
console.log(`发布准备报告已生成：${path.relative(workspaceRoot, outputPath)}；状态 ${report.status}；阻断项 ${report.blockers.length} 个`);
