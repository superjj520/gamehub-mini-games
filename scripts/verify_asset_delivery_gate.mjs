import fs from "node:fs";
import path from "node:path";

const manifestPath = "docs/asset-production-manifest.json";
const runtimeCatalogPath = "gta-reference-runtime/content/asset-runtime-catalog.json";
const audioCatalogPath = "gta-reference-runtime/content/audio-runtime-catalog.json";
const rightsManifestPath = "gta-reference-runtime/content/rights-manifest.json";

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function resolveProjectPath(filePath) {
  const resolved = path.resolve(filePath);
  const projectRoot = path.resolve(".");
  assert(resolved === projectRoot || resolved.startsWith(`${projectRoot}${path.sep}`), `资产证据路径越出工程目录：${filePath}`);
  return resolved;
}

function resolveRuntimeResource(resourcePath) {
  assert(typeof resourcePath === "string" && resourcePath.startsWith("res://"), `运行时资源路径必须位于 res://：${resourcePath}`);
  const relativePath = resourcePath.slice("res://".length);
  const resolved = path.resolve("gta-reference-runtime", relativePath);
  const runtimeRoot = path.resolve("gta-reference-runtime");
  assert(resolved.startsWith(`${runtimeRoot}${path.sep}`), `运行时资源路径越出运行时目录：${resourcePath}`);
  return resolved;
}

function validateOptionalRuntimePath(resourcePath, label) {
  if (resourcePath === "") return;
  const resolved = resolveRuntimeResource(resourcePath);
  assert(fs.existsSync(resolved), `${label}不存在：${resourcePath}`);
  assert([".tscn", ".scn", ".tres", ".res", ".ogg", ".wav", ".mp3"].includes(path.extname(resolved)), `${label}扩展名不受支持：${resourcePath}`);
}

function isCandidateScenePath(resourcePath) {
  return typeof resourcePath === "string"
    && resourcePath.startsWith("res://")
    && resourcePath.toLowerCase().includes("candidate");
}

const manifest = readJson(manifestPath);
const runtimeCatalog = readJson(runtimeCatalogPath);
const audioCatalog = readJson(audioCatalogPath);
const rightsManifest = readJson(rightsManifestPath);

assert(manifest.schema_version === 2, "资产生产清单 schema 版本不受资产交付门禁支持");
assert(Array.isArray(manifest.slots) && manifest.slots.length > 0, "资产生产清单没有槽位");
assert(Array.isArray(runtimeCatalog.slots), "运行时资产目录没有 slots");
assert(Array.isArray(audioCatalog.events), "运行时音频目录没有 events");
assert(Array.isArray(rightsManifest.assets), "权利清单没有 assets");

const runtimeSlots = new Map(runtimeCatalog.slots.map((slot) => [slot.id, slot]));
const rightsAssets = new Map(rightsManifest.assets.map((asset) => [asset.id, asset]));
const rightsAssetsBySlot = new Map();
for (const asset of rightsManifest.assets) {
  for (const slotId of asset.asset_slot_ids ?? []) {
    assert(!rightsAssetsBySlot.has(slotId), `资产槽位存在多个未区分来源的权利记录：${slotId}`);
    rightsAssetsBySlot.set(slotId, asset);
  }
}
const knownFallbackPolicies = new Set(["procedural_graybox", "forbid"]);
const readyStatuses = new Set(["release_candidate", "ready"]);
const readyIntegrations = new Set(["integrated", "verified"]);
const readyRights = new Set(["approved", "granted"]);
const readyPlatforms = new Set(["approved", "verified"]);
const ids = new Set();
let pendingCount = 0;
let readyCount = 0;

