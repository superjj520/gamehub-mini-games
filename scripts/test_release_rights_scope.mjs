import fs from "node:fs";
import {rightsAssetsForScope} from "./release_rights_scope.mjs";

const rights = JSON.parse(fs.readFileSync("gta-reference-runtime/content/rights-manifest.json", "utf8"));
const assets = rights.assets;
const office = rightsAssetsForScope(assets, "office_vertical_slice");
const officeAndCity = rightsAssetsForScope(assets, "office_and_city");

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const officeIds = new Set(office.map((asset) => asset.id));
for (const requiredId of [
  "graybox_geometry",
  "procedural_ui",
  "procedural_audio_cues",
  "original_procedural_audio_library_candidate",
  "original_three_wheel_delivery_candidate",
  "original_generated_office_glass_partition_v1",
  "original_procedural_player_character_candidate",
  "original_procedural_office_npc_candidate",
  "original_procedural_office_environment_candidate",
  "original_procedural_interaction_props_candidate",
]) assert(officeIds.has(requiredId), `办公室首发范围缺少权利映射：${requiredId}`);
assert(officeAndCity.some((asset) => asset.id === "original_generated_urban_storefront_v1"), "城市扩展范围缺少原创店铺候选");
assert(!office.some((asset) => asset.id === "quaternius_universal_base_character_candidate"), "办公室原创范围错误包含 Quaternius 角色候选");
assert(!officeAndCity.some((asset) => asset.id === "quaternius_downtown_city_standard_candidate"), "城市原创范围错误包含 Quaternius 城市候选");
assert(assets.find((asset) => asset.id === "original_procedural_player_character_candidate")?.asset_slot_ids?.includes("player-character"), "玩家槽位缺少原创权利映射");
assert(assets.find((asset) => asset.id === "original_procedural_office_npc_candidate")?.asset_slot_ids?.includes("office-npc-set"), "办公室 NPC 槽位缺少原创权利映射");
assert(assets.find((asset) => asset.id === "original_procedural_interaction_props_candidate")?.asset_slot_ids?.includes("interaction-props"), "交互道具槽位缺少原创权利映射");
for (const asset of assets) {
  assert(Array.isArray(asset.release_scope_ids), `资产缺少 release_scope_ids：${asset.id}`);
  assert(new Set(asset.release_scope_ids).size === asset.release_scope_ids.length, `资产范围重复：${asset.id}`);
}

console.log(`首发范围权利映射回归通过：办公室 ${office.length} 条，办公室与城市 ${officeAndCity.length} 条；第三方候选未被误纳入`);
