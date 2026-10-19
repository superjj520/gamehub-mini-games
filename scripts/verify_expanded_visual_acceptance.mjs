import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const root = process.cwd();
const matrixPath = path.join(root, "docs/expanded-visual-acceptance-matrix.json");
const matrix = JSON.parse(fs.readFileSync(matrixPath, "utf8"));
const runtimeRoot = path.join(root, "gta-reference-runtime");
const expandedEvidenceRoot = path.join(root, "reference-evidence", "expanded-runtime-matrix");
const allowedStatus = new Set(["proposed", "unverified", "passed", "blocked", "not_implemented"]);
const errors = [];

function collectFiles(directory) {
  const entries = fs.readdirSync(directory, { withFileTypes: true }).sort((left, right) => left.name.localeCompare(right.name));
  const files = [];
  for (const entry of entries) {
    if (entry.isDirectory() && [".godot", ".import"].includes(entry.name)) continue;
    const absolutePath = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...collectFiles(absolutePath));
    else if (entry.isFile() && !entry.name.endsWith(".import") && !entry.name.endsWith(".uid")) files.push(absolutePath);
  }
  return files;
}

const sourceHash = crypto.createHash("sha256");
const sourceFiles = collectFiles(runtimeRoot);
for (const filePath of sourceFiles) {
  sourceHash.update(path.relative(runtimeRoot, filePath).split(path.sep).join("/"));
  sourceHash.update("\0");
  sourceHash.update(fs.readFileSync(filePath));
  sourceHash.update("\0");
}
const currentSourceFingerprint = sourceHash.digest("hex");
if (matrix.source_fingerprint !== currentSourceFingerprint) errors.push("扩展视觉矩阵没有绑定当前运行时源指纹");

const manifestPath = path.join(expandedEvidenceRoot, "manifest.json");
if (fs.existsSync(manifestPath)) {
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  if (manifest.source_fingerprint !== currentSourceFingerprint || manifest.source_file_count !== sourceFiles.length) {
    errors.push("扩展截图 manifest 没有绑定当前运行时源指纹或文件数量");
  }
}

const behaviorEvidencePath = path.join(root, matrix.behavior_evidence_path || "reference-evidence/expanded-runtime-matrix/behavior-evidence.json");
if (!fs.existsSync(behaviorEvidencePath)) {
  errors.push(`扩展行为证据不存在：${matrix.behavior_evidence_path || "未配置路径"}`);
} else {
  const behaviorEvidence = JSON.parse(fs.readFileSync(behaviorEvidencePath, "utf8"));
  if (behaviorEvidence.source_fingerprint !== currentSourceFingerprint || behaviorEvidence.source_file_count !== sourceFiles.length) {
    errors.push("扩展行为证据没有绑定当前运行时源指纹或文件数量");
  }
  if (behaviorEvidence.status !== "expanded_behavior_verified") errors.push(`扩展行为证据状态不是 expanded_behavior_verified：${behaviorEvidence.status}`);
  const passedEntries = new Set((behaviorEvidence.tests ?? []).filter((test) => test.status === "passed").flatMap((test) => test.expanded_entries ?? []));
  for (const entry of matrix.entries ?? []) {
    if (!passedEntries.has(entry.id)) errors.push(`${entry.id} 缺少通过的扩展行为证据`);
  }
}

if (matrix.schema_version !== 1) errors.push("扩展视觉矩阵 schema_version 必须为 1");
if (matrix.status !== "supplemental_scope_proposed") errors.push("扩展视觉矩阵必须明确标记 supplemental_scope_proposed");
if (!Array.isArray(matrix.entries) || matrix.entries.length < 12) errors.push("扩展视觉矩阵至少需要 12 个独立验收项");

const ids = new Set();
let passed = 0;
let unverified = 0;
let proposed = 0;
for (const entry of matrix.entries ?? []) {
  if (!entry.id || ids.has(entry.id)) errors.push(`扩展验收项 id 缺失或重复：${entry.id || "<empty>"}`);
  ids.add(entry.id);
  for (const field of ["chapter", "content_area", "visual_state", "visual_status", "capture_path", "required_capabilities", "required_evidence"]) {
    if (!Object.prototype.hasOwnProperty.call(entry, field)) errors.push(`${entry.id} 缺少字段：${field}`);
  }
  if (!allowedStatus.has(entry.visual_status)) errors.push(`${entry.id} 的 visual_status 不受支持：${entry.visual_status}`);
  if (!Array.isArray(entry.required_capabilities) || entry.required_capabilities.length === 0) errors.push(`${entry.id} 缺少 required_capabilities`);
  if (!Array.isArray(entry.required_evidence) || entry.required_evidence.length === 0) errors.push(`${entry.id} 缺少 required_evidence`);
  if (entry.visual_status === "passed") {
    passed += 1;
    if (!entry.capture_path) errors.push(`${entry.id} 已标记 passed 但没有 capture_path`);
    if (!entry.review || entry.review.decision !== "passed" || !entry.review.reviewer || !entry.review.reviewed_at || !entry.review.method || entry.review.runtime_source_fingerprint !== matrix.source_fingerprint || !entry.review.runtime_screenshot_sha256) {
      errors.push(`${entry.id} 已标记 passed 但缺少完整人工复核记录`);
    }
  } else if (entry.visual_status === "unverified") {
    unverified += 1;
  } else if (entry.visual_status === "proposed") {
    proposed += 1;
  }
  if (entry.capture_path) {
    const capturePath = path.join(root, entry.capture_path);
    if (!fs.existsSync(capturePath)) {
      errors.push(`${entry.id} 的 capture_path 文件不存在：${entry.capture_path}`);
    } else {
      const bytes = fs.readFileSync(capturePath);
      if (bytes.subarray(0, 8).toString("hex") !== "89504e470d0a1a0a") errors.push(`${entry.id} 的 capture_path 不是 PNG`);
    }
  }
}

if (errors.length > 0) {
  console.error(`扩展视觉验收矩阵验证失败：${errors.length} 项`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

const summary = `扩展视觉验收矩阵验证通过：${matrix.entries.length} 项；passed=${passed}，unverified=${unverified}，proposed=${proposed}`;
console.log(summary);
if (process.argv.includes("--strict") && passed !== matrix.entries.length) {
  console.error("严格模式阻断：扩展视觉项尚未全部完成人工验收");
  process.exit(1);
}
