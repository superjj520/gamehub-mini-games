import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {execFileSync} from "node:child_process";

const root = path.resolve(".");
const outputDir = path.join(root, "build");
const sourceManifestPath = path.join(root, "docs/release-manifest.json");
const explicitFiles = [
  "docs/product-baseline-decision.json",
  "docs/asset-candidate-registry.json",
  "docs/asset-rights-register.md",
  "docs/final-asset-production-backlog.md",
  "docs/candidate-art-review-2026-10-10.md",
  "docs/candidate-art-review-city-player-2026-10-10.md",
  "docs/candidate-city-quaternius-visual-review-2026-10-12.md",
  "reference-evidence/candidate-runtime/candidate-art-review-2026-10-10.json",
  "reference-evidence/candidate-runtime/candidate-art-review-city-player-2026-10-10.json",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-capture.json",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-01.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-capture-v9.json",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-01-v9.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-capture-city-08-11-v1.json",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-08-v1.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-capture-city-08-v6.json",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-08-v6.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-capture-city-01-08-11-v23.json",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-01-v11.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-08-v9.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-11-v23.png",
  "reference-evidence/candidate-runtime/quaternius-city-asset-audit-2026-10-12.json",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-capture-city-01-08-11-v24.json",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-01-v24.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-08-v24.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-11-v24.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-capture-city-01-08-11-v25.json",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-01-v25.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-08-v25.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-11-v25.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-capture-city-01-08-11-v26.json",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-01-v26.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-08-v26.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-11-v26.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-11-v1.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-capture-city-11-v9.json",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-11-v9.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-capture-city-11-v11.json",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-11-v11.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-capture-city-11-v18.json",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-11-v18.png",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-capture-city-11-v22.json",
  "reference-evidence/candidate-runtime/city-quaternius-candidate-city-11-v22.png",
  "reference-evidence/candidate-runtime/city-makehuman-player-candidate-capture-v27.json",
  "reference-evidence/candidate-runtime/city-makehuman-player-candidate-city-01-v27.png",
  "reference-evidence/candidate-runtime/city-makehuman-player-candidate-city-08-v27.png",
  "reference-evidence/candidate-runtime/city-makehuman-player-candidate-city-11-v27.png",
  "reference-evidence/candidate-runtime/city-makehuman-player-candidate-capture-v28.json",
  "reference-evidence/candidate-runtime/city-makehuman-player-candidate-city-01-v28.png",
  "reference-evidence/candidate-runtime/city-makehuman-player-candidate-city-08-v28.png",
  "reference-evidence/candidate-runtime/city-makehuman-player-candidate-city-11-v28.png",
  "reference-evidence/candidate-runtime/city-makehuman-crowd-ab-rejection-v29.json",
  "reference-evidence/candidate-runtime/city-makehuman-crowd-ab-city-01-v29.png",
  "reference-evidence/candidate-runtime/city-makehuman-crowd-ab-city-08-v29.png",
  "reference-evidence/candidate-runtime/city-makehuman-crowd-ab-city-11-v29.png",
  "reference-evidence/candidate-runtime/city-makehuman-player-candidate-capture-v30.json",
  "reference-evidence/candidate-runtime/city-makehuman-player-candidate-city-01-v30.png",
  "reference-evidence/candidate-runtime/city-makehuman-player-candidate-city-08-v30.png",
  "reference-evidence/candidate-runtime/city-makehuman-player-candidate-city-11-v30.png",
  "docs/windows-device-qa-runbook.md",
  "gta-reference-runtime/content/asset-runtime-catalog.json",
  "gta-reference-runtime/content/rights-manifest.json",
  "gta-reference-runtime/assets/characters/quaternius-superhero-male/QUATERNIUS-LICENSE.txt",
  "gta-reference-runtime/assets/characters/quaternius-superhero-male/character.glb",
  "gta-reference-runtime/assets/characters/quaternius-superhero-male/character_npc_outfitted.glb",
  "gta-reference-runtime/assets/characters/quaternius-superhero-male/character_outfitted.glb",
  "gta-reference-runtime/assets/characters/quaternius-superhero-male/player_character_quaternius_candidate.gd",
  "gta-reference-runtime/assets/characters/quaternius-superhero-male/player_character_quaternius_candidate.tscn",
  "gta-reference-runtime/assets/characters/quaternius-superhero-male/office_npc_quaternius_candidate.gd",
  "gta-reference-runtime/assets/characters/quaternius-superhero-male/office_npc_quaternius_candidate.tscn",
  "gta-reference-runtime/assets/environment/quaternius-downtown/LICENSE-quaternius.txt",
  "gta-reference-runtime/assets/environment/cc0/worn_asphalt/worn_asphalt_diff_1k.jpg",
  "gta-reference-runtime/assets/environment/cc0/worn_asphalt/worn_asphalt_nor_gl_1k.jpg",
  "gta-reference-runtime/assets/environment/cc0/worn_asphalt/worn_asphalt_rough_1k.jpg",
  "gta-reference-runtime/assets/environment/generated/urban_storefront_v2_generated.png",
  "gta-reference-runtime/assets/environment/generated/urban_storefront_v2_generated.json",
  "gta-reference-runtime/assets/environment/generated/warehouse_backlot_facade_v1_generated.png",
  "gta-reference-runtime/assets/environment/generated/warehouse_backlot_facade_v1_generated.json",
  "reference-evidence/p0-candidate-city-08.png",
  "reference-evidence/candidate-runtime/city-delivery-current-capture.json",
  "reference-evidence/candidate-runtime/city-storefront-candidate-city-01.json",
  "reference-evidence/candidate-runtime/city-storefront-candidate-city-08.json",
  "reference-evidence/candidate-runtime/city-storefront-candidate-city-11.json",
  "art-source/city-full-kit-candidate/run_city_candidate_playtest.mjs",
  "art-source/characters/quaternius-superhero-male/player_character_visual_candidate.gd",
  "art-source/characters/quaternius-superhero-male/player_character_visual_candidate.tscn",
  "art-source/characters/makehuman-office-worker/makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb",
  "art-source/characters/makehuman-office-worker/makehuman_office_worker_elegant_suit_skinned_probe_512_simplified.glb",
  "art-source/characters/makehuman-office-worker/makehuman_office_npc_retouch.gd",
  "art-source/characters/makehuman-office-player/makehuman_player_visual_candidate.gd",
  "art-source/characters/makehuman-office-player/makehuman_player_visual_candidate.tscn",
];
const directoryRoots = [
  "art-source/city-full-kit-candidate",
  "art-source/characters/quaternius-superhero-male/city-crowd-candidate",
  "art-source/vehicles/three-wheel-delivery",
];

