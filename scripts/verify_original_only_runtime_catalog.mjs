import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const runtimeRoot = path.join(root, "gta-reference-runtime");
const catalogPath = path.join(runtimeRoot, "content/asset-runtime-catalog-original-only.json");
const catalog = JSON.parse(fs.readFileSync(catalogPath, "utf8"));
const playtestEntryPath = path.join(root, "scripts/run_original_only_candidate_playtest.sh");
if (!fs.existsSync(playtestEntryPath)) throw new Error("缺少原创边界候选试玩入口");
const playtestEntry = fs.readFileSync(playtestEntryPath, "utf8");
if (!playtestEntry.includes("REFERENCE_ASSET_CATALOG_PATH=\"res://content/asset-runtime-catalog-original-only.json\"")) {
  throw new Error("原创边界候选试玩入口没有固定使用 original-only 资产目录");
}
if (!playtestEntry.includes("REFERENCE_ASSET_PREVIEW=1")) throw new Error("原创边界候选试玩入口没有开启候选资产预览模式");
const visualSlots = (catalog.slots ?? []).filter((slot) => slot.id !== "final-audio-library");
const audioSlot = (catalog.slots ?? []).find((slot) => slot.id === "final-audio-library");
if (catalog.character_variant !== "original_only" || catalog.release_allowed !== false) throw new Error("原创边界目录身份或发布状态不正确");
if (visualSlots.length !== 7) throw new Error(`原创边界目录视觉槽位数量异常：${visualSlots.length}`);
if (!audioSlot || audioSlot.fallback_policy !== "forbid") throw new Error("原创边界音频槽位仍允许程序化灰盒回退");
for (const slot of visualSlots) {
  if (slot.fallback_policy !== "forbid") throw new Error(`原创边界视觉槽位仍允许灰盒回退：${slot.id}`);
  if (!String(slot.scene_path).startsWith("res://")) throw new Error(`原创边界槽位路径无效：${slot.id}`);
  const filePath = path.join(runtimeRoot, String(slot.scene_path).replace(/^res:\/\//, ""));
  if (!fs.existsSync(filePath)) throw new Error(`原创边界槽位资源不存在：${slot.id} -> ${slot.scene_path}`);
  if (/quaternius|makehuman|polyhaven|cc0/i.test(String(slot.scene_path))) throw new Error(`原创边界槽位挂载了外部资源：${slot.id}`);
}
const payloadText = fs.readFileSync(catalogPath, "utf8");
if (/quaternius|makehuman|polyhaven|worn_asphalt/i.test(payloadText)) throw new Error("原创边界目录文本包含外部资产标识");
console.log(`原创边界正式源码目录验证通过：${visualSlots.length} 个视觉槽位 + 音频槽位；全部 forbid；外部路径 0 个`);
