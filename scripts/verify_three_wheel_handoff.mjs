import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";

const root = process.cwd();
const handoffPath = path.join(root, "docs/asset-production-handoff-three-wheel.json");
const handoff = JSON.parse(fs.readFileSync(handoffPath, "utf8"));

function readJson(relativePath) {
  const absolutePath = path.join(root, relativePath);
  if (!fs.existsSync(absolutePath)) throw new Error(`三轮车交接文件不存在：${relativePath}`);
  return JSON.parse(fs.readFileSync(absolutePath, "utf8"));
}

function sha256(relativePath) {
  const absolutePath = path.join(root, relativePath);
  if (!fs.existsSync(absolutePath)) throw new Error(`三轮车交接资产不存在：${relativePath}`);
  return crypto.createHash("sha256").update(fs.readFileSync(absolutePath)).digest("hex");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

assert(handoff.schema_version === 1, "三轮车交接清单 schema 版本错误");
assert(handoff.status === "candidate_handoff", "三轮车交接清单必须保持 candidate_handoff");
assert(handoff.slot_id === "three-wheel-vehicle", "三轮车交接清单槽位错误");
assert(handoff.provenance.external_source === false, "三轮车候选不得声明外部来源已通过");
assert(handoff.provenance.review_required_before_release === true, "三轮车候选必须保留发布前审查");
assert(handoff.evidence.visual_status !== "passed", "候选交接不得伪造视觉通过");
assert(handoff.evidence.release_allowed === false, "候选交接不得标记为可发布");

assert(sha256(handoff.deliverables.glb.path) === handoff.deliverables.glb.sha256, "三轮车 GLB 哈希与交接清单不一致");
assert(sha256(handoff.deliverables.scene.path) === handoff.deliverables.scene.sha256, "三轮车场景哈希与交接清单不一致");
assert(sha256(handoff.deliverables.asset_card.path) === handoff.deliverables.asset_card.sha256, "三轮车资产卡哈希与交接清单不一致");

const assetCard = readJson(handoff.deliverables.asset_card.path);
assert(assetCard.asset_id === "three-wheel-delivery-final-candidate-detailed-v2", "三轮车资产卡身份错误");
assert(assetCard.runtime_sha256 === handoff.deliverables.glb.sha256, "三轮车资产卡未绑定当前 GLB");
assert(assetCard.source.type === "original_procedural_generation", "三轮车资产卡来源类型错误");
assert(assetCard.release_allowed === false, "三轮车资产卡不得标记为可发布");
assert(assetCard.visual_status === "unverified", "三轮车资产卡不得伪造视觉通过");

const evidence = readJson(handoff.deliverables.runtime_evidence);
assert(evidence.candidate_id === handoff.candidate_id, "三轮车运行时证据候选 id 不一致");
assert(evidence.candidate_sha256 === handoff.deliverables.glb.sha256, "三轮车运行时证据未绑定当前 GLB");
assert(evidence.status === "candidate_isolated_city_office_runtime_verified", "三轮车运行时证据未达到隔离接入验证状态");
assert(evidence.runtime_options.fallback_policy === "forbid", "三轮车候选运行时没有禁止灰盒回退");
assert(evidence.visual_status === "unverified", "三轮车运行时证据不得伪造视觉通过");
assert(evidence.release_allowed === false, "三轮车运行时证据不得标记为可发布");

const registry = readJson("docs/asset-candidate-registry.json");
const registryEntry = registry.candidates.find((candidate) => candidate.id === handoff.candidate_id);
assert(registryEntry, `候选登记中缺少 ${handoff.candidate_id}`);
assert(registryEntry.runtime_sha256 === handoff.deliverables.glb.sha256, "候选登记未绑定当前三轮车 GLB");
assert(registryEntry.release_allowed === false && registryEntry.visual_status !== "passed", "候选登记错误提升了三轮车状态");

const currentSource = execFileSync(process.execPath, ["scripts/source_fingerprint.mjs"], {cwd: root, encoding: "utf8"}).trim();
const match = currentSource.match(/^([0-9a-f]{64}) files=(\d+)$/);
assert(match, `当前源码指纹格式无效：${currentSource}`);
assert(match[1] === handoff.evidence.current_runtime_source_fingerprint, "三轮车交接清单未绑定当前正式运行时源码");
assert(Number(match[2]) === Number(handoff.evidence.current_runtime_source_file_count), "三轮车交接清单源码文件数过期");

for (const requiredPath of [handoff.provenance.builder, handoff.evidence.integration_runner, handoff.evidence.candidate_runtime_script]) {
  assert(fs.existsSync(path.join(root, requiredPath)), `三轮车交接引用文件不存在：${requiredPath}`);
}

console.log(`三轮车生产交接验证通过：${handoff.candidate_id}；运行时 ${match[1]}/${match[2]}；视觉未验收；不可发布`);