function sha256Bytes(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function sha256File(filePath) {
  return sha256Bytes(fs.readFileSync(filePath));
}

function collectFiles(directory) {
  const entries = fs.readdirSync(directory, {withFileTypes: true}).sort((a, b) => a.name.localeCompare(b.name));
  const files = [];
  for (const entry of entries) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...collectFiles(absolute));
    else if (entry.isFile() && !entry.name.endsWith(".import") && !entry.name.endsWith(".uid")) files.push(absolute);
  }
  return files;
}

function readSource() {
  const manifest = JSON.parse(fs.readFileSync(sourceManifestPath, "utf8"));
  if (!manifest.source?.sha256 || !Number.isInteger(manifest.source.file_count)) throw new Error("发布清单缺少正式运行时源指纹");
  return manifest.source;
}

function packageFiles() {
  const files = new Set(explicitFiles.map((file) => path.resolve(root, file)));
  for (const directory of directoryRoots) {
    const absolute = path.resolve(root, directory);
    for (const file of collectFiles(absolute)) files.add(file);
  }
  return [...files].sort();
}

function copyEntries(stagingRoot, files) {
  return files.map((sourcePath) => {
    if (!fs.existsSync(sourcePath) || !fs.statSync(sourcePath).isFile()) throw new Error(`城市候选审阅包文件不存在：${path.relative(root, sourcePath)}`);
    const relative = path.relative(root, sourcePath).split(path.sep).join("/");
    const target = path.join(stagingRoot, relative);
    fs.mkdirSync(path.dirname(target), {recursive: true});
    fs.copyFileSync(sourcePath, target);
    return {path: relative, bytes: fs.statSync(sourcePath).size, sha256: sha256File(sourcePath)};
  });
}

