import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const reviewPath = path.join(root, "reference-evidence/candidate-runtime/candidate-art-review-2026-10-10.json");
const review = JSON.parse(fs.readFileSync(reviewPath, "utf8"));

if (review.schema_version !== 1) throw new Error("候选环境资产审阅记录 schema_version 无效");
if (review.review_status !== "candidate_provisional") throw new Error("候选环境资产审阅记录不得越过 candidate_provisional");
if (review.visual_acceptance_status !== "unverified") throw new Error("候选环境资产审阅记录不得自动升级视觉状态");
if (review.release_allowed !== false) throw new Error("候选环境资产审阅记录不得声明可发布");
if (!Array.isArray(review.assets) || review.assets.length !== 4) throw new Error("候选环境资产审阅记录必须覆盖 4 项环境候选");

function readPngDimensions(bytes, assetId) {
  const signature = Buffer.from("89504e470d0a1a0a", "hex");
  if (!bytes.subarray(0, 8).equals(signature)) throw new Error(`${assetId} 不是 PNG`);
  return [bytes.readUInt32BE(16), bytes.readUInt32BE(20)];
}

for (const asset of review.assets) {
  if (asset.runtime_acceptance !== "pending_current_graphical_capture") {
    throw new Error(`${asset.id} 的运行时验收状态不安全：${asset.runtime_acceptance}`);
  }
  const assetPath = path.join(root, asset.path);
  if (!fs.existsSync(assetPath)) throw new Error(`${asset.id} 文件不存在：${asset.path}`);
  const bytes = fs.readFileSync(assetPath);
  const dimensions = readPngDimensions(bytes, asset.id);
  const hash = crypto.createHash("sha256").update(bytes).digest("hex");
  if (hash !== asset.sha256) throw new Error(`${asset.id} SHA-256 已漂移：记录 ${asset.sha256}，实际 ${hash}`);
  if (dimensions[0] !== asset.dimensions[0] || dimensions[1] !== asset.dimensions[1]) {
    throw new Error(`${asset.id} 尺寸已漂移：记录 ${asset.dimensions.join("×")}，实际 ${dimensions.join("×")}`);
  }
}

console.log(`候选环境资产审阅验证通过：${review.assets.length} 项；状态 ${review.review_status}；视觉 ${review.visual_acceptance_status}；不可发布`);
