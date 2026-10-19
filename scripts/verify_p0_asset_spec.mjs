import fs from "node:fs";

const manifest = JSON.parse(fs.readFileSync("docs/asset-production-manifest.json", "utf8"));
const required = new Map([
  ["player-character", ["idle_default", "walk_default", "crouch_default", "interact_default", "vehicle_default", "hit_default", "fail_default"]],
  ["office-npc-set", ["idle_default", "walk_default", "search_default", "alert_default"]],
  ["office-environment-kit", []],
  ["city-environment-kit", []],
  ["three-wheel-vehicle", []],
]);
const errors = [];
const slots = new Map((manifest.slots ?? []).map((slot) => [slot.id, slot]));

for (const [id, animationNames] of required) {
  const slot = slots.get(id);
  if (!slot) {
    errors.push(`P0 资产槽位缺失：${id}`);
    continue;
  }
  if (slot.status !== "graybox") {
    errors.push(`P0 资产槽位必须保持显式灰盒或候选状态：${id}`);
  }
  if (slot.release_allowed !== false) {
    errors.push(`P0 资产槽位不能在未完成权利和视觉验收前允许发布：${id}`);
  }
  for (const animationName of animationNames) {
    if (!slot.required_animation_sets?.includes(animationName)) {
      errors.push(`P0 资产槽位缺少动画契约：${id}/${animationName}`);
    }
  }
  if (!Array.isArray(slot.required_evidence) || slot.required_evidence.length === 0) {
    errors.push(`P0 资产槽位缺少证据出口：${id}`);
  }
}

const vehicle = slots.get("three-wheel-vehicle");
if (vehicle && !vehicle.acceptance.includes("载具耐久 HUD 与失败反馈")) {
  errors.push("三轮车 P0 规格缺少耐久 HUD 与失败反馈验收");
}
const city = slots.get("city-environment-kit");
if (city && (!city.acceptance.includes("后场仓储入口与装卸点构图") || !city.acceptance.includes("白天/黄昏/雨后光照配置"))) {
  errors.push("城市环境 P0 规格缺少仓储或天气视觉验收");
}

if (errors.length > 0) {
  console.error(`P0 资产规格校验阻断：${errors.length} 项`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`P0 资产规格校验通过：${required.size} 个核心槽位；动画、证据、发布阻断和扩展视觉出口均已登记`);
