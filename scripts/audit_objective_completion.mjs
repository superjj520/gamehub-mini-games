import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const readJson = (relativePath) => JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
const exists = (relativePath) => fs.existsSync(path.join(root, relativePath));
const hash = (value) => crypto.createHash("sha256").update(JSON.stringify(value)).digest("hex");

const decision = readJson("docs/product-baseline-decision.json");
const readiness = readJson("docs/readiness-report.json");
const acceptance = readJson("reference-evidence/acceptance-status.json");
const matrix = readJson("reference-evidence/runtime-matrix/manifest.json");
const currentBehavior = readJson("reference-evidence/current-runtime-behavior/manifest.json");
const expandedMatrix = readJson("docs/expanded-visual-acceptance-matrix.json");
const assets = readJson("docs/asset-production-manifest.json");
const releaseManifest = readJson("docs/release-manifest.json");
const candidateAdoption = readJson("docs/asset-candidate-adoption-matrix.json");
const graphicalReadiness = readJson("reference-evidence/candidate-runtime/graphical-capture-readiness.json");

const segmentCount = Array.isArray(acceptance.segments) ? acceptance.segments.length : 0;
const behaviorPassed = Array.isArray(acceptance.segments)
  ? acceptance.segments.filter((segment) => segment.behavior_status === "passed").length
  : 0;
const visualPassed = Array.isArray(acceptance.segments)
  ? acceptance.segments.filter((segment) => segment.visual_status === "passed").length
  : 0;
const visualTotal = Array.isArray(matrix.captures) ? matrix.captures.length : 0;
const expandedVisualTotal = Array.isArray(expandedMatrix.entries) ? expandedMatrix.entries.length : 0;
const expandedVisualPassed = Array.isArray(expandedMatrix.entries)
  ? expandedMatrix.entries.filter((entry) => entry.visual_status === "passed").length
  : 0;
const grayboxAssets = Array.isArray(assets.slots)
  ? assets.slots.filter((slot) => slot.status === "graybox").length
  : 0;
const candidateAssets = Array.isArray(candidateAdoption.slots)
  ? candidateAdoption.slots.filter((slot) => slot.integration_status?.startsWith("verified_") && slot.visual_status !== "passed").length
  : 0;
// 当前版本身份以正式发布清单为准；运行时矩阵可能保留历史截图，不能反向定义当前源码。
const sourceFingerprint = releaseManifest.source?.sha256 ?? "";
const sourceFileCount = Number(releaseManifest.source?.file_count ?? 0);
const currentMatrixPngs = Number(graphicalReadiness.summary?.current_matrix_pngs ?? 0);
const currentMatrixReady = matrix.source_fingerprint === sourceFingerprint
  && matrix.source_file_count === sourceFileCount
  && currentMatrixPngs === visualTotal;
const currentBehaviorVerified = currentBehavior.status === "current_behavior_matrix_verified"
  && currentBehavior.source_fingerprint === sourceFingerprint
  && currentBehavior.source_file_count === sourceFileCount
  && currentBehavior.segment_count === 21;

