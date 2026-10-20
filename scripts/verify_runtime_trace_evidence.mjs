import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { buildTraceGapReport } from "./trace_gap_report.mjs";

const root = process.cwd();
const tracePath = path.join(root, "reference-evidence", "runtime-matrix", "trace-evidence.json");
const acceptancePath = path.join(root, "reference-evidence", "acceptance-status.json");
const matrixPath = path.join(root, "reference-evidence", "runtime-matrix", "manifest.json");
const traceManifest = JSON.parse(fs.readFileSync(tracePath, "utf8"));
const acceptance = JSON.parse(fs.readFileSync(acceptancePath, "utf8"));
const matrix = JSON.parse(fs.readFileSync(matrixPath, "utf8"));
const runtimeRoot = path.join(root, "gta-reference-runtime");
const ignoredDirectories = new Set([".godot", ".import"]);
function collectFiles(directory) {
  const entries = fs.readdirSync(directory, { withFileTypes: true }).sort((left, right) => left.name.localeCompare(right.name));
  const files = [];
  for (const entry of entries) {
    if (entry.isDirectory() && ignoredDirectories.has(entry.name)) continue;
    const absolutePath = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...collectFiles(absolutePath));
    else if (entry.isFile() && !entry.name.endsWith(".import") && !entry.name.endsWith(".uid")) files.push(absolutePath);
  }
  return files;
}
const runtimeFiles = collectFiles(runtimeRoot);
const runtimeHash = crypto.createHash("sha256");
for (const filePath of runtimeFiles) {
  runtimeHash.update(path.relative(runtimeRoot, filePath).split(path.sep).join("/"));
  runtimeHash.update("\0");
  runtimeHash.update(fs.readFileSync(filePath));
  runtimeHash.update("\0");
}
const currentSourceFingerprint = runtimeHash.digest("hex");
if (traceManifest.source_fingerprint !== currentSourceFingerprint || traceManifest.source_file_count !== runtimeFiles.length) {
  throw new Error("运行时事件证据没有绑定当前源文件指纹，请重新采集并运行 sync_runtime_matrix_manifest.mjs");
}
if (matrix.source_fingerprint !== traceManifest.source_fingerprint || matrix.source_file_count !== traceManifest.source_file_count) {
  throw new Error("运行时事件证据与截图矩阵的源文件指纹不一致");
}
if (traceManifest.version !== 1) throw new Error("运行时事件证据版本不受支持");
if (traceManifest.visual_status !== "unverified") throw new Error("运行时事件证据不得自动批准视觉");
if (!Array.isArray(traceManifest.captures) || traceManifest.captures.length !== 21) {
  throw new Error("运行时事件证据必须覆盖 21 个分段");
}
const gapReport = buildTraceGapReport(traceManifest, acceptance, matrix);
const gapReportPath = path.join(root, "reference-evidence", "runtime-matrix", "trace-gap-report.json");
const storedGapReport = JSON.parse(fs.readFileSync(gapReportPath, "utf8"));
if (JSON.stringify(storedGapReport) !== JSON.stringify(gapReport)) {
  throw new Error("运行时事件缺口报告不是当前证据的只读派生结果，请运行 create_trace_gap_report.mjs");
}
if (gapReport.gap_count > 0) {
  console.log(`运行时事件证据结构验证通过：${gapReport.segment_count} 个分段；发现 ${gapReport.gap_count} 个期望事件缺口，行为证据状态保持 partial，视觉状态仍为 unverified`);
} else {
  console.log(`运行时事件证据验证通过：${gapReport.segment_count} 个分段，视觉状态仍为 unverified`);
}
