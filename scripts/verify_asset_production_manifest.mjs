import fs from "node:fs";
import path from "node:path";

const manifestPath = path.resolve("docs/asset-production-manifest.json");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const productDecision = JSON.parse(fs.readFileSync(path.resolve("docs/product-baseline-decision.json"), "utf8"));
const runtimeCatalogPath = path.resolve(manifest.runtime_catalog);
const runtimeCatalog = JSON.parse(fs.readFileSync(runtimeCatalogPath, "utf8"));
if (manifest.schema_version !== 2) throw new Error("资产生产清单 schema 版本不受支持");
const baselineApproved = productDecision.status === "approved";
const expectedManifestStatus = baselineApproved ? "p0_production_authorized" : "preproduction_pending_product_baseline";
if (manifest.status !== expectedManifestStatus) {
  throw new Error(`资产生产清单状态与产品基线不一致：期望 ${expectedManifestStatus}`);
}
if (baselineApproved && manifest.visual_direction !== productDecision.visual_direction) {
  throw new Error("已确认产品基线的视觉方向没有同步到资产生产清单");
}
if (!baselineApproved && manifest.visual_direction !== "待用户定稿") {
  throw new Error("待确认产品基线的资产生产清单不得提前锁定视觉方向");
}
if (manifest.runtime_catalog !== "gta-reference-runtime/content/asset-runtime-catalog.json") {
  throw new Error("资产生产清单没有绑定运行时资产目录");
}
if (!fs.existsSync(path.resolve(manifest.runtime_catalog))) {
  throw new Error("运行时资产目录文件不存在");
}
if (manifest.audio_runtime_catalog !== "gta-reference-runtime/content/audio-runtime-catalog.json") {
  throw new Error("资产生产清单没有绑定运行时音频目录");
}
if (!fs.existsSync(path.resolve(manifest.audio_runtime_catalog))) {
  throw new Error("运行时音频目录文件不存在");
}
if (!Array.isArray(manifest.slots) || manifest.slots.length < 8) {
  throw new Error("资产生产清单槽位不完整");
}
if (!Array.isArray(runtimeCatalog.slots) || runtimeCatalog.slots.length !== manifest.slots.length) {
  throw new Error("资产生产清单与运行时资产目录的槽位数量不一致");
}
const ids = new Set();
const runtimeSlots = new Map(runtimeCatalog.slots.map((slot) => [slot.id, slot]));
const isCandidateScenePath = (scenePath) => typeof scenePath === "string"
  && scenePath.startsWith("res://")
  && scenePath.toLowerCase().includes("candidate");
const supportedAnimationSets = new Set([
  "idle_default",
  "walk_default",
  "crouch_default",
  "interact_default",
  "vehicle_default",
  "hit_default",
  "fail_default",
  "search_default",
  "alert_default",
  "displaced_default",
]);
for (const slot of manifest.slots) {
  if (!slot.id || ids.has(slot.id)) throw new Error(`资产生产清单存在空 id 或重复 id：${slot.id}`);
  ids.add(slot.id);
  const runtimeSlot = runtimeSlots.get(slot.id);
  if (!runtimeSlot) throw new Error(`资产生产清单槽位没有运行时目录映射：${slot.id}`);
  if (runtimeSlot.category !== slot.category) throw new Error(`资产槽位分类不一致：${slot.id}`);
  if (slot.status !== "graybox") throw new Error(`未确认的资产槽位不得标记为最终状态：${slot.id}`);
  if (slot.release_allowed !== false) throw new Error(`灰盒资产槽位不得标记为可发布：${slot.id}`);
  if (!Array.isArray(slot.acceptance) || slot.acceptance.length === 0) throw new Error(`资产槽位缺少验收条件：${slot.id}`);
  if (!Array.isArray(slot.runtime_contract) || slot.runtime_contract.length === 0) throw new Error(`资产槽位缺少运行时契约：${slot.id}`);
  if (!Array.isArray(slot.required_evidence) || slot.required_evidence.length === 0) throw new Error(`资产槽位缺少必需证据：${slot.id}`);
  if (!Array.isArray(slot.required_animation_sets) || slot.required_animation_sets.some((animationName) => !supportedAnimationSets.has(animationName))) {
    throw new Error(`资产槽位包含未登记动画状态：${slot.id}`);
  }
  const allowedIntegrationStatuses = new Set(["not_started", "candidate_integrated_unverified"]);
  if (!allowedIntegrationStatuses.has(slot.integration_status)) {
    throw new Error(`未确认的资产槽位只能保持未开始或候选接入未验证：${slot.id}`);
  }
  if (slot.rights_status !== "pending_final_asset_source") throw new Error(`资产槽位权利状态错误：${slot.id}`);
  const expectedPlatformStatus = baselineApproved ? "steam_windows_target_device_pending" : "pending_platform_confirmation";
  if (slot.platform_status !== expectedPlatformStatus) throw new Error(`资产槽位平台状态错误：${slot.id}`);
  if (runtimeSlot.scene_path !== "") {
    if (slot.integration_status !== "candidate_integrated_unverified" || !isCandidateScenePath(runtimeSlot.scene_path)) {
      throw new Error(`灰盒资产槽位不应提前挂载正式场景：${slot.id}`);
    }
  }
  if (runtimeSlot.fallback_policy !== "procedural_graybox") throw new Error(`灰盒资产槽位必须保留程序化回退：${slot.id}`);
}
for (const runtimeSlot of runtimeCatalog.slots) {
  if (!ids.has(runtimeSlot.id)) throw new Error(`运行时资产目录存在未登记槽位：${runtimeSlot.id}`);
}
console.log(`资产生产清单验证通过：${manifest.slots.length} 个槽位，P0 生产已授权；契约/证据/权利/平台字段完整，全部保持灰盒待交付`);
