import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";

const root = process.cwd();
const handoffPath = path.join(root, "docs/asset-production-handoff-interaction-props.json");
const handoff = JSON.parse(fs.readFileSync(handoffPath, "utf8"));

function readJson(relativePath) {
  const absolutePath = path.join(root, relativePath);
  if (!fs.existsSync(absolutePath)) throw new Error(`交互道具交接文件不存在：${relativePath}`);
  return JSON.parse(fs.readFileSync(absolutePath, "utf8"));
}

function sha256(relativePath) {
  const absolutePath = path.join(root, relativePath);
  if (!fs.existsSync(absolutePath)) throw new Error(`交互道具交接资产不存在：${relativePath}`);
  return crypto.createHash("sha256").update(fs.readFileSync(absolutePath)).digest("hex");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

assert(handoff.schema_version === 1, "交互道具交接清单 schema 版本错误");
assert(handoff.status === "candidate_handoff", "交互道具交接清单必须保持 candidate_handoff");
assert(handoff.slot_id === "interaction-props", "交互道具交接清单槽位错误");
assert(handoff.provenance.external_source === false, "交互道具候选不得声明外部来源已通过");
assert(handoff.provenance.review_required_before_release === true, "交互道具候选必须保留发布前审查");
assert(handoff.evidence.visual_status !== "passed", "候选交接不得伪造视觉通过");
assert(handoff.evidence.release_allowed === false, "候选交接不得标记为可发布");

const glbPath = handoff.deliverables.glb.path;
const atlasPath = handoff.deliverables.material_atlas.path;
assert(sha256(glbPath) === handoff.deliverables.glb.sha256, "交互道具 GLB 哈希与交接清单不一致");
assert(sha256(atlasPath) === handoff.deliverables.material_atlas.sha256, "交互道具材质图集哈希与交接清单不一致");

const assetRecord = readJson(handoff.deliverables.asset_record);
assert(assetRecord.id === handoff.candidate_id, "asset-record 候选 id 不一致");
assert(assetRecord.runtime_sha256 === handoff.deliverables.glb.sha256, "asset-record 未绑定当前 GLB");
assert(assetRecord.material_atlas_sha256 === handoff.deliverables.material_atlas.sha256, "asset-record 未绑定当前材质图集");
assert(assetRecord.visual_status === "unverified", "asset-record 不得伪造视觉通过");
assert(assetRecord.release_allowed === false, "asset-record 不得标记为可发布");

const evidence = readJson(handoff.deliverables.runtime_evidence);
assert(evidence.candidate_id === handoff.candidate_id, "运行时证据候选 id 不一致");
assert(evidence.candidate_sha256 === handoff.deliverables.glb.sha256, "运行时证据未绑定当前 GLB");
assert(evidence.formal_runtime_source_fingerprint === handoff.evidence.current_runtime_source_fingerprint, "运行时证据与交接清单源指纹不一致");
assert(Number(evidence.formal_runtime_source_file_count) === Number(handoff.evidence.current_runtime_source_file_count), "运行时证据与交接清单源码文件数不一致");
assert(evidence.status === "candidate_isolated_runtime_verified", "运行时证据未达到隔离接入验证状态");
assert(evidence.visual_status === "unverified", "运行时证据不得伪造视觉通过");
assert(evidence.release_allowed === false, "运行时证据不得标记为可发布");

const currentSource = execFileSync(process.execPath, ["scripts/source_fingerprint.mjs"], {cwd: root, encoding: "utf8"}).trim();
const match = currentSource.match(/^([0-9a-f]{64}) files=(\d+)$/);
assert(match, `当前源码指纹格式无效：${currentSource}`);
assert(match[1] === handoff.evidence.current_runtime_source_fingerprint, "交互道具交接清单未绑定当前正式运行时源码");
assert(Number(match[2]) === Number(handoff.evidence.current_runtime_source_file_count), "交互道具交接清单源码文件数过期");

for (const group of handoff.runtime_contract.required_groups) {
  assert(group.endsWith("_Interaction"), `交互道具运行时分组命名不符合约定：${group}`);
}
for (const requiredPath of [handoff.provenance.builder, handoff.evidence.integration_runner, handoff.evidence.integration_test]) {
  assert(fs.existsSync(path.join(root, requiredPath)), `交互道具交接引用文件不存在：${requiredPath}`);
}

console.log(`交互道具生产交接验证通过：${handoff.candidate_id}；运行时 ${match[1]}/${match[2]}；视觉未验收；不可发布`);
