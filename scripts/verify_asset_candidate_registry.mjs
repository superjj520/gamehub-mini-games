import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const registryPath = path.resolve("docs/asset-candidate-registry.json");
const registry = JSON.parse(fs.readFileSync(registryPath, "utf8"));
const releaseManifestPath = path.resolve("docs/release-manifest.json");
const releaseManifest = fs.existsSync(releaseManifestPath)
  ? JSON.parse(fs.readFileSync(releaseManifestPath, "utf8"))
  : null;
if (registry.schema_version !== 1) throw new Error("候选资产登记表 schema 版本不受支持");
if (registry.status !== "candidate_only") throw new Error("候选资产登记表不得脱离 candidate_only 状态");
if (!Array.isArray(registry.candidates) || registry.candidates.length === 0) throw new Error("候选资产登记表为空");

const ids = new Set();
for (const candidate of registry.candidates) {
  if (!candidate.id || ids.has(candidate.id)) throw new Error(`候选资产 id 为空或重复：${candidate.id}`);
  ids.add(candidate.id);
  if (candidate.release_allowed !== false) throw new Error(`候选资产不得标记为可发布：${candidate.id}`);
  if (!candidate.visual_status || candidate.visual_status === "passed") throw new Error(`候选资产视觉状态错误：${candidate.id}`);
  for (const evidencePath of candidate.evidence ?? []) {
    if (!fs.existsSync(path.resolve(evidencePath))) throw new Error(`候选资产证据不存在：${candidate.id} -> ${evidencePath}`);
  }
  if (candidate.visual_evidence) {
    const visualEvidence = candidate.visual_evidence;
    const visualPath = path.resolve(visualEvidence.path ?? "");
    if (!fs.existsSync(visualPath)) throw new Error(`候选资产视觉证据不存在：${candidate.id} -> ${visualEvidence.path}`);
    const visualSha256 = crypto.createHash("sha256").update(fs.readFileSync(visualPath)).digest("hex");
    if (visualSha256 !== visualEvidence.sha256) throw new Error(`候选资产视觉证据哈希不匹配：${candidate.id}`);
    if (!/^\d{4}-\d{2}-\d{2}T/.test(String(visualEvidence.captured_at ?? ""))) {
      throw new Error(`候选资产视觉证据缺少采集时间：${candidate.id}`);
    }
    if (releaseManifest && visualEvidence.source_fingerprint !== releaseManifest.source.sha256) {
      throw new Error(`候选资产视觉证据源指纹不匹配：${candidate.id}`);
    }
  }
  if (candidate.integration_status === "verified_in_isolated_asset_override_test") {
    for (const requiredPath of [candidate.runtime_scene, candidate.runtime_script]) {
      if (!requiredPath || !fs.existsSync(path.resolve(requiredPath))) throw new Error(`已接入候选资产缺少运行时文件：${candidate.id} -> ${requiredPath}`);
    }
  }
  if (candidate.integration_status === "blocked_tool_crash_no_output" && !candidate.blocker) {
    throw new Error(`工具阻断候选资产缺少 blocker 说明：${candidate.id}`);
  }
}

console.log(`候选资产登记验证通过：${registry.candidates.length} 项；全部保持不可发布且视觉未签收`);
