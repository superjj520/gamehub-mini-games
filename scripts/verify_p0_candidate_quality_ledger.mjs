import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const readJson = (relativePath) => JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

const ledger = readJson("reference-evidence/candidate-runtime/p0-candidate-quality-ledger.json");
const releaseManifest = readJson("docs/release-manifest.json");
const registry = readJson("docs/asset-candidate-registry.json");
const adoption = readJson("docs/asset-candidate-adoption-matrix.json");
const captureReadiness = readJson("reference-evidence/candidate-runtime/graphical-capture-readiness.json");

const requiredSlots = [
  "player-character",
  "office-npc-set",
  "office-environment-kit",
  "city-environment-kit",
  "three-wheel-vehicle",
];
const registryIds = new Set((registry.candidates ?? []).map((candidate) => candidate.id));
const adoptionById = new Map((adoption.slots ?? []).map((slot) => [slot.id, slot]));

assert(ledger.schema_version === 1, "P0 候选质量台账 schema 版本不受支持");
assert(ledger.status === "candidate_only_blocked_by_manual_visual_signoff", "P0 候选质量台账不得越过候选阻断状态");
assert(ledger.source.sha256 === releaseManifest.source.sha256, "P0 候选质量台账源指纹与发布清单不一致");
assert(Number(ledger.source.file_count) === Number(releaseManifest.source.file_count), "P0 候选质量台账源文件数与发布清单不一致");
assert(ledger.release_decision.allowed === false, "P0 候选质量台账不得允许发布");
assert(ledger.capture_gate.status === captureReadiness.status, "P0 候选质量台账图形门禁状态已漂移");
assert(ledger.capture_gate.manual_visual_signoff_required === true, "P0 候选质量台账必须保留人工视觉签收要求");

const slotIds = (ledger.slots ?? []).map((slot) => slot.id);
assert(slotIds.length === requiredSlots.length, `P0 候选质量台账槽位数量错误：${slotIds.length}/${requiredSlots.length}`);
for (const slotId of requiredSlots) {
  const slot = ledger.slots.find((entry) => entry.id === slotId);
  const adoptionSlot = adoptionById.get(slotId);
  assert(slot, `P0 候选质量台账缺少槽位：${slotId}`);
  assert(adoptionSlot, `P0 候选质量台账没有对应接入矩阵：${slotId}`);
  assert(slot.candidate_count > 0, `P0 槽位没有候选资产：${slotId}`);
  assert(slot.integration_status.startsWith("verified_"), `P0 槽位未保留隔离接入验证状态：${slotId}`);
  assert(slot.visual_status === "unverified", `P0 槽位不得绕过视觉签收：${slotId}`);
  assert(slot.rights_status === "candidate_rights_recorded_not_release_signed", `P0 槽位权利状态不安全：${slotId}`);
  assert(slot.platform_status === "windows_target_device_pending", `P0 槽位平台状态不安全：${slotId}`);
  assert(slot.release_allowed === false, `P0 槽位不得允许发布：${slotId}`);
  assert(slot.evidence_complete === true, `P0 槽位存在缺失的候选证据：${slotId}`);
  for (const candidateId of slot.candidate_registry_ids) {
    assert(registryIds.has(candidateId), `P0 台账引用不存在的候选登记：${candidateId}`);
  }
}

if (ledger.capture_gate.status === "current_graphical_evidence_ready_for_manual_signoff") {
  assert(ledger.capture_gate.current_source_bound_pngs > 0, "当前源图形 PNG 不得在人工视觉签收节点缺失");
  assert(ledger.capture_gate.current_matrix_pngs === ledger.capture_gate.required_matrix_pngs, "正式矩阵应完整后才能进入人工视觉签收节点");
} else {
  assert(ledger.capture_gate.status === "blocked_by_graphics_capture", "P0 候选图形门禁状态不受支持");
  assert(ledger.capture_gate.current_source_bound_pngs === 0, "图形采集阻断状态不得伪称存在当前源 PNG");
  assert(ledger.capture_gate.current_matrix_pngs < ledger.capture_gate.required_matrix_pngs, "图形采集阻断状态下正式矩阵不得声称完整");
}
console.log(`P0 候选质量台账验证通过：${requiredSlots.length} 个槽位；候选证据完整；视觉、权利、Windows 设备和发布状态仍被正确阻断`);
