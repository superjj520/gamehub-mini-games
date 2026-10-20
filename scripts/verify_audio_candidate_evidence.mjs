import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const runtimeRoot = path.join(root, "gta-reference-runtime");
const libraryRoot = path.join(runtimeRoot, "assets/audio/generated");
const rightsPath = path.join(runtimeRoot, "content/rights-manifest.json");
const cuePath = path.join(runtimeRoot, "content/audio_cues.json");
const runtimeCatalogPath = path.join(runtimeRoot, "content/audio-runtime-catalog.json");
const libraryManifestPath = path.join(libraryRoot, "audio-library-manifest.json");
const outputPath = path.join(root, "reference-evidence/candidate-runtime/audio-candidate-acceptance.json");
const outputTempPath = `${outputPath}.tmp-${process.pid}`;

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function readWavMetrics(filePath) {
  const data = fs.readFileSync(filePath);
  if (data.length < 44 || data.toString("ascii", 0, 4) !== "RIFF" || data.toString("ascii", 8, 12) !== "WAVE") {
    throw new Error(`音频文件不是有效 RIFF/WAVE：${path.relative(root, filePath)}`);
  }
  const audioFormat = data.readUInt16LE(20);
  const channels = data.readUInt16LE(22);
  const sampleRate = data.readUInt32LE(24);
  const bitsPerSample = data.readUInt16LE(34);
  const dataOffset = data.indexOf(Buffer.from("data"), 36);
  if (audioFormat !== 1 || dataOffset < 0 || bitsPerSample !== 16) {
    throw new Error(`音频文件格式不符合候选契约：${path.relative(root, filePath)}`);
  }
  const sampleBytes = data.readUInt32LE(dataOffset + 4);
  const sampleStart = dataOffset + 8;
  const sampleEnd = Math.min(data.length, sampleStart + sampleBytes);
  const sampleCount = Math.floor((sampleEnd - sampleStart) / 2);
  let peak = 0;
  let squaredSum = 0;
  for (let offset = sampleStart; offset + 1 < sampleEnd; offset += 2) {
    const sample = data.readInt16LE(offset) / 32768;
    const absolute = Math.abs(sample);
    peak = Math.max(peak, absolute);
    squaredSum += sample * sample;
  }
  const durationSeconds = sampleCount / Math.max(1, channels * sampleRate);
  const rms = Math.sqrt(squaredSum / Math.max(1, sampleCount));
  return {
    bytes: data.length,
    sample_rate: sampleRate,
    channels,
    bits_per_sample: bitsPerSample,
    duration_seconds: Number(durationSeconds.toFixed(6)),
    peak: Number(peak.toFixed(6)),
    rms: Number(rms.toFixed(6)),
    sha256: sha256(filePath),
  };
}

for (const filePath of [rightsPath, cuePath, runtimeCatalogPath, libraryManifestPath]) {
  if (!fs.existsSync(filePath)) throw new Error(`音频候选验收缺少文件：${path.relative(root, filePath)}`);
}

const rights = readJson(rightsPath);
const cueCatalog = readJson(cuePath);
const runtimeCatalog = readJson(runtimeCatalogPath);
const library = readJson(libraryManifestPath);
const rightsEntry = (rights.assets ?? []).find((asset) => asset.id === "original_procedural_audio_library_candidate");
if (!rightsEntry) throw new Error("权利清单缺少原创程序化音频候选条目");
if (rightsEntry.release_allowed !== false || rightsEntry.status !== "internal_candidate_only") {
  throw new Error("音频候选必须保持 internal_candidate_only 且不可发布");
}
if (library.status !== "internal_candidate_only" || library.release_allowed !== false) {
  throw new Error("音频库清单状态不能升级为可发布");
}

