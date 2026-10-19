import crypto from "node:crypto";
import fs from "node:fs";
import {scopeDefinitions, resolveScope} from "./release_scope.mjs";

const decisionPath = "docs/product-baseline-decision.json";
const outputPath = "gta-reference-runtime/content/launch-profile.json";
const decision = JSON.parse(fs.readFileSync(decisionPath, "utf8"));
const decisionSha256 = crypto.createHash("sha256").update(fs.readFileSync(decisionPath)).digest("hex");
const entries = {
  office: {
    id: "office",
    shortcut: "1",
    title: "1  准点下班 · 办公室潜行",
    description: "办公室潜行、NPC感知、准点条件、失败与重试",
    scene_path: "res://scenes/benchmark.tscn",
    content_pack_id: "office-leave-on-time-v1",
    asset_catalog_path: "res://content/asset-runtime-catalog-original-only.json"
  },
  city: {
    id: "city",
    shortcut: "2",
    title: "2  中国街区任务 · 免费鸡蛋",
    description: "任务链、物品携带、三轮车、行人、冲突与城市存档",
    scene_path: "res://scenes/city.tscn",
    content_pack_id: "city-free-eggs-v1",
    asset_catalog_path: "res://content/asset-runtime-catalog-original-only.json"
  }
};

const requestedScope = resolveScope(decision.launch_scope);
let selectedEntries = Object.values(entries);
if (decision.status === "approved") {
  if (!requestedScope) throw new Error("已批准产品基线没有可解析的首发范围");
  const selectedKinds = requestedScope.assetIds.includes("city-environment-kit") ? ["office", "city"] : ["office"];
  selectedEntries = selectedKinds.map((kind) => entries[kind]);
}

const profile = {
  schema_version: 1,
  id: "launch-profile-v1",
  version: 1,
  status: decision.status,
  launch_scope: decision.launch_scope?.[0] ?? null,
  internal_development_mode: decision.status !== "approved",
  product_decision_sha256: decisionSha256,
  policy: "产品基线确认前保留办公室与城市内部开发入口；确认后只保留首发范围入口",
  entries: selectedEntries,
};
fs.writeFileSync(outputPath, `${JSON.stringify(profile, null, 2)}\n`, "utf8");
console.log(`运行时启动配置已生成：${outputPath}；状态 ${profile.status}；入口 ${profile.entries.map((entry) => entry.id).join("、")}`);