for (const slot of manifest.slots) {
  assert(slot && typeof slot === "object", "资产生产清单存在非对象槽位");
  assert(typeof slot.id === "string" && slot.id.length > 0, "资产生产清单存在空 id");
  assert(!ids.has(slot.id), `资产生产清单存在重复 id：${slot.id}`);
  ids.add(slot.id);

  const runtimeSlot = runtimeSlots.get(slot.id);
  assert(runtimeSlot, `资产槽位没有运行时目录映射：${slot.id}`);
  assert(runtimeSlot.category === slot.category, `资产槽位分类与运行时目录不一致：${slot.id}`);
  assert(knownFallbackPolicies.has(runtimeSlot.fallback_policy), `资产槽位回退策略未登记：${slot.id}`);
  validateOptionalRuntimePath(runtimeSlot.scene_path, `资产槽位运行时场景 ${slot.id}`);

  const claimsRelease = slot.release_allowed === true;
  const claimsReady = readyStatuses.has(slot.status) || readyIntegrations.has(slot.integration_status);
  const claimsPartialDelivery = manifest.status !== "p0_production_authorized"
    && (slot.rights_status !== "pending_final_asset_source" || slot.platform_status !== "pending_platform_confirmation");
  const isDeliveryClaimed = claimsRelease || claimsReady || claimsPartialDelivery;

  if (!isDeliveryClaimed) {
    pendingCount += 1;
    assert(slot.status === "graybox", `未声明成品的资产槽位状态必须保持 graybox：${slot.id}`);
    assert(slot.release_allowed === false, `灰盒资产槽位不得允许发布：${slot.id}`);
    if (runtimeSlot.scene_path !== "") {
      assert(slot.integration_status === "candidate_integrated_unverified", `灰盒资产槽位只能预挂候选接入场景：${slot.id}`);
      assert(isCandidateScenePath(runtimeSlot.scene_path), `灰盒资产槽位不能预挂非候选正式场景：${slot.id}`);
    }
    assert(runtimeSlot.fallback_policy === "procedural_graybox", `灰盒资产槽位必须明确程序化回退：${slot.id}`);
    continue;
  }

  readyCount += 1;
  assert(manifest.status !== "preproduction_pending_product_baseline", `产品基线仍待确认时不能声明成品资产：${slot.id}`);
  assert(slot.status === "release_candidate", `资产交付槽位必须标记为 release_candidate：${slot.id}`);
  assert(slot.release_allowed === true, `资产交付槽位必须明确允许发布：${slot.id}`);
  assert(slot.integration_status === "integrated", `资产交付槽位尚未完成运行时接入：${slot.id}`);
  assert(readyRights.has(slot.rights_status), `资产交付槽位权利状态未签收：${slot.id}`);
  assert(readyPlatforms.has(slot.platform_status), `资产交付槽位平台状态未签收：${slot.id}`);
  assert(typeof slot.asset_package === "string" && slot.asset_package.length > 0, `资产交付槽位缺少 asset_package：${slot.id}`);
  assert(fs.existsSync(resolveProjectPath(slot.asset_package)), `资产交付包不存在：${slot.id} -> ${slot.asset_package}`);
  assert(Array.isArray(slot.delivery_evidence) && slot.delivery_evidence.length > 0, `资产交付槽位缺少 delivery_evidence：${slot.id}`);
  for (const evidencePath of slot.delivery_evidence) {
    assert(typeof evidencePath === "string" && evidencePath.length > 0, `资产交付证据路径为空：${slot.id}`);
    assert(fs.existsSync(resolveProjectPath(evidencePath)), `资产交付证据不存在：${slot.id} -> ${evidencePath}`);
  }
  const rightsAsset = rightsAssets.get(slot.id) ?? rightsAssetsBySlot.get(slot.id);
  assert(rightsAsset?.release_allowed === true, `资产交付槽位没有同 id 的可发布权利记录：${slot.id}`);

  if (slot.category === "audio") {
    for (const event of audioCatalog.events) {
      assert(typeof event.stream_path === "string" && event.stream_path.length > 0, `最终音频槽位存在空 stream_path：${slot.id}/${event.id}`);
      assert(event.fallback_policy === "forbid", `最终音频槽位仍允许静默回退：${slot.id}/${event.id}`);
      validateOptionalRuntimePath(event.stream_path, `音频事件 ${event.id}`);
    }
  } else {
    assert(typeof runtimeSlot.scene_path === "string" && runtimeSlot.scene_path.length > 0, `最终资产槽位缺少 scene_path：${slot.id}`);
    assert(runtimeSlot.fallback_policy === "forbid", `最终资产槽位仍允许静默回退灰盒：${slot.id}`);
    assert([".tscn", ".scn"].includes(path.extname(resolveRuntimeResource(runtimeSlot.scene_path))), `最终资产槽位必须挂载 PackedScene：${slot.id}`);
  }
}

for (const runtimeSlot of runtimeCatalog.slots) {
  assert(ids.has(runtimeSlot.id), `运行时资产目录存在未登记槽位：${runtimeSlot.id}`);
}

console.log(`资产交付门禁通过：${pendingCount} 个槽位保持显式灰盒回退，${readyCount} 个槽位完成成品交付契约校验；不存在成品资产静默回退。`);
