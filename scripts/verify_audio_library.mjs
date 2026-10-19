import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const workspaceRoot = path.resolve(".");
const libraryRoot = path.join(workspaceRoot, "gta-reference-runtime", "assets", "audio", "generated");
const manifestPath = path.join(libraryRoot, "audio-library-manifest.json");
const cueCatalogPath = path.join(workspaceRoot, "gta-reference-runtime", "content", "audio_cues.json");

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function readWavHeader(filePath) {
  const buffer = fs.readFileSync(filePath);
  if (buffer.length < 44 || buffer.toString("ascii", 0, 4) !== "RIFF" || buffer.toString("ascii", 8, 12) !== "WAVE") {
    throw new Error(`不是有效的 RIFF/WAVE 文件：${filePath}`);
  }
  return {
    channels: buffer.readUInt16LE(22),
    sampleRate: buffer.readUInt32LE(24),
    bitsPerSample: buffer.readUInt16LE(34),
    dataBytes: buffer.readUInt32LE(40),
    fileBytes: buffer.length,
  };
}

if (!fs.existsSync(manifestPath)) throw new Error(`缺少音频库清单：${manifestPath}`);
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
if (manifest.status !== "internal_candidate_only" || manifest.release_allowed !== false) {
  throw new Error("音频库必须保持内部候选状态，不能被验证器误标为可发布");
}
if (!Array.isArray(manifest.files)) throw new Error("音频库必须登记 files 数组");
if (!fs.existsSync(cueCatalogPath)) throw new Error(`缺少音频提示音目录：${cueCatalogPath}`);
const cueCatalog = JSON.parse(fs.readFileSync(cueCatalogPath, "utf8"));
const expectedIds = new Set((cueCatalog.cues ?? []).map((cue) => String(cue?.id ?? "")).filter(Boolean));
const manifestIds = manifest.files.map((entry) => String(entry?.id ?? ""));
if (manifestIds.length !== expectedIds.size) {
  throw new Error(`音频库文件数与提示音目录不一致：清单 ${manifestIds.length}，提示音目录 ${expectedIds.size}`);
}
if (new Set(manifestIds).size !== manifestIds.length || manifestIds.some((id) => !expectedIds.has(id))) {
  throw new Error("音频库清单的 id 必须与提示音目录一一对应且不得重复");
}

for (const entry of manifest.files) {
  const relativePath = entry.path?.replace("res://assets/audio/generated/", "");
  const filePath = relativePath ? path.join(libraryRoot, relativePath) : null;
  if (!filePath || !fs.existsSync(filePath)) throw new Error(`音频文件缺失：${entry.path}`);
  const header = readWavHeader(filePath);
  if (header.channels !== 1 || header.sampleRate !== 22050 || header.bitsPerSample !== 16) {
    throw new Error(`音频格式不符合候选规范：${entry.path}`);
  }
  if (header.fileBytes !== entry.bytes || header.dataBytes <= 0) throw new Error(`音频字节数异常：${entry.path}`);
  if (sha256(filePath) !== entry.sha256) throw new Error(`音频 SHA-256 不一致：${entry.path}`);
}

console.log(`原创程序化音频库验证通过：${manifest.files.length} 个 WAV；22050 Hz；单声道；16-bit；仍为 internal_candidate_only`);
