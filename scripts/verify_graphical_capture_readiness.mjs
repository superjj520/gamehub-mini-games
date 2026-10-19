import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";

const root = process.cwd();
const evidenceRoot = path.join(root, "reference-evidence/candidate-runtime");
const matrixPath = path.join(root, "reference-evidence/runtime-matrix/manifest.json");
const reportPath = path.join(evidenceRoot, "graphical-capture-readiness.json");
const strict = process.argv.includes("--strict");

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function collectJsonFiles(directory) {
  if (!fs.existsSync(directory)) return [];
  return fs.readdirSync(directory, {withFileTypes: true})
    .sort((a, b) => a.name.localeCompare(b.name))
    .flatMap((entry) => {
      const absolutePath = path.join(directory, entry.name);
      if (entry.isDirectory()) return collectJsonFiles(absolutePath);
      return entry.isFile() && entry.name.endsWith(".json") ? [absolutePath] : [];
    });
}

function isPng(filePath) {
  if (!fs.existsSync(filePath)) return false;
  const bytes = fs.readFileSync(filePath);
  return bytes.length >= 24 && bytes.readUInt32BE(0) === 0x89504e47;
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

function writeJsonAtomic(filePath, payload) {
  fs.mkdirSync(path.dirname(filePath), {recursive: true});
  const temporaryPath = `${filePath}.tmp-${process.pid}`;
  fs.writeFileSync(temporaryPath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
  fs.renameSync(temporaryPath, filePath);
}

const sourceOutput = execFileSync(process.execPath, ["scripts/source_fingerprint.mjs"], {
  cwd: root,
  encoding: "utf8",
}).trim();
const sourceMatch = sourceOutput.match(/^([0-9a-f]{64}) files=(\d+)$/);
if (!sourceMatch) throw new Error(`当前源码指纹格式无效：${sourceOutput}`);
const currentSourceSha256 = sourceMatch[1];
const currentSourceFileCount = Number(sourceMatch[2]);
const expectedAssetCatalogPath = "res://content/asset-runtime-catalog-original-only.json";
// Godot 导出会重写内容未变化的运行时元数据文件；内容指纹与 PNG 哈希才是
// 证据绑定依据，不能因为导出工具刷新了 mtime 就把同一份当前源截图判为过期。
const latestRuntimeMtimeMs = Math.max(...collectRuntimeFiles(path.join(root, "gta-reference-runtime")).map((filePath) => fs.statSync(filePath).mtimeMs));
const matrix = readJson(matrixPath);
const matrixSession = matrix.capture_session ?? null;
const matrixSessionValid = matrixSession?.source_fingerprint === currentSourceSha256
  && Number(matrixSession?.source_file_count) === currentSourceFileCount
  && ["visible_window", "windows_device"].includes(matrixSession?.method)
  && matrixSession?.session_status === "unverified_pending_visual_signoff"
  && matrixSession?.asset_catalog_path === expectedAssetCatalogPath
  && Number(matrixSession?.capture_count) === (matrix.captures?.length ?? 0);
const matrixCurrentPngs = matrixSessionValid
  ? (matrix.captures ?? []).filter((capture) => {
    const imagePath = path.join(root, "reference-evidence", capture.path);
    return capture.visual_status === "unverified"
      && isPng(imagePath)
      && capture.sha256 === sha256(imagePath)
      && capture.asset_catalog_path === expectedAssetCatalogPath;
  }).length
  : 0;
const requiredMatrixPngs = Array.isArray(matrix.captures) ? matrix.captures.length : 21;
const entries = [];
const blockers = [];
const warnings = [];

if (!matrixSessionValid) blockers.push("正式 21 段矩阵缺少当前源指纹下的非无头采集会话记录");
if (matrixCurrentPngs < requiredMatrixPngs) blockers.push(`正式矩阵当前有效 PNG 不完整：${matrixCurrentPngs}/${requiredMatrixPngs}`);

for (const filePath of collectJsonFiles(evidenceRoot)) {
  const payload = readJson(filePath);
  const status = String(payload.status ?? "");
  if (!status.includes("graphical_capture")) continue;

  const relativePath = path.relative(root, filePath);
  const runtimeSource = payload.source_sha256?.runtime_source_fingerprint ?? payload.runtime_source_fingerprint;
  const runtimeFileCount = Number(payload.source_sha256?.runtime_file_count ?? payload.runtime_file_count ?? 0);
  const imagePath = payload.image?.path ? path.join(root, payload.image.path) : null;
  const imagePresent = imagePath != null && isPng(imagePath);
  const currentSource = runtimeSource === currentSourceSha256 && runtimeFileCount === currentSourceFileCount;
  const imageHashMatches = imagePresent && payload.image?.sha256 === sha256(imagePath);
  entries.push({
    evidence: relativePath,
    capture_id: payload.capture_id ?? null,
    status,
    visual_status: payload.visual_status ?? null,
    release_allowed: payload.release_allowed ?? null,
    source_current: currentSource,
    image_path: payload.image?.path ?? null,
    image_present: imagePresent,
    image_hash_matches: imageHashMatches,
    failure_kind: payload.failure_kind ?? null,
  });
  // candidate-runtime 下的失败或旧候选元数据是历史诊断材料，不应阻断已经
  // 完成正式 21 段矩阵采集的当前版本；正式矩阵本身仍由上面的 session 和
  // PNG 完整性门禁负责。把两者分开，避免“有历史失败记录”被误读成“当前
  // 正式图形证据缺失”。
  if (!currentSource) warnings.push(`${relativePath} 未绑定当前源指纹`);
  if (!imagePresent) warnings.push(`${relativePath} 没有可读取的当前 PNG`);
  if (imagePresent && !imageHashMatches) warnings.push(`${relativePath} 的 PNG 哈希不匹配`);
}

const currentImages = entries.filter((entry) => entry.source_current && entry.image_present && entry.image_hash_matches);
// 候选隔离截图即使绑定当前源码，也不能计入正式 21 段矩阵；否则图形采集
// 阻断时会被误报成存在当前正式 PNG，进而让 P0 台账与准备度报告互相矛盾。
const currentSourceBoundPngs = matrixCurrentPngs;
const failureEntries = entries.filter((entry) => entry.failure_kind || entry.status.endsWith("_failed"));
const report = {
  schema_version: 1,
  generated_at: new Date().toISOString(),
  status: matrixCurrentPngs === requiredMatrixPngs ? "current_graphical_evidence_ready_for_manual_signoff" : "blocked_by_graphics_capture",
  strict,
  current_source: {sha256: currentSourceSha256, file_count: currentSourceFileCount},
  asset_catalog_path: expectedAssetCatalogPath,
  requirement: {
    no_headless_evidence: true,
    current_png_must_be_source_bound: true,
    manual_visual_signoff_still_required: true,
  },
  summary: {
    inspected_graphical_metadata: entries.length,
    current_source_bound_pngs: currentSourceBoundPngs,
    current_candidate_bound_pngs: currentImages.length,
    current_matrix_pngs: matrixCurrentPngs,
    required_matrix_pngs: requiredMatrixPngs,
    matrix_capture_session_valid: matrixSessionValid,
    latest_runtime_mtime: new Date(latestRuntimeMtimeMs).toISOString(),
    failed_capture_metadata: failureEntries.length,
  },
  entries,
  blockers: [...new Set(blockers)],
  warnings: [...new Set(warnings)],
  next_action: matrixCurrentPngs === requiredMatrixPngs
    ? "打开视觉审阅面板，逐段完成人工视觉签收"
    : "在可用桌面或 Windows 图形环境运行视觉采集器，完成后记录当前采集会话；失败前不得更新旧 PNG 的源指纹",
};
writeJsonAtomic(reportPath, report);

console.log(`图形采集准备度报告已写入：${path.relative(root, reportPath)}`);
console.log(`当前源绑定 PNG：${currentSourceBoundPngs}（正式矩阵 ${matrixCurrentPngs}/${requiredMatrixPngs}）；失败采集记录：${failureEntries.length}；阻断项：${report.blockers.length}；历史警告：${report.warnings.length}`);
for (const blocker of report.blockers) console.log(`- ${blocker}`);
if (strict && matrixCurrentPngs < requiredMatrixPngs) process.exit(1);
