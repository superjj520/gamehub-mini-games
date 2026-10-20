import fs from "node:fs";
import {resolveScope, scopeDefinitions} from "./release_scope.mjs";

const assets = JSON.parse(fs.readFileSync("docs/asset-production-manifest.json", "utf8"));
const acceptance = JSON.parse(fs.readFileSync("reference-evidence/acceptance-status.json", "utf8"));
const matrix = JSON.parse(fs.readFileSync("reference-evidence/runtime-matrix/manifest.json", "utf8"));
const assetIds = new Set(assets.slots.map((slot) => slot.id));
const acceptanceIds = new Set(acceptance.segments.map((segment) => segment.id));
const captureIds = new Set(matrix.captures.map((capture) => capture.id));
const errors = [];

function assert(condition, message) {
  if (!condition) errors.push(message);
}

assert(resolveScope([]) === null, "空首发范围不应解析为有效范围");
assert(resolveScope(["unknown_scope"]) === null, "未知首发范围不应解析为有效范围");
for (const [scopeId, scope] of Object.entries(scopeDefinitions)) {
  const uniqueSegments = new Set(scope.segmentIds);
  const uniqueAssets = new Set(scope.assetIds);
  assert(uniqueSegments.size === scope.segmentIds.length, `首发范围分段重复：${scopeId}`);
  assert(uniqueAssets.size === scope.assetIds.length, `首发范围资产重复：${scopeId}`);
  for (const segmentId of scope.segmentIds) {
    assert(acceptanceIds.has(segmentId), `首发范围缺少参考验收分段：${scopeId}/${segmentId}`);
    assert(captureIds.has(segmentId), `首发范围缺少运行时截图分段：${scopeId}/${segmentId}`);
  }
  for (const assetId of scope.assetIds) {
    assert(assetIds.has(assetId), `首发范围缺少资产槽位：${scopeId}/${assetId}`);
  }
}

const office = scopeDefinitions.office_vertical_slice;
const complete = scopeDefinitions.office_and_city;
assert(complete.segmentIds.length > office.segmentIds.length, "完整双内容包没有扩展办公室分段");
assert(complete.assetIds.length > office.assetIds.length, "完整双内容包没有扩展办公室资产");

if (errors.length > 0) {
  console.error(`首发范围映射校验阻断：${errors.length} 项`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`首发范围映射校验通过：${Object.keys(scopeDefinitions).join("、")}；A=${office.segmentIds.length} 段/${office.assetIds.length} 槽位，B=${complete.segmentIds.length} 段/${complete.assetIds.length} 槽位`);
