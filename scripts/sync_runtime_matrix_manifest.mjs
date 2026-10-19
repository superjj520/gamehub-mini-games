import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { assertSourceBinding } from "./source_binding_guard.mjs";

const root = path.resolve(".");
const runtimeRoot = path.join(root, "gta-reference-runtime");
const manifestPath = path.join(root, "reference-evidence", "runtime-matrix", "manifest.json");
const editorManifestPath = path.join(root, "reference-evidence", "runtime-matrix", "matrix-manifest-editor.json");
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

const hash = crypto.createHash("sha256");
const runtimeFiles = collectFiles(runtimeRoot);
for (const filePath of runtimeFiles) {
  const relativePath = path.relative(runtimeRoot, filePath).split(path.sep).join("/");
  hash.update(relativePath);
  hash.update("\0");
  hash.update(fs.readFileSync(filePath));
  hash.update("\0");
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const editorManifest = fs.existsSync(editorManifestPath)
  ? JSON.parse(fs.readFileSync(editorManifestPath, "utf8"))
  : null;
const editorCaptures = new Map((editorManifest?.captures ?? []).map((capture) => [capture.id, capture]));
const sourceFingerprint = hash.digest("hex");
const sourceFileCount = runtimeFiles.length;

if (!editorManifest) {
  throw new Error("缺少 source-bound 图形采集清单，拒绝把未绑定 PNG 同步为正式视觉证据");
}
assertSourceBinding(editorManifest, "图形采集清单", sourceFingerprint, sourceFileCount);
for (const capture of manifest.captures) {
  const editorCapture = editorCaptures.get(capture.id);
  if (!editorCapture) {
    throw new Error(`图形采集清单缺少正式矩阵条目 ${capture.id}，拒绝同步混合版本证据`);
  }
  assertSourceBinding(editorCapture, `图形采集条目 ${capture.id}`, sourceFingerprint, sourceFileCount);
}
const tracePath = path.join(root, "reference-evidence", "runtime-matrix", "trace-evidence.json");
const editorTracePath = path.join(root, "reference-evidence", "runtime-matrix", "matrix-trace-evidence-editor.json");
const traceManifest = fs.existsSync(editorTracePath)
  ? JSON.parse(fs.readFileSync(editorTracePath, "utf8"))
  : JSON.parse(fs.readFileSync(tracePath, "utf8"));
assertSourceBinding(
  traceManifest,
  fs.existsSync(editorTracePath) ? "事件采集清单" : "现有事件证据",
  sourceFingerprint,
  sourceFileCount,
);
const acceptancePath = path.join(root, "reference-evidence", "acceptance-status.json");
const acceptance = JSON.parse(fs.readFileSync(acceptancePath, "utf8"));

manifest.source_fingerprint = sourceFingerprint;
manifest.source_file_count = sourceFileCount;
for (const capture of manifest.captures) {
  const editorCapture = editorCaptures.get(capture.id);
  if (editorCapture) {
    capture.asset_catalog_path = editorCapture.asset_catalog_path;
    capture.capture_entry = editorCapture.capture_entry;
    capture.capture_profile = editorCapture.capture_profile;
    capture.state_setup = editorCapture.state_setup;
    capture.visual_state = editorCapture.visual_state;
    capture.source_fingerprint = editorCapture.source_fingerprint;
    capture.source_file_count = editorCapture.source_file_count;
  }
  const candidatePath = path.join(root, "reference-evidence", capture.path);
  capture.sha256 = crypto.createHash("sha256").update(fs.readFileSync(candidatePath)).digest("hex");
  capture.visual_status = "unverified";
  const comparisonPath = path.join(root, "reference-evidence", capture.comparison_report);
  const comparison = JSON.parse(fs.readFileSync(comparisonPath, "utf8"));
  comparison.candidate_sha256 = capture.sha256;
  comparison.visual_status = "unverified";
  fs.writeFileSync(comparisonPath, `${JSON.stringify(comparison, null, 2)}\n`, "utf8");
}
fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
traceManifest.source_fingerprint = sourceFingerprint;
traceManifest.source_file_count = sourceFileCount;
fs.writeFileSync(tracePath, `${JSON.stringify(traceManifest, null, 2)}\n`, "utf8");
const shortFingerprint = sourceFingerprint.slice(0, 8);
for (const segment of acceptance.segments ?? []) {
  const review = segment.behavior_review;
  if (!review || typeof review !== "object") continue;
  review.runtime_source_fingerprint = sourceFingerprint;
  if (typeof review.replay_id === "string") {
    review.replay_id = review.replay_id.replace(/-[0-9a-f]{8}$/i, `-${shortFingerprint}`);
  }
}
fs.writeFileSync(acceptancePath, `${JSON.stringify(acceptance, null, 2)}\n`, "utf8");
console.log(`运行时矩阵与事件证据已绑定源指纹：${sourceFingerprint} files=${sourceFileCount}`);
