import fs from "node:fs";
import crypto from "node:crypto";

const manifestPath = "gta-reference-runtime/content/rights-manifest.json";
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const evidencePath = "reference-evidence/manifest.json";
const evidence = JSON.parse(fs.readFileSync(evidencePath, "utf8"));

if (!Array.isArray(manifest.assets) || !Array.isArray(manifest.third_party_components)) {
  throw new Error("权利清单缺少资产或第三方组件数组");
}
if (!Array.isArray(evidence.sources) || evidence.sources.some((source) => source.release_allowed !== false)) {
  throw new Error("参考证据库必须全部标记为不可发布");
}

let evidenceFrames = 0;
for (const source of evidence.sources) {
  if (!source.source_path || !source.source_sha256) {
    throw new Error(`参考视频缺少来源路径或 SHA-256：${source.id}`);
  }
  if (!fs.existsSync(source.source_path)) {
    throw new Error(`参考视频来源不存在，无法复核：${source.source_path}`);
  }
  const sourceHash = crypto.createHash("sha256").update(fs.readFileSync(source.source_path)).digest("hex");
  if (sourceHash !== source.source_sha256) {
    throw new Error(`参考视频来源指纹不匹配：${source.id}`);
  }
  for (const segment of source.segments ?? []) {
    evidenceFrames += 1;
    const imagePath = `reference-evidence/${segment.image}`;
    if (!fs.existsSync(imagePath)) {
      throw new Error(`参考证据帧不存在：${imagePath}`);
    }
    if (!segment.sha256) {
      throw new Error(`参考证据帧缺少 SHA-256：${segment.id}`);
    }
    const actualHash = crypto.createHash("sha256").update(fs.readFileSync(imagePath)).digest("hex");
    if (actualHash !== segment.sha256) {
      throw new Error(`参考证据帧指纹不匹配：${segment.id}`);
    }
  }
}

for (const asset of manifest.assets) {
  if (!asset.id || !asset.type || !asset.source || !asset.rights) {
    throw new Error(`资产条目字段不完整：${asset.id ?? "未命名"}`);
  }
  if (typeof asset.release_candidate_required !== "boolean") {
    throw new Error(`资产条目缺少 release_candidate_required：${asset.id}`);
  }
}

for (const component of manifest.third_party_components) {
  if (!component.id || !component.source || !component.status || !component.license) {
    throw new Error(`第三方组件条目字段不完整：${component.id ?? "未命名"}`);
  }
  if (component.status === "in_use" && component.release_allowed !== true) {
    throw new Error(`在用第三方组件不可发布：${component.id}`);
  }
}

const allowedAssets = manifest.assets.filter((asset) => asset.release_allowed === true).length;
const requiredBlockedAssets = manifest.assets.filter((asset) => asset.release_candidate_required === true && asset.release_allowed !== true).length;
const excludedInternalAssets = manifest.assets.filter((asset) => asset.release_candidate_required === false).length;
const inUseComponents = manifest.third_party_components.filter((component) => component.status === "in_use").length;

console.log(`资产权利清单验证通过：可发布资产 ${allowedAssets} 项，候选包必需但未授权资产 ${requiredBlockedAssets} 项，明确排除的内部资产 ${excludedInternalAssets} 项，在用第三方组件 ${inUseComponents} 项，参考证据帧 ${evidenceFrames} 张`);
