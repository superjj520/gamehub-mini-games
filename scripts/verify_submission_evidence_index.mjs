import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const workspaceRoot = path.resolve(".");
const indexPath = path.join(workspaceRoot, "docs", "store-submission-evidence-index.json");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(workspaceRoot, relativePath), "utf8"));
}

function sha256(relativePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(path.join(workspaceRoot, relativePath))).digest("hex");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const index = readJson("docs/store-submission-evidence-index.json");
const releaseManifest = readJson("docs/release-manifest.json");
const readiness = readJson("docs/readiness-report.json");
const ownerInputs = readJson("docs/release-owner-inputs.json");
const productDecision = readJson("docs/product-baseline-decision.json");
const fullCandidatePlaytest = readJson("reference-evidence/candidate-runtime/full-candidate-playtest.json");
const originalOnlyCandidatePlaytest = readJson("reference-evidence/candidate-runtime/full-candidate-playtest-original-only.json");
const source = releaseManifest.source;

assert(index.schema_version === 1, "证据索引 schema 版本不受支持");
assert(index.status === "internal_no_go", "证据索引不得脱离 internal_no_go 状态");
assert(index.build_identity.source_sha256 === source.sha256, "证据索引源指纹与发布清单不一致");
assert(index.build_identity.source_file_count === source.file_count, "证据索引源文件数与发布清单不一致");
assert(index.decision === "仅允许内部开发验证，不得提交 Steam 商店", "证据索引提交决策错误");
assert(readiness.status === "internal_no_go", "证据索引绑定的发布准备报告不得为可发布状态");
assert(index.candidate_playtest.status === "candidate_isolated_full_playtest_verified", "统一候选试玩证据没有通过完整行为预检");
assert(index.candidate_playtest.source_sha256 === source.sha256, "统一候选试玩证据源指纹过期");
assert(index.candidate_playtest.source_file_count === source.file_count, "统一候选试玩证据源文件数过期");
assert(fullCandidatePlaytest.visual_status === "unverified" && fullCandidatePlaytest.release_allowed === false, "统一候选试玩证据不得升级为视觉或发布通过");
assert(index.candidate_playtest.entries.includes("office-candidate") && index.candidate_playtest.entries.includes("city-candidate"), "统一候选试玩证据缺少办公室或城市入口");
assert(index.release_candidate?.variant === "original_only", "正式候选必须绑定原创边界变体");
assert(index.release_candidate?.source_sha256 === source.sha256, "正式候选源指纹过期");
assert(index.release_candidate?.source_file_count === source.file_count, "正式候选源文件数过期");
assert(index.release_candidate?.status === originalOnlyCandidatePlaytest.status, "正式候选试玩状态不一致");
assert(index.release_candidate?.visual_status === "unverified" && index.release_candidate?.release_allowed === false, "正式候选不得绕过视觉或发布门禁");
assert(fs.existsSync(path.join(workspaceRoot, index.release_candidate.playtest_path)), "正式候选试玩证据不存在");
assert(fs.existsSync(path.join(workspaceRoot, index.release_candidate.qa_bundle_path)), "正式候选 Windows QA 包不存在");
assert(index.metadata_profile.product_name === productDecision.product_name, "证据索引产品名称与产品基线不一致");
assert(JSON.stringify(index.metadata_profile.launch_platforms) === JSON.stringify(productDecision.launch_platforms), "证据索引平台与产品基线不一致");
assert(JSON.stringify(index.metadata_profile.launch_regions_and_languages) === JSON.stringify(productDecision.launch_regions_and_languages), "证据索引地区语言与产品基线不一致");
assert(index.metadata_profile.support_status.includes("待确认"), "证据索引不得把客服状态标记为已完成");
assert(index.metadata_profile.privacy_status.includes("待确认"), "证据索引不得把隐私政策状态标记为已完成");
assert(index.metadata_profile.age_rating_status.includes("待确认"), "证据索引不得把年龄分级状态标记为已完成");

for (const packageEntry of index.packages) {
  assert(packageEntry.exists === true, `候选包不存在：${packageEntry.path}`);
  assert(typeof packageEntry.path === "string" && packageEntry.path.startsWith("build/"), `候选包路径不在 build 下：${packageEntry.path}`);
  assert(packageEntry.source_sha256 === source.sha256, `候选包源指纹过期：${packageEntry.path}`);
  assert(packageEntry.source_file_count === source.file_count, `候选包源文件数过期：${packageEntry.path}`);
  assert(packageEntry.status !== "release_candidate", `证据索引错误地把内部包标记为发布候选：${packageEntry.path}`);
  assert(sha256(packageEntry.path) === packageEntry.sha256, `候选包哈希不一致：${packageEntry.path}`);
  assert(fs.statSync(path.join(workspaceRoot, packageEntry.path)).size === packageEntry.bytes, `候选包大小不一致：${packageEntry.path}`);
}

for (const gate of index.gate_matrix) {
  assert(Array.isArray(gate.evidence) && gate.evidence.length > 0, `门禁缺少证据路径：${gate.id}`);
  for (const evidencePath of gate.evidence) {
    assert(fs.existsSync(path.join(workspaceRoot, evidencePath)), `门禁证据路径不存在：${gate.id} -> ${evidencePath}`);
  }
}

const visualGate = index.gate_matrix.find((gate) => gate.id === "visual_matrix");
assert(visualGate?.status === "blocked_unverified", "视觉门禁不得被索引标记为通过");
assert(["unverified_current_binding", "unverified_and_binding_mismatch"].includes(visualGate.binding.status), "视觉矩阵必须明确保持未验收状态");
const visualBindingMatches = visualGate.binding.current_source_sha256 === visualGate.binding.recorded_source_sha256 && visualGate.binding.current_source_file_count === visualGate.binding.recorded_source_file_count;
assert((visualGate.binding.status === "unverified_current_binding") === visualBindingMatches, "视觉矩阵绑定状态与源指纹事实不一致");
const expandedGate = index.gate_matrix.find((gate) => gate.id === "expanded_visual_matrix");
assert(expandedGate?.status === "blocked_unverified", "扩展视觉门禁不得被索引标记为通过");
const storeGate = index.gate_matrix.find((gate) => gate.id === "store_compliance");
assert(storeGate?.strict_materials?.status === "blocked_pending_owner_inputs", "商店严格材料状态应明确阻断待负责人输入");
assert(storeGate.strict_materials.unresolved_count === ownerInputs.inputs.filter((input) => input.status !== "confirmed").length, "商店待定字段数量与负责人输入清单不一致");
assert(index.owner_inputs.every((input) => input.value_present === false), "证据索引不应复制或填充未确认的负责人值");
assert(index.forbidden_content.includes("参考视频"), "证据索引缺少参考视频禁入声明");

console.log(`商店提交证据索引验证通过：状态 ${index.status}；源指纹 ${source.sha256}/${source.file_count}；候选包 ${index.packages.length} 个；视觉门禁仍为阻断`);
