import crypto from "node:crypto";
import fs from "node:fs";
import {resolveScope} from "./release_scope.mjs";

const decisionPath = "docs/product-baseline-decision.json";
const profilePath = "gta-reference-runtime/content/launch-profile.json";
const decision = JSON.parse(fs.readFileSync(decisionPath, "utf8"));
const profile = JSON.parse(fs.readFileSync(profilePath, "utf8"));
const expectedDecisionSha256 = crypto.createHash("sha256").update(fs.readFileSync(decisionPath)).digest("hex");
const allEntries = {
  office: {scene_path: "res://scenes/benchmark.tscn", content_pack_id: "office-leave-on-time-v1", asset_catalog_path: "res://content/asset-runtime-catalog-original-only.json"},
  city: {scene_path: "res://scenes/city.tscn", content_pack_id: "city-free-eggs-v1", asset_catalog_path: "res://content/asset-runtime-catalog-original-only.json"},
};

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

assert(profile.schema_version === 1, "运行时启动配置 schema 版本不受支持");
assert(profile.id === "launch-profile-v1" && profile.version === 1, "运行时启动配置缺少稳定 id/version");
assert(profile.status === decision.status, "运行时启动配置状态与产品基线不一致");
assert(profile.product_decision_sha256 === expectedDecisionSha256, "运行时启动配置未绑定当前产品基线");
assert(Array.isArray(profile.entries) && profile.entries.length > 0, "运行时启动配置没有入口");
const requestedScope = resolveScope(decision.launch_scope);
const expectedKinds = decision.status === "approved"
  ? (requestedScope.assetIds.includes("city-environment-kit") ? ["office", "city"] : ["office"])
  : ["office", "city"];
assert(JSON.stringify(profile.entries.map((entry) => entry.id)) === JSON.stringify(expectedKinds), "运行时启动入口与产品范围不一致");
assert(profile.launch_scope === (decision.launch_scope?.[0] ?? null), "运行时启动配置 launch_scope 不一致");
for (const entry of profile.entries) {
  assert(allEntries[entry.id], `运行时启动配置包含未知入口：${entry.id}`);
  assert(entry.scene_path === allEntries[entry.id].scene_path, `运行时启动配置场景路径错误：${entry.id}`);
  assert(entry.content_pack_id === allEntries[entry.id].content_pack_id, `运行时启动配置内容包错误：${entry.id}`);
  assert(entry.asset_catalog_path === allEntries[entry.id].asset_catalog_path, `运行时启动配置资产目录错误：${entry.id}`);
  assert(entry.asset_catalog_path.startsWith("res://") && entry.asset_catalog_path.endsWith(".json"), `运行时启动配置资产目录不是 JSON 路径：${entry.id}`);
  assert(entry.scene_path.startsWith("res://") && entry.scene_path.endsWith(".tscn"), `运行时启动配置场景不是 PackedScene 路径：${entry.id}`);
}
console.log(`运行时启动配置验证通过：状态 ${profile.status}；入口 ${profile.entries.map((entry) => entry.id).join("、")}`);
