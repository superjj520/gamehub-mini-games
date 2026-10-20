import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";

const root = process.cwd();
const handoff = JSON.parse(fs.readFileSync(path.join(root, "docs/asset-production-handoff-city-environment.json"), "utf8"));

function sha256(relativePath) {
  const absolutePath = path.join(root, relativePath);
  if (!fs.existsSync(absolutePath)) throw new Error(`城市环境交接文件不存在：${relativePath}`);
  return crypto.createHash("sha256").update(fs.readFileSync(absolutePath)).digest("hex");
}

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

assert(handoff.schema_version === 1, "城市环境交接清单 schema 版本错误");
assert(handoff.status === "candidate_handoff", "城市环境交接清单必须保持 candidate_handoff");
assert(handoff.slot_id === "city-environment-kit", "城市环境交接清单槽位错误");
assert(handoff.provenance.external_source === false, "城市环境原创候选不得声明外部来源已通过");
assert(handoff.provenance.review_required_before_release === true, "城市环境候选必须保留发布前审查");
assert(handoff.evidence.visual_status !== "passed", "候选交接不得伪造视觉通过");
assert(handoff.evidence.release_allowed === false, "候选交接不得标记为可发布");

for (const entry of [handoff.deliverables.script, handoff.deliverables.scene]) {
  assert(sha256(entry.path) === entry.sha256, `城市环境文件哈希与交接清单不一致：${entry.path}`);
}

const evidence = readJson(handoff.deliverables.runtime_evidence);
assert(evidence.status === "candidate_isolated_full_playtest_verified", "城市环境原创-only 完整候选证据未达到隔离回放验证状态");
assert(evidence.character_variant === "original_only", "城市环境交接必须绑定 original-only 候选分支");
assert(evidence.source.sha256 === handoff.evidence.current_runtime_source_fingerprint, "城市环境证据与交接清单源指纹不一致");
assert(Number(evidence.source.file_count) === Number(handoff.evidence.current_runtime_source_file_count), "城市环境证据源码文件数不一致");
assert(evidence.active_candidate_ids.includes(handoff.candidate_id), "完整候选证据未启用原创城市环境候选");
assert(evidence.active_candidate_slots[handoff.slot_id] === "res://art-source/candidate-playtest/original-only/original_only_city_environment_candidate.tscn", "完整候选证据的城市环境入口错误");
assert(evidence.visual_status === "unverified", "城市环境证据不得伪造视觉通过");
assert(evidence.release_allowed === false, "城市环境证据不得标记为可发布");

const registry = readJson("docs/asset-candidate-registry.json");
const entry = registry.candidates.find((candidate) => candidate.id === handoff.candidate_id);
assert(entry, `候选登记中缺少 ${handoff.candidate_id}`);
assert(entry.source_kind === "project_original_generated_code_and_registered_generated_textures", "城市环境候选来源类型不是原创代码与登记生成纹理");
assert(entry.visual_status !== "passed" && entry.release_allowed === false, "候选登记错误提升了城市环境状态");

const currentSource = execFileSync(process.execPath, ["scripts/source_fingerprint.mjs"], {cwd: root, encoding: "utf8"}).trim();
const match = currentSource.match(/^([0-9a-f]{64}) files=(\d+)$/);
assert(match, `当前源码指纹格式无效：${currentSource}`);
assert(match[1] === handoff.evidence.current_runtime_source_fingerprint, "城市环境交接清单未绑定当前正式运行时源码");
assert(Number(match[2]) === Number(handoff.evidence.current_runtime_source_file_count), "城市环境交接清单源码文件数过期");

console.log(`城市环境生产交接验证通过：${handoff.candidate_id}；运行时 ${match[1]}/${match[2]}；视觉未验收；不可发布`);
