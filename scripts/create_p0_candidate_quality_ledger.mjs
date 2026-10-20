import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const readJson = (relativePath) => JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
const writePath = path.join(root, "reference-evidence/candidate-runtime/p0-candidate-quality-ledger.json");

const releaseManifest = readJson("docs/release-manifest.json");
const registry = readJson("docs/asset-candidate-registry.json");
const adoption = readJson("docs/asset-candidate-adoption-matrix.json");
const captureReadiness = readJson("reference-evidence/candidate-runtime/graphical-capture-readiness.json");
const formalManifest = readJson("docs/asset-production-manifest.json");

const p0SlotIds = [
  "player-character",
  "office-npc-set",
  "office-environment-kit",
  "city-environment-kit",
  "three-wheel-vehicle",
];

const registryById = new Map((registry.candidates ?? []).map((candidate) => [candidate.id, candidate]));
const adoptionById = new Map((adoption.slots ?? []).map((slot) => [slot.id, slot]));
const formalById = new Map((formalManifest.slots ?? []).map((slot) => [slot.id, slot]));

const slots = p0SlotIds.map((slotId) => {
  const adoptionSlot = adoptionById.get(slotId);
  const formalSlot = formalById.get(slotId);
  const candidateIds = adoptionSlot?.candidate_registry_ids ?? [];
  const candidates = candidateIds.map((candidateId) => registryById.get(candidateId)).filter(Boolean);
  const evidenceComplete = candidates.every((candidate) => (candidate.evidence ?? []).every((evidencePath) => fs.existsSync(path.join(root, evidencePath))));
  const allCandidateOnly = candidates.every((candidate) => candidate.release_allowed === false && candidate.visual_status === "unverified");

  return {
    id: slotId,
    category: formalSlot?.category ?? null,
    priority: ["player-character", "office-npc-set", "office-environment-kit", "three-wheel-vehicle"].includes(slotId) ? "P0_launch_office" : "P0_city_extension",
    candidate_count: candidates.length,
    candidate_registry_ids: candidateIds,
    evidence_complete: evidenceComplete,
    integration_status: adoptionSlot?.integration_status ?? "missing_adoption_record",
    visual_status: adoptionSlot?.visual_status ?? "missing_adoption_record",
    rights_status: adoptionSlot?.rights_status ?? "missing_adoption_record",
    platform_status: adoptionSlot?.platform_status ?? "missing_adoption_record",
    release_allowed: formalSlot?.release_allowed === true || !allCandidateOnly,
    next_gate: "当前源非无头截图、逐段人工视觉验收、Windows 10/11 目标设备回归和最终权利签收",
  };
});

const currentSource = {
  sha256: releaseManifest.source.sha256,
  file_count: releaseManifest.source.file_count,
};

const ledger = {
  schema_version: 1,
  generated_at: new Date().toISOString(),
  status: "candidate_only_blocked_by_manual_visual_signoff",
  product: "新时代觉醒者",
  launch_scope: "office_vertical_slice",
  source: currentSource,
  policy: "本台账只汇总候选资产的可追溯性和未完成门禁，不把接入、静态检查或旧截图等同于最终资产、视觉签收或可发布状态。",
  capture_gate: {
    status: captureReadiness.status,
    current_source_bound_pngs: captureReadiness.summary.current_source_bound_pngs,
    current_matrix_pngs: captureReadiness.summary.current_matrix_pngs,
    required_matrix_pngs: captureReadiness.summary.required_matrix_pngs,
    matrix_capture_session_valid: captureReadiness.summary.matrix_capture_session_valid,
    manual_visual_signoff_required: captureReadiness.requirement.manual_visual_signoff_still_required,
    next_action: captureReadiness.next_action,
  },
  slots,
  release_decision: {
    allowed: false,
    reason: captureReadiness.status === "current_graphical_evidence_ready_for_manual_signoff"
      ? "P0 候选已完成当前源视觉采集，但仍未完成人工视觉签收、Windows 目标设备和最终权利门禁"
      : "P0 候选尚未完成当前源非无头视觉采集，且仍未完成人工视觉签收、Windows 目标设备和最终权利门禁",
  },
};

fs.writeFileSync(writePath, `${JSON.stringify(ledger, null, 2)}\n`);
console.log(`P0 候选质量台账已生成：${path.relative(root, writePath)}；${slots.length} 个槽位；当前源 ${currentSource.sha256.slice(0, 8)}`);
