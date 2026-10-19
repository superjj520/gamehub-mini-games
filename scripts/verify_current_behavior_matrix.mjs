import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";

const root = process.cwd();
const readJson = (relativePath) => JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
const sourceOutput = execFileSync(process.execPath, ["scripts/source_fingerprint.mjs"], {cwd: root, encoding: "utf8"}).trim();
const sourceMatch = sourceOutput.match(/^([0-9a-f]{64}) files=(\d+)$/);
if (!sourceMatch) throw new Error(`当前源码指纹格式无效：${sourceOutput}`);
const report = readJson("reference-evidence/current-runtime-behavior/manifest.json");
const trace = readJson("reference-evidence/current-runtime-behavior/trace-evidence.json");
const acceptance = readJson("reference-evidence/acceptance-status.json");
if (report.status !== "current_behavior_matrix_verified" || report.visual_status !== "unverified") throw new Error("当前行为矩阵状态不正确");
if (report.source_fingerprint !== sourceMatch[1] || report.source_file_count !== Number(sourceMatch[2])) throw new Error("当前行为矩阵未绑定当前源码");
if (trace.source_fingerprint !== sourceMatch[1] || trace.source_file_count !== Number(sourceMatch[2])) throw new Error("当前行为轨迹未绑定当前源码");
if (!Array.isArray(trace.captures) || trace.captures.length !== 21) throw new Error("当前行为轨迹必须覆盖 21 个分段");
const traceById = new Map(trace.captures.map((capture) => [capture.id, capture]));
const aliases = {camera: "camera_state", perception: "perception_state", inventory: "inventory_changed"};
for (const segment of acceptance.segments) {
  const capture = traceById.get(segment.id);
  if (!capture) throw new Error(`当前行为轨迹缺少分段：${segment.id}`);
  const types = new Set(capture.event_types ?? (capture.trace_events ?? []).map((event) => event.type));
  for (const expected of segment.runtime_events) {
    const actual = aliases[expected] ?? expected;
    if (!types.has(actual)) throw new Error(`当前行为轨迹缺少事件：${segment.id}/${actual}`);
  }
}
console.log(`当前行为矩阵验证通过：21/21 分段、源指纹 ${sourceMatch[1]} / ${sourceMatch[2]} 个文件；视觉状态仍为 unverified`);
