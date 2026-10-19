import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const runtimeRoot = path.join(root, "gta-reference-runtime");
const matrixPath = path.join(root, "docs", "expanded-visual-acceptance-matrix.json");
const recordsPath = path.join(root, "reference-evidence", "expanded-runtime-matrix", "capture-records.json");
const manifestPath = path.join(root, "reference-evidence", "expanded-runtime-matrix", "manifest.json");
const ignoredDirectories = new Set([".godot", ".import"]);
const allowCurrentRebind = process.argv.includes("--rebind-current");
const invalidateCurrentEvidence = process.argv.includes("--invalidate-current");

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

function runtimeFingerprint() {
  const hash = crypto.createHash("sha256");
  const files = collectFiles(runtimeRoot);
  for (const filePath of files) {
    const relativePath = path.relative(runtimeRoot, filePath).split(path.sep).join("/");
    hash.update(relativePath);
    hash.update("\0");
    hash.update(fs.readFileSync(filePath));
    hash.update("\0");
  }
  return { hash: hash.digest("hex"), count: files.length };
}

function readPngMetadata(filePath) {
  const bytes = fs.readFileSync(filePath);
  if (bytes.subarray(0, 8).toString("hex") !== "89504e470d0a1a0a") {
    throw new Error(`扩展截图不是 PNG：${filePath}`);
  }
  return {
    sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    width: bytes.readUInt32BE(16),
    height: bytes.readUInt32BE(20),
    bytes: bytes.length,
  };
}

const fingerprint = runtimeFingerprint();
const matrix = JSON.parse(fs.readFileSync(matrixPath, "utf8"));
const previousSourceFingerprint = matrix.source_fingerprint ?? null;
if (matrix.source_fingerprint !== fingerprint.hash && !allowCurrentRebind && !invalidateCurrentEvidence) {
  throw new Error("扩展截图采集记录与当前运行时源指纹不一致，拒绝绑定旧证据");
}
if (matrix.source_fingerprint !== fingerprint.hash && allowCurrentRebind) {
  console.warn("扩展矩阵源指纹已变化；本次使用刚完成的真实图形采集结果重新绑定当前源指纹");
}
const recordsPayload = JSON.parse(fs.readFileSync(recordsPath, "utf8"));
const records = recordsPayload.captures ?? [];
const recordById = new Map();
for (const record of records) {
  if (recordById.has(record.id)) throw new Error(`扩展截图记录重复：${record.id}`);
  const relativePath = record.path;
  const absolutePath = path.join(root, relativePath);
  if (!fs.existsSync(absolutePath)) throw new Error(`扩展截图文件不存在：${relativePath}`);
  const metadata = readPngMetadata(absolutePath);
  recordById.set(record.id, { ...record, ...metadata });
}

let boundCount = 0;
for (const entry of matrix.entries ?? []) {
  if (invalidateCurrentEvidence) {
    entry.capture_path = null;
    entry.visual_status = "unverified";
    entry.review = null;
    continue;
  }
  const record = recordById.get(entry.id);
  if (!record) continue;
  entry.capture_path = record.path;
  entry.visual_status = "unverified";
  entry.review = null;
  boundCount += 1;
}
matrix.source_fingerprint = fingerprint.hash;
matrix.source_file_count = fingerprint.count;

const manifest = {
  version: 1,
  policy: "扩展截图是视觉验收输入，不等于视觉通过；每项仍需事件证据、人工复核和目标设备证据",
  captured_at: new Date().toISOString().slice(0, 10),
  capture_script: "scripts/capture_expanded_visual_matrix.gd",
  source_fingerprint: fingerprint.hash,
  source_file_count: fingerprint.count,
  visual_status: "unverified",
  captures: invalidateCurrentEvidence ? [] : [...recordById.values()],
  historical_capture_source_fingerprint: invalidateCurrentEvidence ? previousSourceFingerprint : null,
  historical_capture_record_count: invalidateCurrentEvidence ? records.length : 0,
};

fs.writeFileSync(matrixPath, `${JSON.stringify(matrix, null, 2)}\n`, "utf8");
fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
if (invalidateCurrentEvidence) {
  console.log(`扩展视觉当前证据已失效化：保留历史记录 ${records.length} 项；当前 PNG 绑定为 0 项；源指纹 ${fingerprint.hash}`);
} else {
  console.log(`扩展视觉证据已绑定：${boundCount} 项；源指纹 ${fingerprint.hash}；所有视觉状态保持 unverified`);
}
