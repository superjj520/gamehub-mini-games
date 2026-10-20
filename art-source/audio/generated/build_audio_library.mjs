import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const workspaceRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const outputRoot = path.join(workspaceRoot, "gta-reference-runtime", "assets", "audio", "generated");
const sampleRate = 22050;
const channels = 1;
const bitsPerSample = 16;

const cueDefinitions = {
  interaction_success: {duration: 0.18, profile: "ascending_double"},
  interaction_denied: {duration: 0.20, profile: "descending_buzz"},
  mission_success: {duration: 0.52, profile: "success_arpeggio"},
  mission_failed: {duration: 0.46, profile: "failure_drop"},
  perception_alert: {duration: 0.28, profile: "alert_pulse"},
  conflict_started: {duration: 0.36, profile: "conflict_rise"},
  vehicle_driver: {duration: 0.22, profile: "vehicle_click"},
  vehicle_collision: {duration: 0.20, profile: "collision_thud"},
  vehicle_destroyed: {duration: 0.48, profile: "destruction_alarm"},
  scan_registered: {duration: 0.30, profile: "scan_sweep"},
  checkpoint_loaded: {duration: 0.24, profile: "checkpoint_soft"},
  mission_restart: {duration: 0.26, profile: "restart_reset"},
  footstep: {duration: 0.11, profile: "footstep"},
  vehicle_engine: {duration: 0.24, profile: "vehicle_engine"},
};

function clamp(value, low, high) {
  return Math.max(low, Math.min(high, value));
}

function sine(frequency, time) {
  return Math.sin(Math.PI * 2 * frequency * time);
}

function noise(index, salt) {
  const value = Math.sin((index + 1) * (12.9898 + salt * 78.233)) * 43758.5453;
  return (value - Math.floor(value)) * 2 - 1;
}

function envelope(progress, attack = 0.02, release = 0.16) {
  const attackGain = clamp(progress / attack, 0, 1);
  const releaseGain = clamp((1 - progress) / release, 0, 1);
  return attackGain * releaseGain;
}

function renderSample(profile, time, progress, index) {
  const base = envelope(progress);
  switch (profile) {
    case "ascending_double":
      return base * (0.55 * sine(progress < 0.52 ? 660 : 880, time) + 0.08 * sine(1320, time));
    case "descending_buzz":
      return base * (0.40 * sine(260 - 90 * progress, time) + 0.10 * noise(index, 1));
    case "success_arpeggio": {
      const notes = [523.25, 659.25, 783.99, 1046.5];
      const noteIndex = Math.min(notes.length - 1, Math.floor(progress * notes.length));
      return base * (0.42 * sine(notes[noteIndex], time) + 0.11 * sine(notes[noteIndex] * 2, time));
    }
    case "failure_drop":
      return base * (0.50 * sine(190 - 90 * progress, time) + 0.08 * sine(95, time));
    case "alert_pulse": {
      const pulse = Math.sin(progress * Math.PI * 6) > 0 ? 1 : 0.15;
      return base * pulse * (0.45 * sine(520, time) + 0.05 * sine(1040, time));
    }
    case "conflict_rise":
      return base * (0.48 * sine(150 + 360 * progress, time) + 0.12 * noise(index, 2) * (1 - progress));
    case "vehicle_click":
      return base * (0.26 * sine(420, time) + 0.18 * noise(index, 3) * Math.exp(-progress * 18));
    case "collision_thud":
      return base * (0.48 * noise(index, 4) * Math.exp(-progress * 12) + 0.24 * sine(120 - 40 * progress, time));
    case "destruction_alarm": {
      const pulse = Math.sin(progress * Math.PI * 8) > 0 ? 1 : 0.18;
      return base * pulse * (0.38 * sine(180, time) + 0.16 * sine(360, time));
    }
    case "scan_sweep":
      return base * (0.42 * sine(420 + 900 * progress, time) + 0.08 * sine(1680, time));
    case "checkpoint_soft":
      return base * (0.38 * sine(520, time) + 0.16 * sine(780, time));
    case "restart_reset":
      return base * (0.40 * sine(300 - 80 * progress, time) + 0.08 * sine(600, time));
    case "footstep":
      return base * (0.48 * noise(index, 6) * Math.exp(-progress * 22) + 0.12 * sine(110, time));
    case "vehicle_engine":
      return base * (0.34 * sine(92 + 18 * progress, time) + 0.16 * sine(184 + 36 * progress, time) + 0.06 * noise(index, 7));
    default:
      return 0;
  }
}

function encodeWav(samples) {
  const dataBytes = samples.length * 2;
  const buffer = Buffer.alloc(44 + dataBytes);
  buffer.write("RIFF", 0, "ascii");
  buffer.writeUInt32LE(36 + dataBytes, 4);
  buffer.write("WAVE", 8, "ascii");
  buffer.write("fmt ", 12, "ascii");
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(channels, 22);
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(sampleRate * channels * (bitsPerSample / 8), 28);
  buffer.writeUInt16LE(channels * (bitsPerSample / 8), 32);
  buffer.writeUInt16LE(bitsPerSample, 34);
  buffer.write("data", 36, "ascii");
  buffer.writeUInt32LE(dataBytes, 40);
  samples.forEach((sample, index) => buffer.writeInt16LE(Math.round(clamp(sample, -1, 1) * 32767), 44 + index * 2));
  return buffer;
}

function renderCue(profile, duration) {
  const sampleCount = Math.round(sampleRate * duration);
  const samples = new Array(sampleCount);
  for (let index = 0; index < sampleCount; index += 1) {
    const time = index / sampleRate;
    const progress = index / Math.max(1, sampleCount - 1);
    samples[index] = renderSample(profile, time, progress, index) * 0.72;
  }
  return encodeWav(samples);
}

fs.mkdirSync(outputRoot, {recursive: true});
const files = [];
for (const [id, definition] of Object.entries(cueDefinitions)) {
  const filePath = path.join(outputRoot, `${id}.wav`);
  const data = renderCue(definition.profile, definition.duration);
  fs.writeFileSync(filePath, data);
  files.push({
    id,
    profile: definition.profile,
    path: `res://assets/audio/generated/${id}.wav`,
    sample_rate: sampleRate,
    channels,
    duration_seconds: definition.duration,
    bytes: data.length,
    sha256: crypto.createHash("sha256").update(data).digest("hex"),
  });
}

const sourcePath = fileURLToPath(import.meta.url);
const manifest = {
  schema_version: 1,
  id: "original-procedural-audio-library-v1",
  status: "internal_candidate_only",
  generator: "art-source/audio/generated/build_audio_library.mjs",
  generator_sha256: crypto.createHash("sha256").update(fs.readFileSync(sourcePath)).digest("hex"),
  synthesis: "确定性 PCM 16-bit 单声道波形；不含第三方录音、采样或参考视频音频",
  files,
  release_allowed: false,
  remaining_gates: ["人工听感与混音审阅", "音量开关回放", "Windows 目标设备验证", "最终发布权利复核"],
};
fs.writeFileSync(path.join(outputRoot, "audio-library-manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
console.log(`原创程序化音频候选已生成：${files.length} 个 WAV；采样率 ${sampleRate} Hz；目录 ${path.relative(workspaceRoot, outputRoot)}`);