const cueIds = (cueCatalog.cues ?? []).map((cue) => cue.id);
const runtimeEvents = runtimeCatalog.events ?? [];
const runtimeIds = runtimeEvents.map((event) => event.id);
const libraryIds = (library.files ?? []).map((file) => file.id);
const audioFiles = [];
const unique = (values) => new Set(values).size === values.length;
const rightsRuntimeFiles = new Set(rightsEntry.derived_runtime_files ?? []);
if (!rightsRuntimeFiles.has("assets/audio/generated/audio-library-manifest.json")) {
  throw new Error("音频候选权利清单缺少 audio-library-manifest.json");
}
if (!unique(cueIds) || !unique(runtimeIds) || !unique(libraryIds)) throw new Error("音频候选目录存在重复事件 id");
if (cueIds.length === 0 || runtimeIds.length !== cueIds.length || libraryIds.length !== cueIds.length) {
  throw new Error(`音频候选三层目录数量不一致：提示音 ${cueIds.length}，运行时 ${runtimeIds.length}，生成库 ${libraryIds.length}`);
}
if (runtimeIds.some((id) => !cueIds.includes(id)) || libraryIds.some((id) => !cueIds.includes(id))) {
  throw new Error("音频候选三层目录的事件 id 不一致");
}
for (const id of cueIds) {
  if (!runtimeIds.includes(id) || !libraryIds.includes(id)) throw new Error(`音频事件没有逐层对齐：${id}`);
  const event = runtimeEvents.find((item) => item.id === id);
  if (!event.stream_path || event.fallback_policy !== "procedural_graybox") throw new Error(`音频事件回退策略异常：${id}`);
  const relativeRuntimePath = event.stream_path.replace("res://", "");
  if (!rightsRuntimeFiles.has(relativeRuntimePath)) {
    throw new Error(`音频事件未登记到候选权利清单：${id} -> ${relativeRuntimePath}`);
  }
  const filePath = path.join(runtimeRoot, event.stream_path.replace("res://", ""));
  if (!fs.existsSync(filePath)) throw new Error(`音频事件资源不存在：${id}`);
  const metrics = readWavMetrics(filePath);
  if (metrics.sample_rate !== 22050 || metrics.channels !== 1 || metrics.bits_per_sample !== 16) {
    throw new Error(`音频事件技术格式不符合候选契约：${id}`);
  }
  if (metrics.duration_seconds <= 0 || metrics.peak <= 0 || metrics.rms <= 0) {
    throw new Error(`音频事件为空或无有效波形：${id}`);
  }
  const libraryEntry = library.files.find((file) => file.id === id);
  if (!libraryEntry || libraryEntry.sha256 !== metrics.sha256 || libraryEntry.bytes !== metrics.bytes) {
    throw new Error(`音频事件与生成清单哈希或大小不一致：${id}`);
  }
  audioFiles.push({id, path: event.stream_path, ...metrics});
}

const report = {
  schema_version: 1,
  status: "technical_candidate_verified",
  visual_status: "not_applicable",
  technical_status: "passed",
  manual_listening_status: "unverified",
  platform_status: "unverified",
  release_allowed: false,
  event_count: cueIds.length,
  audio_files: audioFiles,
  evidence: {
    rights_manifest: {path: "gta-reference-runtime/content/rights-manifest.json", sha256: sha256(rightsPath)},
    cue_catalog: {path: "gta-reference-runtime/content/audio_cues.json", sha256: sha256(cuePath)},
    runtime_catalog: {path: "gta-reference-runtime/content/audio-runtime-catalog.json", sha256: sha256(runtimeCatalogPath)},
    library_manifest: {path: "gta-reference-runtime/assets/audio/generated/audio-library-manifest.json", sha256: sha256(libraryManifestPath)},
  },
  remaining_gates: ["人工听感与混音审阅", "音量开关回放", "Windows 10/11 目标设备验证", "最终发布权利复核"],
  policy: "技术目录、WAV 格式和来源证据通过不等于最终音频质量或发布通过。",
  generated_at: new Date().toISOString(),
};

fs.mkdirSync(path.dirname(outputPath), {recursive: true});
fs.writeFileSync(outputTempPath, `${JSON.stringify(report, null, 2)}\n`, "utf8");
fs.renameSync(outputTempPath, outputPath);
console.log(`音频候选技术验收通过：${cueIds.length} 个事件；人工听感、目标设备和发布状态仍未签收`);
