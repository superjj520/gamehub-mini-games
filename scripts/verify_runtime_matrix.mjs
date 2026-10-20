import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const manifestPath = path.join(root, "reference-evidence", "runtime-matrix", "manifest.json");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
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

const runtimeHash = crypto.createHash("sha256");
const runtimeFiles = collectFiles(runtimeRoot);
for (const filePath of runtimeFiles) {
  const relativePath = path.relative(runtimeRoot, filePath).split(path.sep).join("/");
  runtimeHash.update(relativePath);
  runtimeHash.update("\0");
  runtimeHash.update(fs.readFileSync(filePath));
  runtimeHash.update("\0");
}
const currentSourceFingerprint = runtimeHash.digest("hex");
if (manifest.source_fingerprint !== currentSourceFingerprint || manifest.source_file_count !== runtimeFiles.length) {
  throw new Error("运行时截图矩阵没有绑定当前源文件指纹，请重新采集并运行 sync_runtime_matrix_manifest.mjs");
}
if (!Array.isArray(manifest.captures) || manifest.captures.length !== 21) {
  throw new Error("运行时分段截图矩阵必须覆盖 21 个分段");
}
const ids = new Set();
for (const capture of manifest.captures) {
  if (ids.has(capture.id)) throw new Error(`运行时矩阵存在重复分段：${capture.id}`);
  ids.add(capture.id);
  if (capture.visual_status !== "unverified") throw new Error(`运行时矩阵不得自动通过视觉：${capture.id}`);
  const filePath = path.join(root, "reference-evidence", capture.path);
  const bytes = fs.readFileSync(filePath);
  if (bytes.subarray(0, 8).toString("hex") !== "89504e470d0a1a0a") {
    throw new Error(`运行时矩阵文件不是 PNG：${capture.id}`);
  }
  const sha256 = crypto.createHash("sha256").update(bytes).digest("hex");
  if (sha256 !== capture.sha256) throw new Error(`运行时矩阵指纹不匹配：${capture.id}`);
  const reportPath = path.join(root, "reference-evidence", capture.comparison_report);
  const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
  if (report.visual_status !== "unverified") throw new Error(`视觉对照报告不得自动通过：${capture.id}`);
  if (report.candidate_sha256 !== capture.sha256) throw new Error(`视觉对照报告未指向当前截图：${capture.id}`);
}
console.log(`运行时分段截图矩阵验证通过：${manifest.captures.length} 张，视觉通过仍为 0`);
