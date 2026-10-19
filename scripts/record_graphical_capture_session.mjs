import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";

const root = process.cwd();
const matrixPath = path.join(root, "reference-evidence/runtime-matrix/manifest.json");
const matrix = JSON.parse(fs.readFileSync(matrixPath, "utf8"));
const args = Object.fromEntries(process.argv.slice(2).reduce((pairs, token, index, values) => {
  if (!token.startsWith("--")) return pairs;
  pairs.push([token.slice(2), values[index + 1]]);
  return pairs;
}, []));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function collectRuntimeFiles(directory) {
  const ignored = new Set([".godot", ".import"]);
  return fs.readdirSync(directory, {withFileTypes: true}).flatMap((entry) => {
    if (entry.isDirectory() && ignored.has(entry.name)) return [];
    const absolutePath = path.join(directory, entry.name);
    if (entry.isDirectory()) return collectRuntimeFiles(absolutePath);
    return entry.isFile() && !entry.name.endsWith(".import") && !entry.name.endsWith(".uid") ? [absolutePath] : [];
  });
}

const method = args.method;
const operator = String(args.operator ?? "").trim();
const capturedAt = args["captured-at"];
const expectedAssetCatalogPath = "res://content/asset-runtime-catalog-original-only.json";
const assetCatalogPath = String(args["asset-catalog-path"] ?? "").trim();
const timestampPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;
assert(["visible_window", "windows_device"].includes(method), "--method 必须是 visible_window 或 windows_device");
assert(operator.length > 0, "必须提供 --operator");
assert(timestampPattern.test(capturedAt ?? ""), "--captured-at 必须是带毫秒的 UTC 时间");
assert(Date.parse(capturedAt) <= Date.now(), "--captured-at 不能晚于当前时间");
assert(assetCatalogPath === expectedAssetCatalogPath, `--asset-catalog-path 必须绑定原创边界目录：${expectedAssetCatalogPath}`);

const sourceOutput = execFileSync(process.execPath, ["scripts/source_fingerprint.mjs"], {
  cwd: root,
  encoding: "utf8",
}).trim();
const sourceMatch = sourceOutput.match(/^([0-9a-f]{64}) files=(\d+)$/);
assert(sourceMatch, `当前源码指纹格式无效：${sourceOutput}`);
const sourceFingerprint = sourceMatch[1];
const sourceFileCount = Number(sourceMatch[2]);
assert(matrix.source_fingerprint === sourceFingerprint && matrix.source_file_count === sourceFileCount, "矩阵尚未绑定当前正式运行时源指纹");
assert(Array.isArray(matrix.captures) && matrix.captures.length === 21, "正式矩阵必须覆盖 21 个分段");
for (const capture of matrix.captures) {
  assert(capture.visual_status === "unverified", `视觉状态必须保持 unverified：${capture.id}`);
  const imagePath = path.join(root, "reference-evidence", capture.path);
  assert(fs.existsSync(imagePath), `缺少运行时 PNG：${capture.id}`);
  const hash = crypto.createHash("sha256").update(fs.readFileSync(imagePath)).digest("hex");
  assert(hash === capture.sha256, `运行时 PNG 哈希不匹配：${capture.id}`);
}

const session = {
  operator,
  method,
  captured_at: capturedAt,
  source_fingerprint: sourceFingerprint,
  source_file_count: sourceFileCount,
  asset_catalog_path: assetCatalogPath,
  capture_count: matrix.captures.length,
  session_status: "unverified_pending_visual_signoff",
  note: "由负责人确认本批 PNG 来自真实可见窗口或 Windows 目标设备；该记录不等于视觉通过",
};
console.log(`图形采集会话预览：${method}；${matrix.captures.length} 张 PNG；源指纹 ${sourceFingerprint}`);
if (!process.argv.includes("--write")) {
  console.log("未写入矩阵清单；确认真实采集完成后追加 --write");
  process.exit(0);
}
matrix.capture_session = session;
fs.writeFileSync(matrixPath, `${JSON.stringify(matrix, null, 2)}\n`, "utf8");
console.log(`图形采集会话已写入：${matrixPath}`);
