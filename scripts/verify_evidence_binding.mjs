import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
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
const hash = crypto.createHash("sha256");
for (const filePath of runtimeFiles) {
  hash.update(path.relative(runtimeRoot, filePath).split(path.sep).join("/"));
  hash.update("\0");
  hash.update(fs.readFileSync(filePath));
  hash.update("\0");
}
const expected = { sha256: hash.digest("hex"), file_count: runtimeFiles.length };
const readJson = (relativePath) => JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
const matrix = readJson("reference-evidence/runtime-matrix/manifest.json");
const trace = readJson("reference-evidence/runtime-matrix/trace-evidence.json");
const currentBehavior = readJson("reference-evidence/current-runtime-behavior/manifest.json");
const currentBehaviorTrace = readJson("reference-evidence/current-runtime-behavior/trace-evidence.json");
const release = readJson("docs/release-manifest.json");
const readiness = readJson("docs/readiness-report.json");
const graphicalReadiness = readJson("reference-evidence/candidate-runtime/graphical-capture-readiness.json");
const candidate = readJson("build/internal-candidate-manifest.json");

const bindings = [
  ["当前行为矩阵", currentBehavior.source_fingerprint, currentBehavior.source_file_count],
  ["当前行为事件证据", currentBehaviorTrace.source_fingerprint, currentBehaviorTrace.source_file_count],
  ["候选发布清单", release.source?.sha256, release.source?.file_count],
  ["发布准备报告", readiness.build_identity?.source_sha256, readiness.build_identity?.source_file_count],
  ["图形采集准备度报告", graphicalReadiness.current_source?.sha256, graphicalReadiness.current_source?.file_count],
  ["内部候选树", candidate.candidate?.sha256, candidate.candidate?.file_count],
];
const bindingErrors = [];
for (const [name, sha256, fileCount] of bindings) {
  if (sha256 !== expected.sha256 || fileCount !== expected.file_count) {
    bindingErrors.push(`${name}未绑定当前源：期望 ${expected.sha256}/${expected.file_count}，实际 ${sha256}/${fileCount}`);
  }
}
if (currentBehavior.captureless !== true || currentBehavior.segment_count !== 21 || !Array.isArray(currentBehaviorTrace.captures) || currentBehaviorTrace.captures.length !== 21) {
  bindingErrors.push("当前行为证据没有覆盖 21 个无图形回放分段");
}
const historicalVisualMatrix = matrix.source_fingerprint !== expected.sha256 || matrix.source_file_count !== expected.file_count;
if (historicalVisualMatrix && matrix.captures?.some((capture) => capture.visual_status === "passed")) {
  bindingErrors.push("历史视觉矩阵包含已通过项目，禁止在未重新采集当前源截图前保留通过状态");
}
if (candidate.reproducibility?.passed !== true || candidate.reproducibility?.first?.sha256 !== expected.sha256 || candidate.reproducibility?.second?.sha256 !== expected.sha256) {
  bindingErrors.push("内部候选树缺少与当前源一致的可重复构建证明");
}
if (bindingErrors.length > 0) {
  console.error(`证据绑定未通过：${bindingErrors.length} 项；当前版本仍不可进入发布门禁`);
  for (const error of bindingErrors) console.error(`- ${error}`);
  process.exit(1);
}
console.log(`证据绑定一致性验证通过：当前行为、发布清单、准备报告和内部候选树均绑定 ${expected.sha256} / ${expected.file_count} 个文件；视觉矩阵 ${historicalVisualMatrix ? "保留为历史待重采集" : "已绑定当前源"}`);
