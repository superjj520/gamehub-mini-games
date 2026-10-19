import crypto from "node:crypto";
import fs from "node:fs";

const evidence = JSON.parse(fs.readFileSync("reference-evidence/manifest.json", "utf8"));
const errors = [];
const sha256File = (filePath) => crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
const sha256Bytes = (filePath) => crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");

if (evidence.version !== 1) errors.push("参考媒体清单版本不受支持");
if (!Array.isArray(evidence.sources) || evidence.sources.length !== 2) errors.push("参考媒体必须包含两个本地源视频");
const segmentIds = new Set();
for (const source of evidence.sources ?? []) {
  if (!fs.existsSync(source.source_path)) {
    errors.push(`本地参考视频不存在：${source.source_path}`);
    continue;
  }
  const stat = fs.statSync(source.source_path);
  if (stat.size !== source.file_size_bytes) errors.push(`参考视频文件大小不匹配：${source.id}`);
  if (sha256File(source.source_path) !== source.source_sha256) errors.push(`参考视频 SHA-256 不匹配：${source.id}`);
  if (source.release_allowed !== false) errors.push(`参考视频必须禁止进入发布包：${source.id}`);
  const stream = source.stream_metadata;
  if (!stream || stream.video_codec !== "h264" || stream.audio_codec !== "aac" || stream.audio_sample_rate !== 44100 || stream.audio_channels !== 1 || stream.audio_channel_layout !== "mono") {
    errors.push(`参考视频音视频流元数据不完整或不匹配：${source.id}`);
  }
  if (!Array.isArray(source.segments) || source.segments.length === 0) {
    errors.push(`参考视频缺少分段：${source.id}`);
    continue;
  }
  let previousEnd = 0;
  for (const segment of source.segments) {
    if (segmentIds.has(segment.id)) errors.push(`参考分段 ID 重复：${segment.id}`);
    segmentIds.add(segment.id);
    if (!(segment.time_start >= previousEnd && segment.time_end > segment.time_start && segment.time_end <= source.duration_seconds && segment.representative_time >= segment.time_start && segment.representative_time <= segment.time_end)) {
      errors.push(`参考分段时间边界无效：${segment.id}`);
    }
    if (!Number.isInteger(segment.frame_index) || segment.frame_index < 0) errors.push(`参考分段帧号无效：${segment.id}`);
    const imagePath = `reference-evidence/${segment.image}`;
    if (!fs.existsSync(imagePath)) {
      errors.push(`参考分段抽帧不存在：${segment.id}`);
    } else if (sha256Bytes(imagePath) !== segment.sha256) {
      errors.push(`参考分段抽帧 SHA-256 不匹配：${segment.id}`);
    }
    previousEnd = segment.time_end;
  }
}
if (segmentIds.size !== 21) errors.push(`参考分段总数应为 21，实际为 ${segmentIds.size}`);

if (errors.length > 0) {
  console.error(`参考媒体证据验证阻断：${errors.length} 项`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}
console.log(`参考媒体证据验证通过：${evidence.sources.length} 个本地视频、${segmentIds.size} 个分段、音频流元数据已登记`);
