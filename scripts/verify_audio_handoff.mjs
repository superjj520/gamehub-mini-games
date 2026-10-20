import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";

const root = process.cwd();
const handoff = JSON.parse(fs.readFileSync(path.join(root, "docs/asset-production-handoff-audio.json"), "utf8"));

function sha256(relativePath) {
  const absolutePath = path.join(root, relativePath);
  if (!fs.existsSync(absolutePath)) throw new Error(`音频交接文件不存在：${relativePath}`);
  return crypto.createHash("sha256").update(fs.readFileSync(absolutePath)).digest("hex");
}

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

assert(handoff.schema_version === 1, "音频交接清单 schema 版本错误");
assert(handoff.status === "candidate_handoff", "音频交接清单必须保持 candidate_handoff");
assert(handoff.slot_id === "final-audio-library", "音频交接清单槽位错误");
assert(handoff.provenance.external_source === false, "音频候选不得声明外部来源已通过");
assert(handoff.provenance.review_required_before_release === true, "音频候选必须保留发布前审查");
assert(handoff.evidence.technical_status === "passed", "音频技术验收尚未通过");
assert(handoff.evidence.manual_listening_status === "unverified", "音频人工听感状态必须保持未验收");
assert(handoff.evidence.platform_status === "unverified", "音频平台状态必须保持未验收");
assert(handoff.evidence.release_allowed === false, "音频候选不得标记为可发布");

for (const entry of [handoff.deliverables.runtime_catalog, handoff.deliverables.cue_catalog, handoff.deliverables.library_manifest]) {
  assert(sha256(entry.path) === entry.sha256, `音频目录文件哈希与交接清单不一致：${entry.path}`);
}

const evidence = readJson(handoff.deliverables.runtime_evidence);
assert(evidence.status === "technical_candidate_verified", "音频候选证据状态错误");
assert(evidence.technical_status === "passed", "音频候选技术状态错误");
assert(evidence.manual_listening_status === "unverified", "音频候选证据不得伪造人工听感通过");
assert(evidence.platform_status === "unverified", "音频候选证据不得伪造目标设备通过");
assert(evidence.release_allowed === false, "音频候选证据不得标记为可发布");
assert(Number(evidence.event_count) === handoff.runtime_contract.event_count, "音频事件数量与交接清单不一致");
assert(Array.isArray(evidence.audio_files) && evidence.audio_files.length === handoff.runtime_contract.event_count, "音频文件清单数量不一致");

for (const audio of evidence.audio_files) {
  const relativePath = audio.path.replace(/^res:\/\//, "gta-reference-runtime/");
  const absolutePath = path.join(root, relativePath);
  assert(fs.existsSync(absolutePath), `音频 WAV 不存在：${relativePath}`);
  const bytes = fs.statSync(absolutePath).size;
  assert(bytes === audio.bytes, `音频字节数与证据不一致：${audio.id}`);
  assert(sha256(relativePath) === audio.sha256, `音频 SHA-256 与证据不一致：${audio.id}`);
}

const currentSource = execFileSync(process.execPath, ["scripts/source_fingerprint.mjs"], {cwd: root, encoding: "utf8"}).trim();
const match = currentSource.match(/^([0-9a-f]{64}) files=(\d+)$/);
assert(match, `当前源码指纹格式无效：${currentSource}`);
assert(match[1] === handoff.evidence.current_runtime_source_fingerprint, "音频交接清单未绑定当前正式运行时源码");
assert(Number(match[2]) === Number(handoff.evidence.current_runtime_source_file_count), "音频交接清单源码文件数过期");

console.log(`音频库生产交接验证通过：${handoff.candidate_id}；14 个事件；运行时 ${match[1]}/${match[2]}；人工听感未验收；不可发布`);
