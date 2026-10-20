import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";

const workspaceRoot = path.resolve(".");
const sourceManifestPath = path.join(workspaceRoot, "docs/release-manifest.json");
const candidateManifestPath = path.join(workspaceRoot, "build/internal-candidate-manifest.json");

function sha256Bytes(bytes) {
  return crypto.createHash("sha256").update(bytes).digest("hex");
}

function sha256File(filePath) {
  return sha256Bytes(fs.readFileSync(filePath));
}

function packagePath() {
  if (process.argv[2]) return path.resolve(process.argv[2]);
  const source = JSON.parse(fs.readFileSync(sourceManifestPath, "utf8")).source;
  return path.join(workspaceRoot, "build", `p0-office-candidate-review-${source.sha256.slice(0, 8)}.zip`);
}

const archivePath = packagePath();
if (!fs.existsSync(archivePath)) throw new Error(`P0 办公室审阅包不存在：${archivePath}`);
const metadataPath = `${archivePath.slice(0, -4)}.json`;
if (!fs.existsSync(metadataPath)) throw new Error(`缺少审阅包清单：${metadataPath}`);
const metadata = JSON.parse(fs.readFileSync(metadataPath, "utf8"));
if (metadata.status !== "internal_candidate_review_only") throw new Error(`审阅包状态错误：${metadata.status}`);
if (sha256File(archivePath) !== metadata.sha256) throw new Error("审阅包 SHA-256 与外部清单不一致");
if (fs.statSync(archivePath).size !== metadata.bytes) throw new Error("审阅包字节数与外部清单不一致");

const entries = execFileSync("unzip", ["-Z1", archivePath], {encoding: "utf8"}).split(/\r?\n/).filter(Boolean);
for (const forbidden of ["reference-evidence/video-1/", "reference-evidence/video-2/", "参考视频"]) {
  if (entries.some((entry) => entry.includes(forbidden))) throw new Error(`审阅包包含禁止内容：${forbidden}`);
}
for (const required of [
  "README.md",
  "manifest.json",
  "docs/asset-candidate-registry.json",
  "gta-reference-runtime/content/rights-manifest.json",
  "art-source/environment/polyhaven-metal-office-desk/office_desk_candidate.gd",
  "art-source/environment/polyhaven-metal-office-desk/office_desk_candidate.tscn",
  "art-source/environment/polyhaven-metal-office-desk/capture_combined_office_candidate_visual.mjs",
  "art-source/props/original-interaction-kit/interaction_props_atlas_v1.png",
]) {
  if (!entries.includes(required)) throw new Error(`审阅包缺少必需文件：${required}`);
}
execFileSync("unzip", ["-t", archivePath], {stdio: "ignore"});

const archiveManifest = JSON.parse(execFileSync("unzip", ["-p", archivePath, "manifest.json"], {encoding: "utf8"}));
const currentSource = JSON.parse(fs.readFileSync(sourceManifestPath, "utf8")).source;
if (archiveManifest.source?.sha256 !== currentSource.sha256 || archiveManifest.source?.file_count !== currentSource.file_count) {
  throw new Error(`审阅包源指纹过期：期望 ${currentSource.sha256}/${currentSource.file_count}，实际 ${archiveManifest.source?.sha256}/${archiveManifest.source?.file_count}`);
}
if (archiveManifest.status !== "internal_candidate_review_only" || archiveManifest.scope !== "office_vertical_slice") {
  throw new Error("审阅包内部清单状态或范围错误");
}
for (const entry of archiveManifest.entries ?? []) {
  const data = execFileSync("unzip", ["-p", archivePath, entry.path], {maxBuffer: 128 * 1024 * 1024});
  if (data.length !== entry.bytes || sha256Bytes(data) !== entry.sha256) throw new Error(`审阅包内部文件哈希不一致：${entry.path}`);
}
if (fs.existsSync(candidateManifestPath)) {
  const candidateManifest = JSON.parse(fs.readFileSync(candidateManifestPath, "utf8"));
  if (candidateManifest.status !== "internal_no_go") throw new Error("内部候选树状态异常");
}
console.log(`办公室 P0 候选审阅包验证通过：${path.relative(workspaceRoot, archivePath)}；源指纹 ${archiveManifest.source.sha256}/${archiveManifest.source.file_count}；文件 ${archiveManifest.entries.length} 个；禁止内容 0 个`);