const requirements = [
  {
    id: "reference_evidence",
    status: segmentCount === 21 && visualTotal === 21 && currentMatrixReady ? "passed" : "incomplete",
    evidence: ["reference-evidence/manifest.json", "reference-evidence/acceptance-status.json", "reference-evidence/runtime-matrix/manifest.json"],
    reason: currentMatrixReady
      ? "21 个参考分段和 21 张当前源运行时截图已登记并完成源绑定"
      : `参考分段或当前源运行时截图未完成：参考分段 ${segmentCount}/21、运行时登记 ${visualTotal}/21、当前源有效 PNG ${currentMatrixPngs}/${visualTotal}`,
  },
  {
    id: "behavior_runtime",
    status: currentBehaviorVerified && behaviorPassed === segmentCount && segmentCount === 21 ? "passed_graybox" : "incomplete",
    evidence: ["reference-evidence/current-runtime-behavior/manifest.json", "reference-evidence/current-runtime-behavior/trace-evidence.json", "scripts/verify_current_behavior_matrix.mjs"],
    reason: currentBehaviorVerified
      ? `${behaviorPassed}/${segmentCount} 个分段行为回放通过，且当前源码行为证据已绑定 ${sourceFingerprint}/${sourceFileCount}；这不是最终视觉完成证明`
      : "当前源码行为矩阵缺失或没有绑定发布清单身份",
  },
  {
    id: "visual_acceptance",
    status: visualPassed === visualTotal && visualTotal > 0 ? "passed" : "unverified",
    evidence: ["reference-evidence/runtime-matrix/manifest.json", "reference-evidence/runtime-matrix/compare-reports"],
    reason: `${visualPassed}/${visualTotal} 个视觉分段通过人工签收`,
  },
  {
    id: "expanded_visual_acceptance",
    status: expandedVisualPassed === expandedVisualTotal && expandedVisualTotal > 0 ? "passed" : "unverified",
    evidence: ["docs/expanded-content-plan.md", "docs/expanded-visual-acceptance-matrix.json", "scripts/verify_expanded_visual_acceptance.mjs"],
    reason: `${expandedVisualPassed}/${expandedVisualTotal} 个视频样本之外的扩展视觉项通过人工签收`,
  },
  {
    id: "final_assets",
    status: grayboxAssets === 0 && Array.isArray(assets.slots) ? "passed" : "blocked_graybox",
    evidence: ["docs/asset-production-manifest.json", "gta-reference-runtime/content/asset-runtime-catalog.json"],
    reason: `${grayboxAssets}/${Array.isArray(assets.slots) ? assets.slots.length : 0} 个正式资产槽位仍为灰盒；${candidateAssets} 个候选槽位已有隔离接入证据但尚未完成视觉、权利和设备签收`,
  },
  {
    id: "product_baseline",
    status: decision.status === "approved" ? "passed" : "blocked_user_confirmation",
    evidence: ["docs/product-baseline-decision.json", "docs/product-confirmation-packet.md"],
    reason: decision.status === "approved" ? "产品基线已确认" : "产品名称、平台、范围、视觉方向、预算和上线窗口仍待确认",
  },
  {
    id: "release_readiness",
    status: readiness.status === "release_go" ? "passed" : "blocked_release_gates",
    evidence: ["docs/readiness-report.json", "scripts/verify_readiness_report.mjs", "scripts/verify_release_preconditions.mjs"],
    reason: `发布准备状态为 ${readiness.status}`,
  },
  {
    id: "build_identity",
    status: matrix.source_fingerprint === sourceFingerprint && matrix.source_file_count === sourceFileCount ? "passed" : "inconsistent",
    evidence: ["reference-evidence/runtime-matrix/manifest.json", "docs/release-manifest.json", "scripts/source_fingerprint.mjs"],
    reason: matrix.source_fingerprint === sourceFingerprint && matrix.source_file_count === sourceFileCount
      ? `矩阵与发布清单均绑定 ${sourceFingerprint}/${sourceFileCount} 个文件`
      : `当前发布清单为 ${sourceFingerprint}/${sourceFileCount}；历史矩阵为 ${matrix.source_fingerprint}/${matrix.source_file_count}，需重新采集后才能绑定`,
  },
  {
    id: "platform_export",
    status: exists("gta-reference-runtime/export_presets.cfg") ? "pending_target_device_validation" : "blocked_export_not_configured",
    evidence: ["gta-reference-runtime/project.godot", "gta-reference-runtime/export_presets.cfg"],
    reason: exists("gta-reference-runtime/export_presets.cfg") ? "已有导出预设，仍需目标设备验证" : "尚未配置 Godot 导出预设",
  },
];

const blockers = requirements.filter((requirement) => !["passed", "passed_graybox"].includes(requirement.status)).map((requirement) => requirement.id);
const report = {
  schema_version: 1,
  generated_at: new Date().toISOString(),
  status: blockers.length === 0 ? "complete_candidate" : "incomplete",
  completion_proven: blockers.length === 0,
  source_fingerprint: sourceFingerprint,
  source_file_count: sourceFileCount,
  counts: {
    segments: segmentCount,
    behavior_passed: behaviorPassed,
    visual_passed: visualPassed,
    visual_total: visualTotal,
    expanded_visual_passed: expandedVisualPassed,
    expanded_visual_total: expandedVisualTotal,
    graybox_assets: grayboxAssets,
    candidate_assets: candidateAssets,
  },
  requirements,
  blockers,
  report_hash: hash({sourceFingerprint, segmentCount, behaviorPassed, visualPassed, visualTotal, expandedVisualPassed, expandedVisualTotal, grayboxAssets, candidateAssets, blockers}),
  policy: "只有所有要求都有直接证据时才能标记 complete_candidate；本报告不会替代产品、权利、平台或人工视觉定稿。",
};

fs.writeFileSync(path.join(root, "docs/objective-completion-status.json"), `${JSON.stringify(report, null, 2)}\n`, "utf8");
console.log(`目标完成审计：${report.status}；行为 ${behaviorPassed}/${segmentCount}；视觉 ${visualPassed}/${visualTotal}；灰盒资产 ${grayboxAssets}`);
console.log(`阻断项：${blockers.length === 0 ? "无" : blockers.join(", ")}`);

if (process.argv.includes("--strict") && blockers.length > 0) process.exit(1);
