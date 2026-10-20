import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const readJson = (relativePath) => JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
const exists = (relativePath) => fs.existsSync(path.join(root, relativePath));
const source = readJson("docs/release-manifest.json").source;
const baseline = readJson("docs/product-baseline-decision.json");
const readiness = readJson("docs/readiness-report.json");
const objective = readJson("docs/objective-completion-status.json");
const behavior = readJson("reference-evidence/current-runtime-behavior/manifest.json");
const expandedBehavior = readJson("reference-evidence/expanded-runtime-matrix/behavior-evidence.json");
const graphical = readJson("reference-evidence/candidate-runtime/graphical-capture-readiness.json");
const assets = readJson("docs/asset-production-manifest.json");

const currentSource = `${source.sha256}/${source.file_count}`;
const currentPngs = Number(graphical.summary?.current_matrix_pngs ?? 0);
const expandedPngs = Number(graphical.summary?.current_expanded_pngs ?? 0);
const currentBehaviorPassed = behavior.status === "current_behavior_matrix_verified";
const expandedBehaviorPassed = expandedBehavior.status === "expanded_behavior_verified";
const grayboxAssets = assets.slots.filter((slot) => slot.status === "graybox").length;

const requirements = [
  {
    id: "product-definition",
    label: "产品定义与范围",
    status: baseline.status === "approved" ? "passed" : "blocked_owner_confirmation",
    direct_evidence: ["docs/product-baseline-decision.json", "docs/product-confirmation-packet.md"],
    acceptance_gate: "名称、平台、首发范围、视觉方向、预算、版权边界和商业化方式已定稿",
    remaining: baseline.status === "approved" ? [] : ["产品负责人定稿"],
  },
  {
    id: "reference-evidence",
    label: "参考视频证据库与当前源绑定",
    status: currentPngs === 21 ? "passed" : "blocked_graphics_capture",
    direct_evidence: ["reference-evidence/manifest.json", "reference-evidence/runtime-matrix/manifest.json", "reference-evidence/candidate-runtime/graphical-capture-readiness.json"],
    acceptance_gate: "21 个参考分段都有当前源、非无头、可读取 PNG，并完成人工逐段签收",
    remaining: currentPngs === 21 ? [] : [`当前源 PNG ${currentPngs}/21`, "可见窗口或 Windows 图形采集会话", "人工逐段视觉签收"],
  },
  {
    id: "third-person-runtime",
    label: "第三人称角色与镜头",
    status: currentBehaviorPassed ? "behavior_verified_visual_unverified" : "incomplete",
    direct_evidence: ["gta-reference-runtime/scripts/player_controller.gd", "gta-reference-runtime/scripts/third_person_camera.gd", "gta-reference-runtime/tests/presentation_animation_test.gd", "reference-evidence/current-runtime-behavior/manifest.json"],
    acceptance_gate: "角色移动、蹲伏、交互、载具镜头和遮挡关系在行为与视觉矩阵中逐项通过",
    remaining: ["当前源图形采集", "角色/动画/镜头人工视觉签收"],
  },
  {
    id: "npc-perception",
    label: "NPC 感知、警觉与搜索",
    status: currentBehaviorPassed ? "behavior_verified_visual_unverified" : "incomplete",
    direct_evidence: ["gta-reference-runtime/scripts/perception_state.gd", "gta-reference-runtime/tests/office_integration_test.gd", "reference-evidence/current-runtime-behavior/trace-evidence.json"],
    acceptance_gate: "视野、遮挡、怀疑、发现、搜索、失败和恢复状态可回放并通过视觉签收",
    remaining: ["NPC 动作、视线提示和空间构图视觉签收"],
  },
  {
    id: "mission-state-machine",
    label: "任务状态机与任务链",
    status: currentBehaviorPassed ? "behavior_verified_visual_unverified" : "incomplete",
    direct_evidence: ["gta-reference-runtime/scripts/mission_state.gd", "gta-reference-runtime/scripts/mission_chain.gd", "gta-reference-runtime/tests/city_integration_test.gd", "gta-reference-runtime/tests/office_integration_test.gd"],
    acceptance_gate: "城市任务、办公室潜行、失败、重试、检查点和成功结算状态完整可回放",
    remaining: ["任务关键帧与反馈层视觉签收"],
  },
  {
    id: "city-and-interactions",
    label: "城市、交互道具与开放街区",
    status: currentBehaviorPassed ? "behavior_verified_visual_unverified" : "incomplete",
    direct_evidence: ["gta-reference-runtime/scenes/city.tscn", "gta-reference-runtime/scripts/city_demo.gd", "gta-reference-runtime/scripts/interaction_target.gd", "gta-reference-runtime/tests/city_integration_test.gd"],
    acceptance_gate: "商店、货架、鸡蛋、登记牌、街区入口、行人和任务目标在同一运行时中可交互",
    remaining: ["城市最终资产", "当前源城市截图", "逐项构图、材质、密度和灯光签收"],
  },
  {
    id: "vehicle-runtime",
    label: "三轮载具与驾驶反馈",
    status: currentBehaviorPassed ? "behavior_verified_visual_unverified" : "incomplete",
    direct_evidence: ["gta-reference-runtime/scripts/vehicle_controller.gd", "gta-reference-runtime/tests/city_vehicle_candidate.gd", "gta-reference-runtime/tests/city_performance_profile_test.gd"],
    acceptance_gate: "上下车、转向、加速、碰撞、耐久、失败反馈和存档恢复可回放",
    remaining: ["驾驶镜头、车辆材质、坐姿、速度感和碰撞表现视觉签收"],
  },
  {
    id: "hud-and-save",
    label: "HUD、设置、存档与恢复",
    status: currentBehaviorPassed ? "behavior_verified_visual_unverified" : "incomplete",
    direct_evidence: ["gta-reference-runtime/scripts/game_hud_visual.gd", "gta-reference-runtime/scripts/save_store.gd", "gta-reference-runtime/tests/hud_layout_integration_test.gd", "gta-reference-runtime/tests/session_journal_test.gd"],
    acceptance_gate: "目标、距离、雷达、交互提示、失败覆盖层、设置、存档和恢复在目标分辨率下可用",
    remaining: ["HUD 当前源截图", "目标分辨率与 Windows 输入/存档回归"],
  },
  {
    id: "expanded-content",
    label: "视频样本之外的原创扩展内容",
    status: expandedBehaviorPassed && expandedPngs === 18 ? "passed" : expandedBehaviorPassed ? "behavior_verified_visual_unverified" : "incomplete",
    direct_evidence: ["docs/expanded-content-plan.md", "reference-evidence/expanded-runtime-matrix/behavior-evidence.json", "docs/expanded-visual-acceptance-matrix.json"],
    acceptance_gate: "18 个扩展项分别完成行为、当前源视觉截图、人工审阅和目标设备验收",
    remaining: expandedPngs === 18 ? [] : [`当前源扩展 PNG ${expandedPngs}/18`, "扩展项人工视觉签收", "目标设备验收"],
  },
  {
    id: "original-rights",
    label: "原创资产与版权边界",
    status: "candidate_rights_verified_final_signoff_pending",
    direct_evidence: ["gta-reference-runtime/content/rights-manifest.json", "docs/asset-rights-register.md", "gta-reference-runtime/THIRD_PARTY_NOTICES.md"],
    acceptance_gate: "所有首发资产都有可发布来源、许可、作者和范围记录，参考视频不进入发布包",
    remaining: ["8 个正式资产槽位最终来源与权利签收", `当前灰盒槽位 ${grayboxAssets}/8`],
  },
  {
    id: "automated-quality",
    label: "自动化测试、性能与可复现构建",
    status: currentBehaviorPassed && exists("docs/windows-build-manifest.json") ? "host_verified_target_device_pending" : "incomplete",
    direct_evidence: ["reference-evidence/current-runtime-behavior/manifest.json", "reference-evidence/expanded-runtime-matrix/behavior-evidence.json", "docs/windows-build-manifest.json", "docs/windows-device-qa-runbook.md"],
    acceptance_gate: "行为、扩展行为、性能、候选包、Windows 构建和目标设备回归全部有可复核证据",
    remaining: ["Windows 10/11 目标设备启动、输入、性能和图形回归"],
  },
  {
    id: "release-preparation",
    label: "Steam 发布准备",
    status: readiness.status === "release_go" ? "passed" : "internal_no_go",
    direct_evidence: ["docs/readiness-report.json", "docs/release-blocker-dashboard.json", "docs/store-submission-evidence-index.json", "docs/release-owner-inputs.json"],
    acceptance_gate: "视觉、资产权利、目标设备、商店字段、隐私、分级和发布回滚全部通过",
    remaining: readiness.status === "release_go" ? [] : ["视觉签收", "最终资产和权利", "Windows 真机 QA", "6 个发行负责人/法务字段"],
  },
];

const report = {
  schema_version: 1,
  generated_at: new Date().toISOString(),
  product_name: "新时代觉醒者",
  source: {sha256: source.sha256, file_count: source.file_count},
  objective_status: objective.status,
  requirements,
  summary: {
    total: requirements.length,
    passed: requirements.filter((item) => item.status === "passed").length,
    behavior_verified_visual_unverified: requirements.filter((item) => item.status === "behavior_verified_visual_unverified").length,
    blocked: requirements.filter((item) => item.status.includes("blocked") || item.status === "internal_no_go" || item.status.endsWith("pending") || item.status.includes("unverified")).length,
  },
  policy: "追踪矩阵只汇总直接证据；行为通过不替代视觉、权利、目标设备或商店发布门禁。",
};

fs.writeFileSync(path.join(root, "docs/requirement-traceability.json"), `${JSON.stringify(report, null, 2)}\n`, "utf8");
console.log(`目标要求追踪矩阵已生成：${report.summary.passed}/${report.summary.total} 项完全通过；当前源 ${currentSource}`);
for (const item of requirements.filter((requirement) => requirement.status !== "passed")) console.log(`- ${item.id}: ${item.status}`);
