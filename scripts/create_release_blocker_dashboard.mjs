import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const readJson = (relativePath) => JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));

const objective = readJson("docs/objective-completion-status.json");
const readiness = readJson("docs/readiness-report.json");
const releaseManifest = readJson("docs/release-manifest.json");
const graphical = readJson("reference-evidence/candidate-runtime/graphical-capture-readiness.json");
const ownerInputs = readJson("docs/release-owner-inputs.json");

const objectiveById = new Map((objective.requirements ?? []).map((requirement) => [requirement.id, requirement]));
const readinessById = new Map((readiness.gates ?? []).map((gate) => [gate.id, gate]));
const ownerByInputId = new Map((ownerInputs.inputs ?? []).map((input) => [input.id, input]));

const gate = (id, owner, status, evidence, unblockAction, reason) => ({
  id,
  owner,
  status,
  evidence,
  unblock_action: unblockAction,
  reason,
});

const visualRequirement = objectiveById.get("visual_acceptance");
const finalAssetRequirement = objectiveById.get("final_assets");
const platformRequirement = objectiveById.get("platform_export");
const readinessVisual = readinessById.get("visual_matrix");
const readinessAssets = readinessById.get("final_assets");
const readinessPlatform = readinessById.get("target_platform");
const graphicalReady = graphical.status === "current_graphical_evidence_ready_for_manual_signoff";
const graphicalCurrentPngs = graphical.summary?.current_source_bound_pngs ?? graphical.current_source_bound_pngs ?? 0;
const graphicalRequiredPngs = graphical.summary?.required_matrix_pngs ?? graphical.required_matrix_pngs ?? 21;
const graphicalGateStatus = graphicalReady ? "passed" : graphical.status;
const graphicalAction = graphicalReady
  ? "打开正式视觉审阅面板，逐段完成当前源 PNG 与参考帧的人工对照；不通过项继续返工"
  : "解锁 Mac 或使用 Windows 目标设备，完成当前源 21 段真实窗口采集；确认 PNG 后再记录采集会话";
const graphicalReason = `${graphicalCurrentPngs}/${graphicalRequiredPngs} 张当前源 PNG 可用；${graphicalReady ? "当前图形证据已就绪，等待人工视觉签收" : "旧截图不得改绑"}`;

const gates = [
  gate(
    "graphics_capture",
    "视觉负责人 / 发布工程负责人",
    graphicalGateStatus,
    [
      "reference-evidence/candidate-runtime/graphical-capture-readiness.json",
      "docs/visual-capture-runbook.md",
    ],
    graphicalAction,
    graphicalReason,
  ),
  gate(
    "visual_signoff",
    "视觉负责人",
    visualRequirement?.status ?? "unverified",
    visualRequirement?.evidence ?? ["reference-evidence/runtime-matrix/manifest.json"],
    "逐段对照角色、镜头、构图、HUD、灯光、材质、动画和关键道具，记录人工签收或返工项",
    visualRequirement?.reason ?? "视觉状态缺少当前审计证据",
  ),
  gate(
    "final_assets",
    "美术 / 音频 / 权利负责人",
    finalAssetRequirement?.status ?? readinessAssets?.status ?? "blocked_graybox",
    finalAssetRequirement?.evidence ?? ["docs/asset-production-manifest.json", "gta-reference-runtime/content/rights-manifest.json"],
    "为 8 个正式资产槽位完成最终资产、来源记录、许可证、目标设备表现和人工视觉签收",
    finalAssetRequirement?.reason ?? readinessAssets?.reason ?? "正式资产仍未完成",
  ),
  gate(
    "windows_target_device",
    "发布工程负责人",
    platformRequirement?.status ?? readinessPlatform?.status ?? "pending_target_device_validation",
    platformRequirement?.evidence ?? ["docs/windows-device-qa-runbook.md", "reference-evidence/windows-device-qa"],
    "在 Windows 10/11 目标设备运行启动、输入、存档、性能、窗口分辨率和视觉回归，并保存人工签收记录",
    readinessPlatform?.reason ?? "目标设备尚未完成严格 QA",
  ),
  gate(
    "steam_owner_inputs",
    "发行负责人 / 法务负责人",
    ownerByInputId.get("operating_entity")?.status ?? "pending_owner_confirmation",
    ["docs/release-owner-inputs.json", "docs/store-submission-checklist.md"],
    "确认运营主体、隐私责任主体、客服邮箱、隐私政策地址、年龄分级和公开测试日期",
    "Steam 商店材料仍为草案，运营主体字段未确认",
  ),
];

const blockers = gates.filter((item) => !["passed", "passed_graybox"].includes(item.status));
const dashboard = {
  schema_version: 1,
  generated_at: new Date().toISOString(),
  status: blockers.length === 0 ? "release_go_candidate" : "internal_no_go",
  source: {
    sha256: releaseManifest.source.sha256,
    file_count: releaseManifest.source.file_count,
  },
  counts: {
    behavior_passed: objective.counts?.behavior_passed ?? 0,
    behavior_total: objective.counts?.segments ?? 0,
    visual_passed: objective.counts?.visual_passed ?? 0,
    visual_total: objective.counts?.visual_total ?? 0,
    graybox_assets: objective.counts?.graybox_assets ?? 0,
  },
  gates,
  blockers: blockers.map((item) => item.id),
  policy: "本看板只汇总当前证据，不替代产品定稿、权利签署、人工视觉验收、目标设备 QA 或商店提交。",
};

const outputPath = path.join(root, "docs/release-blocker-dashboard.json");
fs.writeFileSync(outputPath, `${JSON.stringify(dashboard, null, 2)}\n`, "utf8");
console.log(`发布阻断看板已生成：${path.relative(root, outputPath)}；状态 ${dashboard.status}；阻断 ${blockers.length} 项；源 ${dashboard.source.sha256}/${dashboard.source.file_count}`);
