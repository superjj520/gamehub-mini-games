import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";

const root = path.resolve(".");
const source = JSON.parse(fs.readFileSync(path.join(root, "docs/release-manifest.json"), "utf8")).source;
const archivePath = path.join(root, "build", `city-candidate-review-${source.sha256.slice(0, 8)}.zip`);
const metadataPath = `${archivePath.slice(0, -4)}.json`;
if (!fs.existsSync(archivePath) || !fs.existsSync(metadataPath)) throw new Error("城市候选审阅包或清单不存在");

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

const metadata = JSON.parse(fs.readFileSync(metadataPath, "utf8"));
if (metadata.status !== "internal_candidate_review_only") throw new Error(`城市候选审阅包状态错误：${metadata.status}`);
if (metadata.sha256 !== sha256(archivePath) || metadata.bytes !== fs.statSync(archivePath).size) throw new Error("城市候选审阅包外部哈希或字节数不一致");
const entries = execFileSync("unzip", ["-Z1", archivePath], {encoding: "utf8"}).split(/\r?\n/).filter(Boolean);
for (const forbidden of ["reference-evidence/video-1/", "reference-evidence/video-2/", "参考视频"]) {
  if (entries.some((entry) => entry.includes(forbidden))) throw new Error(`城市候选审阅包包含禁止内容：${forbidden}`);
}
for (const required of [
  "README.md",
  "manifest.json",
  "art-source/city-full-kit-candidate/city_environment_storefront_candidate.gd",
  "art-source/city-full-kit-candidate/city_full_kit_runtime_integration_test.gd",
  "art-source/city-full-kit-candidate/run_city_candidate_playtest.mjs",
  "art-source/city-full-kit-candidate/city_crowd_makehuman_runtime_overlay.tscn",
  "docs/candidate-art-review-city-player-2026-10-10.md",
  "reference-evidence/candidate-runtime/candidate-art-review-city-player-2026-10-10.json",
  "art-source/characters/quaternius-superhero-male/player_character_visual_candidate.gd",
  "art-source/characters/quaternius-superhero-male/player_character_visual_candidate.tscn",
  "art-source/characters/makehuman-office-worker/makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb",
  "art-source/city-full-kit-candidate/textures/storefront-sign-eggs-v1.png",
  "art-source/characters/quaternius-superhero-male/city-crowd-candidate/city_crowd_quaternius_candidate.gd",
  "art-source/vehicles/three-wheel-delivery/three_wheel_delivery_atlas_candidate.glb",
]) {
  if (!entries.includes(required)) throw new Error(`城市候选审阅包缺少必需文件：${required}`);
}
execFileSync("unzip", ["-t", archivePath], {stdio: "ignore"});
const archiveManifest = JSON.parse(execFileSync("unzip", ["-p", archivePath, "manifest.json"], {encoding: "utf8"}));
if (archiveManifest.scope !== "city_full_kit" || archiveManifest.status !== "internal_candidate_review_only") throw new Error("城市候选包内部状态或范围错误");
if (archiveManifest.source?.sha256 !== source.sha256 || archiveManifest.source?.file_count !== source.file_count) throw new Error("城市候选包绑定的正式运行时源指纹过期");
for (const entry of archiveManifest.entries ?? []) {
  const data = execFileSync("unzip", ["-p", archivePath, entry.path], {maxBuffer: 64 * 1024 * 1024});
  if (data.length !== entry.bytes || crypto.createHash("sha256").update(data).digest("hex") !== entry.sha256) throw new Error(`城市候选包内部文件哈希不一致：${entry.path}`);
}
console.log(`城市候选审阅包验证通过：${archiveManifest.entries.length} 个文件；源指纹 ${archiveManifest.source.sha256}/${archiveManifest.source.file_count}；禁止内容 0 个`);
