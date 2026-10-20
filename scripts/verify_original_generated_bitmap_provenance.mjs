import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import sharp from "sharp";

const root = process.cwd();
const provenancePath = path.join(root, "docs/original-generated-bitmap-provenance.json");

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

if (!fs.existsSync(provenancePath)) throw new Error("原创生成位图来源证据不存在");
const provenance = readJson(provenancePath);
if (provenance.schema_version !== 1) throw new Error("原创生成位图来源证据 schema_version 异常");
if (provenance.status !== "internal_candidate_provenance_recorded") {
  throw new Error("原创生成位图来源证据必须保持内部候选状态");
}
if (provenance.release_allowed !== false) throw new Error("原创生成位图来源证据不能声明可发布");

const assets = provenance.assets ?? [];
if (assets.length !== 3) throw new Error(`原创生成位图来源证据应登记 3 个当前缺失元数据的候选，实际为 ${assets.length} 个`);
const ids = assets.map((asset) => asset.asset_id);
if (new Set(ids).size !== ids.length) throw new Error("原创生成位图来源证据存在重复 asset_id");

for (const asset of assets) {
  if (!asset.asset_id || !asset.slot_id || asset.source_kind !== "ai_generated_original_bitmap") {
    throw new Error(`原创生成位图条目字段不完整：${asset.asset_id ?? "未命名"}`);
  }
  if (asset.release_allowed !== false || asset.visual_status !== "unverified") {
    throw new Error(`原创生成位图必须保持 visual_status=unverified 且不可发布：${asset.asset_id}`);
  }
  if (asset.generator !== "内置图像生成工具") throw new Error(`原创生成位图生成器声明异常：${asset.asset_id}`);
  if (!Array.isArray(asset.dimensions) || asset.dimensions.length !== 2) {
    throw new Error(`原创生成位图尺寸记录异常：${asset.asset_id}`);
  }
  const filePath = path.join(root, asset.runtime_asset);
  if (!fs.existsSync(filePath)) throw new Error(`原创生成位图运行时文件不存在：${asset.runtime_asset}`);
  const actualHash = sha256(filePath);
  if (actualHash !== asset.runtime_sha256) {
    throw new Error(`原创生成位图哈希不一致：${asset.runtime_asset}`);
  }
  const metadata = await sharp(filePath).metadata();
  if (metadata.width !== asset.dimensions[0] || metadata.height !== asset.dimensions[1]) {
    throw new Error(`原创生成位图尺寸不一致：${asset.runtime_asset}`);
  }
  if (!Array.isArray(asset.constraints) || asset.constraints.length < 3) {
    throw new Error(`原创生成位图缺少使用边界：${asset.asset_id}`);
  }
}

console.log(`原创生成位图来源证据通过：${assets.length} 个；视觉、Windows 设备和最终权利签收仍未通过`);
