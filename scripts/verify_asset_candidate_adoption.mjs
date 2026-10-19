import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const readJson = (relativePath) => JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

const adoption = readJson("docs/asset-candidate-adoption-matrix.json");
const registry = readJson("docs/asset-candidate-registry.json");
const releaseManifest = readJson("docs/release-manifest.json");
const formalAssets = readJson("docs/asset-production-manifest.json");

assert(adoption.schema_version === 1, "候选资产接入矩阵 schema 版本不受支持");
assert(adoption.status === "candidate_integration_unverified", "候选资产接入矩阵状态不正确");
assert(adoption.source_fingerprint === releaseManifest.source?.sha256, "候选资产接入矩阵源指纹与发布清单不一致");
assert(Number(adoption.source_file_count) === Number(releaseManifest.source?.file_count), "候选资产接入矩阵源文件数与发布清单不一致");

const registryIds = new Set((registry.candidates ?? []).map((candidate) => candidate.id));
const formalIds = new Set((formalAssets.slots ?? []).map((slot) => slot.id));
const seen = new Set();
for (const slot of adoption.slots ?? []) {
  assert(formalIds.has(slot.id), `候选矩阵存在未登记正式槽位：${slot.id}`);
  assert(!seen.has(slot.id), `候选矩阵存在重复槽位：${slot.id}`);
  seen.add(slot.id);
  assert(slot.integration_status.startsWith("verified_"), `候选槽位未声明隔离验证：${slot.id}`);
  assert(slot.visual_status === "unverified", `候选槽位不得绕过视觉签收：${slot.id}`);
  assert(slot.rights_status === "candidate_rights_recorded_not_release_signed", `候选槽位权利状态不正确：${slot.id}`);
  assert(slot.platform_status === "windows_target_device_pending", `候选槽位平台状态不正确：${slot.id}`);
  for (const candidateId of slot.candidate_registry_ids ?? []) {
    assert(registryIds.has(candidateId), `候选矩阵引用了不存在的候选登记：${candidateId}`);
    const candidate = registry.candidates.find((entry) => entry.id === candidateId);
    assert(candidate.slot_id === slot.id, `候选登记槽位不匹配：${candidateId}`);
    assert(candidate.release_allowed === false, `候选登记不得允许发布：${candidateId}`);
  }
}
assert(seen.size === formalIds.size, `候选矩阵槽位数不完整：${seen.size}/${formalIds.size}`);
for (const evidencePath of adoption.candidate_evidence ?? []) {
  assert(fs.existsSync(path.resolve(root, evidencePath)), `候选接入证据不存在：${evidencePath}`);
}
console.log(`候选资产接入矩阵验证通过：${seen.size} 个槽位；全部保持视觉 unverified、权利未签收和 Windows 目标设备待验收`);