function stableTimestamps(directory) {
  const stable = new Date("2000-01-01T00:00:00.000Z");
  for (const entry of fs.readdirSync(directory, {withFileTypes: true}).sort((a, b) => a.name.localeCompare(b.name))) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) stableTimestamps(entryPath);
    fs.utimesSync(entryPath, stable, stable);
  }
  fs.utimesSync(directory, stable, stable);
}

const source = readSource();
const sourceShort = source.sha256.slice(0, 8);
const outputPath = path.join(outputDir, `city-candidate-review-${sourceShort}.zip`);
const metadataPath = `${outputPath.slice(0, -4)}.json`;
const stagingRoot = fs.mkdtempSync(path.join(os.tmpdir(), "新时代觉醒者-city-candidate-review-"));

try {
  execFileSync(process.execPath, [path.join(root, "scripts/verify_asset_candidate_registry.mjs")], {stdio: "inherit"});
  execFileSync(process.execPath, [path.join(root, "scripts/verify_asset_delivery_gate.mjs")], {stdio: "inherit"});
  const entries = copyEntries(stagingRoot, packageFiles());
  const manifest = {
    schema_version: 1,
    status: "internal_candidate_review_only",
    product_name: "新时代觉醒者",
    scope: "city_full_kit",
    source: {sha256: source.sha256, file_count: source.file_count},
    candidate_policy: "城市候选只用于隔离预览、集成回放和视觉审阅；release_allowed=false，视觉和目标设备证据未签收",
    entries,
    remaining_gates: ["当前源版本真实城市图形截图", "城市候选人工视觉签收", "最终资产权利签收", "Windows 10/11 目标设备 QA", "Steam 商店门禁"],
  };
  const readme = `# 《新时代觉醒者》城市候选审阅包\n\n状态：内部候选审阅，不是可上架版本。\n\n本包包含城市店铺/街区/后场仓储候选、城市人群候选、三轮车候选、权利记录和隔离集成证据。它不包含参考视频或抽帧目录，也不修改正式资产目录。\n\n正式运行时源指纹：${source.sha256} / ${source.file_count} 个文件。\n\n可复现验证：在工作区运行 npm run verify:city-candidate-review。\n视觉捕获只有在真实图形窗口可用时才有效；旧图和失败元数据不能替代当前版本截图。\n\n包内文件：${entries.length} 个；字节数和 SHA-256 记录在 manifest.json。\n`;
  fs.writeFileSync(path.join(stagingRoot, "README.md"), readme, "utf8");
  fs.writeFileSync(path.join(stagingRoot, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
  stableTimestamps(stagingRoot);
  fs.mkdirSync(outputDir, {recursive: true});
  fs.rmSync(outputPath, {force: true});
  execFileSync("zip", ["-Xqr", outputPath, "."], {cwd: stagingRoot, stdio: "inherit"});
  const metadata = {schema_version: 1, status: manifest.status, package_path: path.relative(root, outputPath).split(path.sep).join("/"), bytes: fs.statSync(outputPath).size, sha256: sha256File(outputPath), source: manifest.source, entry_count: entries.length};
  fs.writeFileSync(metadataPath, `${JSON.stringify(metadata, null, 2)}\n`, "utf8");
  console.log(`城市候选审阅包已生成：${metadata.package_path}；${metadata.entry_count} 个文件；${metadata.bytes} bytes；SHA-256 ${metadata.sha256}`);
} finally {
  fs.rmSync(stagingRoot, {recursive: true, force: true});
}
