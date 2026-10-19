import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const workspaceRoot = path.resolve(".");
const packageRoot = path.resolve(process.env.FULL_CANDIDATE_PACKAGE_ROOT?.trim() || path.join(workspaceRoot, "build", "internal-full-candidate"));
const releaseManifestPath = path.join(workspaceRoot, "docs", "release-manifest.json");

function collectFiles(rootPath) {
  const files = [];
  const ignoredMetadataFiles = new Set(["candidate-package-manifest.json", "CANDIDATE_PACKAGE_README.md"]);
  const visit = (directory) => {
    for (const entry of fs.readdirSync(directory, {withFileTypes: true}).sort((left, right) => left.name.localeCompare(right.name))) {
      if (entry.isDirectory() && entry.name === ".godot") continue;
      const absolutePath = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(absolutePath);
      else if (entry.isFile() && !ignoredMetadataFiles.has(entry.name) && !entry.name.endsWith(".import") && !entry.name.endsWith(".uid")) files.push(absolutePath);
    }
  };
  visit(rootPath);
  return files;
}

function fingerprint(rootPath) {
  const hash = crypto.createHash("sha256");
  const files = collectFiles(rootPath);
  for (const filePath of files) {
    hash.update(path.relative(rootPath, filePath).split(path.sep).join("/"));
    hash.update("\0");
    hash.update(fs.readFileSync(filePath));
    hash.update("\0");
  }
  return {sha256: hash.digest("hex"), file_count: files.length};
}

function readJson(relativePath) {
  const filePath = path.join(packageRoot, relativePath);
  if (!fs.existsSync(filePath)) throw new Error(`完整候选包缺少文件：${relativePath}`);
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

if (!fs.existsSync(packageRoot)) throw new Error("完整候选运行包不存在，请先运行 npm run package:candidate:full");
const manifest = readJson("candidate-package-manifest.json");
const releaseManifest = JSON.parse(fs.readFileSync(releaseManifestPath, "utf8"));
const requiredFiles = [
  "project.godot",
  "scenes/launcher.tscn",
  "content/launch-profile.json",
  "content/full-candidate-preview.marker",
  "tests/asset-runtime-catalog-full-candidates.json",
  "tests/capture_p0_candidate_visual.gd",
  "office_desk_composition.tscn",
];
if (manifest.character_variant === "original_only") {
  requiredFiles.push("art-source/candidate-playtest/original-only/original_only_city_environment_candidate.tscn");
} else {
  requiredFiles.push(
    "art-source/city-full-kit-candidate/city_environment_storefront_candidate.tscn",
    "art-source/characters/quaternius-superhero-male/player_character_visual_candidate.gd",
    "art-source/characters/quaternius-superhero-male/player_character_visual_candidate.tscn",
  );
}
const characterFiles = ["original", "original_only"].includes(manifest.character_variant)
  ? [
    "assets/characters/original-procedural-office-characters/original_player_candidate.tscn",
    "assets/characters/original-procedural-office-characters/original_office_npc_candidate.tscn",
    "art-source/environment/original-office-desk/original_office_desk_candidate.gd",
    "art-source/environment/original-office-desk/original_office_desk_candidate.tscn",
  ]
  : [
    "assets/characters/makehuman-office-player/makehuman_player_visual_candidate.tscn",
    "assets/characters/makehuman-office-worker/office_npc_atlas_retouch_candidate.tscn",
  ];
requiredFiles.push(...characterFiles);
for (const relativePath of requiredFiles) {
  if (!fs.existsSync(path.join(packageRoot, relativePath))) throw new Error(`完整候选包缺少入口文件：${relativePath}`);
}
if (manifest.status !== "internal_candidate_review_only" || manifest.release_allowed !== false) {
  throw new Error("完整候选包必须明确标记为 internal_candidate_review_only 且 release_allowed=false");
}
if (manifest.source?.sha256 !== releaseManifest.source?.sha256 || manifest.source?.file_count !== releaseManifest.source?.file_count) {
  throw new Error("完整候选包没有绑定当前正式运行时源指纹");
}
const profile = readJson("content/launch-profile.json");
if (profile.status !== "internal_candidate_review_only") throw new Error("完整候选入口没有标记为内部候选");
if (fs.readFileSync(path.join(packageRoot, "content/full-candidate-preview.marker"), "utf8").trim() !== "internal_candidate_review_only") {
  throw new Error("完整候选启动标记内容不正确");
}
for (const entry of profile.entries ?? []) {
  if (entry.asset_catalog_path !== "res://tests/asset-runtime-catalog-full-candidates.json") {
    throw new Error(`完整候选入口没有绑定包内候选资产目录：${entry.id ?? "unknown"}`);
  }
}
const entryIds = new Set((profile.entries ?? []).map((entry) => entry.id));
for (const entryId of ["office-candidate", "city-candidate", "city-market-candidate"]) {
  if (!entryIds.has(entryId)) throw new Error(`完整候选入口缺少：${entryId}`);
}
const marketEntry = (profile.entries ?? []).find((entry) => entry.id === "city-market-candidate");
if (marketEntry.content_pack_id !== "city-market-delivery-v1" || marketEntry.shortcut !== "4") {
  throw new Error("完整候选夜市入口没有绑定 city-market-delivery-v1/4 号快捷键");
}
const catalog = readJson("tests/asset-runtime-catalog-full-candidates.json");
for (const slotId of ["player-character", "city-player-character", "office-npc-set", "office-environment-kit", "city-crowd-set", "three-wheel-vehicle", "city-environment-kit"]) {
  const slot = catalog.slots.find((candidate) => candidate.id === slotId);
  if (!slot || !slot.scene_path || slot.fallback_policy !== "forbid") throw new Error(`完整候选资产槽位未锁定：${slotId}`);
}
for (const segment of [
  "office-01", "office-02", "office-03", "office-04", "office-05",
  "office-06", "office-07", "office-08", "office-09", "office-10",
]) {
  const backdropPath = path.join(packageRoot, "reference-video-candidate", `${segment}-video-playable-backdrop-v1.png`);
  if (!fs.existsSync(backdropPath)) throw new Error(`完整候选包缺少办公室分段背景：${segment}`);
}
const candidateCaptureSource = fs.readFileSync(path.join(packageRoot, "tests/capture_p0_candidate_visual.gd"), "utf8");
if (!candidateCaptureSource.includes('office.set_meta("asset_catalog_path", catalog_path)') || !candidateCaptureSource.includes("asset-runtime-catalog-full-candidates.json")) {
  throw new Error("完整候选办公室视觉采集没有绑定包内候选资产目录，禁止静默回落到正式灰盒目录");
}
const forbiddenFragments = ["reference-evidence/", "video-1/", "video-2/", "参考视频", "commercial_game_assets"];
const forbidden = collectFiles(packageRoot).map((filePath) => path.relative(packageRoot, filePath).split(path.sep).join("/")).filter((relativePath) => forbiddenFragments.some((fragment) => relativePath.includes(fragment)));
if (forbidden.length > 0) throw new Error(`完整候选包包含禁入内容：${forbidden.slice(0, 8).join(", ")}`);
const actualFingerprint = fingerprint(packageRoot);
if (manifest.package?.sha256 !== actualFingerprint.sha256 || manifest.package?.file_count !== actualFingerprint.file_count) {
  throw new Error("完整候选包内容已变化，包指纹与清单不一致");
}
console.log(`完整候选运行包验证通过：${path.relative(workspaceRoot, packageRoot)}；${actualFingerprint.file_count} 个文件；源指纹 ${manifest.source.sha256}/${manifest.source.file_count}；禁入内容 0 个；release_allowed=false`);
