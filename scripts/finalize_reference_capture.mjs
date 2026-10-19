import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {spawnSync} from "node:child_process";

const root = process.cwd();
const formalRoot = path.join(root, "reference-evidence/runtime-matrix");
const formalManifestPath = path.join(formalRoot, "manifest.json");
const formalTracePath = path.join(formalRoot, "trace-evidence.json");
const acceptancePath = path.join(root, "reference-evidence/acceptance-status.json");
const expectedAssetCatalogPath = "res://content/asset-runtime-catalog-original-only.json";

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (token === "--write") {
      args.write = true;
      continue;
    }
    if (token === "--help") {
      args.help = true;
      continue;
    }
    if (!token.startsWith("--")) throw new Error(`未知参数：${token}`);
    const value = argv[index + 1];
    if (!value || value.startsWith("--")) throw new Error(`参数缺少值：${token}`);
    args[token.slice(2)] = value;
    index += 1;
  }
  return args;
}

function usage() {
  console.log("用法：npm run finalize:reference:capture -- --source-dir <采集输出目录> --method <visible_window|windows_device> --operator <验收人> --captured-at <UTC时间> [--write]");
  console.log("默认只做预检；追加 --write 才会复制当前源 PNG、同步矩阵并记录采集会话。不会自动通过视觉。");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function readJson(filePath) {
  assert(fs.existsSync(filePath), `缺少文件：${filePath}`);
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function isPng(filePath) {
  if (!fs.existsSync(filePath)) return false;
  const bytes = fs.readFileSync(filePath);
  return bytes.length >= 24 && bytes.subarray(0, 8).toString("hex") === "89504e470d0a1a0a";
}

function runNode(script, args = []) {
  const result = spawnSync(process.execPath, [script, ...args], {cwd: root, encoding: "utf8"});
  if (result.status !== 0) {
    throw new Error(`${script} 失败：\n${result.stdout ?? ""}${result.stderr ?? ""}`);
  }
  if (result.stdout) process.stdout.write(result.stdout);
}

function currentSource() {
  const result = spawnSync(process.execPath, ["scripts/source_fingerprint.mjs"], {cwd: root, encoding: "utf8"});
  assert(result.status === 0, `无法计算当前源码指纹：${result.stderr ?? ""}`);
  const match = String(result.stdout).trim().match(/^([0-9a-f]{64}) files=(\d+)$/);
  assert(match, `当前源码指纹格式无效：${result.stdout}`);
  return {sha256: match[1], fileCount: Number(match[2])};
}

function validateTimestamp(value) {
  assert(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value ?? ""), "--captured-at 必须是带毫秒的 UTC 时间");
  const parsed = Date.parse(value);
  assert(Number.isFinite(parsed) && new Date(parsed).toISOString() === value, "--captured-at 不是有效 UTC 时间");
  assert(parsed <= Date.now(), "--captured-at 不能晚于当前时间");
}

const args = parseArgs(process.argv.slice(2));
if (args.help) {
  usage();
  process.exit(0);
}

const sourceDir = path.resolve(String(args["source-dir"] ?? ""));
assert(sourceDir !== root && fs.existsSync(sourceDir) && fs.statSync(sourceDir).isDirectory(), "--source-dir 必须是存在的采集输出目录");
const method = String(args.method ?? "visible_window");
assert(["visible_window", "windows_device"].includes(method), "--method 必须是 visible_window 或 windows_device");
if (args.write) {
  assert(String(args.operator ?? "").trim().length > 0, "--write 时必须提供 --operator");
  validateTimestamp(args["captured-at"]);
}

const source = currentSource();
const editorManifestPath = path.join(sourceDir, "matrix-manifest-editor.json");
const editorTracePath = path.join(sourceDir, "matrix-trace-evidence-editor.json");
const editorManifest = readJson(editorManifestPath);
const editorTrace = readJson(editorTracePath);

assert(editorManifest.capture_entry !== "headless_offscreen_probe", "离屏探针截图只能用于研发诊断，不能进入正式视觉矩阵");
assert(editorTrace.capture_entry !== "headless_offscreen_probe", "离屏探针事件只能用于研发诊断，不能进入正式视觉矩阵");

assert(editorManifest.source_fingerprint === source.sha256 && Number(editorManifest.source_file_count) === source.fileCount, "采集清单没有绑定当前源码，拒绝复制或同步");
assert(editorTrace.source_fingerprint === source.sha256 && Number(editorTrace.source_file_count) === source.fileCount, "事件清单没有绑定当前源码，拒绝复制或同步");
assert(editorManifest.asset_catalog_path === expectedAssetCatalogPath, `采集清单必须绑定原创边界目录：${expectedAssetCatalogPath}`);
assert(editorTrace.asset_catalog_path === expectedAssetCatalogPath, `事件清单必须绑定原创边界目录：${expectedAssetCatalogPath}`);
assert(editorManifest.visual_status === "unverified" && editorTrace.visual_status === "unverified", "采集清单不得自动标记视觉通过");
assert(Array.isArray(editorManifest.captures) && editorManifest.captures.length === 21, "采集清单必须包含 21 个分段");
assert(Array.isArray(editorTrace.captures) && editorTrace.captures.length === 21, "事件清单必须包含 21 个分段");

const captureIds = new Set();
for (const capture of editorManifest.captures) {
  assert(typeof capture.id === "string" && !captureIds.has(capture.id), `采集清单分段重复或无效：${capture.id}`);
  captureIds.add(capture.id);
  const sourcePng = path.join(sourceDir, `${capture.id}.png`);
  assert(isPng(sourcePng), `缺少有效 PNG：${sourcePng}`);
  assert(fs.statSync(sourcePng).size > 1024, `PNG 文件异常过小：${capture.id}`);
}
const traceIds = new Set(editorTrace.captures.map((capture) => capture.id));
assert(traceIds.size === 21 && [...captureIds].every((id) => traceIds.has(id)), "采集清单与事件清单分段集合不一致");

console.log(`当前源采集预检通过：${captureIds.size} 张 PNG；源指纹 ${source.sha256} / ${source.fileCount}`);
if (!args.write) {
  console.log("预检模式未写入正式矩阵；确认人工抽查后追加 --write。");
  process.exit(0);
}

const currentManifest = readJson(formalManifestPath);
const backupEntries = new Set([
  formalManifestPath,
  formalTracePath,
  path.join(formalRoot, "matrix-manifest-editor.json"),
  path.join(formalRoot, "matrix-trace-evidence-editor.json"),
  acceptancePath,
]);
for (const capture of currentManifest.captures ?? []) {
  backupEntries.add(path.join(root, "reference-evidence", capture.path));
  backupEntries.add(path.join(root, "reference-evidence", capture.comparison_report));
}
const backupRoot = fs.mkdtempSync(path.join("/tmp", "new-era-reference-capture-backup-"));
const backups = [];
for (const target of backupEntries) {
  if (!fs.existsSync(target)) continue;
  const backupPath = path.join(backupRoot, path.relative(root, target));
  fs.mkdirSync(path.dirname(backupPath), {recursive: true});
  fs.copyFileSync(target, backupPath);
  backups.push({target, backupPath});
}

function restoreOnFailure(error) {
  for (const {target, backupPath} of backups) fs.copyFileSync(backupPath, target);
  fs.rmSync(backupRoot, {recursive: true, force: true});
  throw error;
}

try {
  fs.copyFileSync(editorManifestPath, path.join(formalRoot, "matrix-manifest-editor.json"));
  fs.copyFileSync(editorTracePath, path.join(formalRoot, "matrix-trace-evidence-editor.json"));
  for (const capture of editorManifest.captures) {
    fs.copyFileSync(path.join(sourceDir, `${capture.id}.png`), path.join(formalRoot, `${capture.id}.png`));
  }
  runNode("scripts/sync_runtime_matrix_manifest.mjs");
  runNode("scripts/record_graphical_capture_session.mjs", [
    "--method", method,
    "--operator", String(args.operator).trim(),
    "--asset-catalog-path", expectedAssetCatalogPath,
    "--captured-at", args["captured-at"],
    "--write",
  ]);
  runNode("scripts/verify_runtime_matrix.mjs");
  runNode("scripts/verify_runtime_trace_evidence.mjs");
  runNode("scripts/verify_graphical_capture_readiness.mjs", ["--strict"]);
} catch (error) {
  restoreOnFailure(error);
}

fs.rmSync(backupRoot, {recursive: true, force: true});
console.log("当前源图形证据已完成安全同步；视觉状态仍保持 unverified，下一步必须逐段人工签收。");
