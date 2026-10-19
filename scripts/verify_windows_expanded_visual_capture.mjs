import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const expectedAssetCatalogPath = "res://tests/asset-runtime-catalog-full-candidates.json";
const runFlagIndex = process.argv.indexOf("--run");
const buildManifestFlagIndex = process.argv.indexOf("--build-manifest");
const runPath = runFlagIndex >= 0 ? process.argv[runFlagIndex + 1] : "";
const evidenceRootFlagIndex = process.argv.indexOf("--evidence-root");
const evidenceRoot = path.resolve(root, evidenceRootFlagIndex >= 0
  ? (process.argv[evidenceRootFlagIndex + 1] ?? "")
  : "reference-evidence/candidate-windows-device-qa");

function failMissingEvidence(message) {
  console.error(`Windows 扩展视觉证据尚未形成：${message}`);
  console.error("这表示目标设备还没有执行真实图形采集，不表示候选构建失败；请先运行 Windows 扩展视觉采集脚本，再重新执行本验证器。");
  process.exit(2);
}

let resolvedRunPath = runPath;
if (!resolvedRunPath) {
  if (!fs.existsSync(evidenceRoot)) failMissingEvidence(`未找到证据目录：${evidenceRoot}`);
  const latest = fs.readdirSync(evidenceRoot, {withFileTypes: true})
    .filter((entry) => entry.isDirectory() && entry.name.startsWith("expanded-run-"))
    .map((entry) => entry.name)
    .sort()
    .at(-1);
  if (!latest) failMissingEvidence(`证据目录中没有扩展视觉运行目录：${evidenceRoot}`);
  resolvedRunPath = path.relative(root, path.join(evidenceRoot, latest));
}

const runDirectory = path.resolve(root, resolvedRunPath);
const runRecordPath = path.join(runDirectory, "windows-expanded-visual-run.json");
const buildManifestPath = path.resolve(root, buildManifestFlagIndex >= 0
  ? (process.argv[buildManifestFlagIndex + 1] ?? "")
  : "reference-evidence/candidate-runtime/full-candidate-windows-build.json");
if (!fs.existsSync(runRecordPath)) throw new Error(`扩展视觉采集记录不存在：${runRecordPath}`);
if (!fs.existsSync(buildManifestPath)) throw new Error(`当前 Windows 构建清单不存在：${buildManifestPath}`);

const runRecord = JSON.parse(fs.readFileSync(runRecordPath, "utf8"));
const buildManifest = JSON.parse(fs.readFileSync(buildManifestPath, "utf8"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function hash(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function pngSize(filePath) {
  const bytes = fs.readFileSync(filePath);
  assert(bytes.subarray(0, 8).toString("hex") === "89504e470d0a1a0a", `文件不是 PNG：${filePath}`);
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20), bytes: bytes.length };
}

const expectedIds = [
  "launcher-cold-boot", "launcher-focus-navigation", "global-crash-recovery-prompt",
  "office-success-feedback", "office-search-loop", "office-failure-overlay", "office-checkpoint-recovery",
  "office-pause-overlay", "global-audio-disabled-fallback", "office-resolution-variants",
  "global-missing-asset-blocked", "city-store-transition", "city-crowd-variants", "city-traffic-near-miss",
  "city-neighborhood-extension", "city-weather-lighting-extension", "city-vehicle-damage-feedback",
  "city-delivery-completion",
];

assert(runRecord.schema_version === 1, "扩展视觉采集记录版本不支持");
assert(runRecord.status === "unverified_pending_visual_signoff", `扩展视觉采集状态不是成功未签收：${runRecord.status}`);
assert(runRecord.visual_status === "unverified", "扩展视觉采集不得直接标记为通过");
assert(runRecord.manual_visual_signoff === "pending", "扩展视觉采集不应包含人工签收结果");
assert(runRecord.asset_catalog_path === expectedAssetCatalogPath, "扩展视觉采集没有绑定包内候选资产目录");
assert(runRecord.build?.sha256 === buildManifest.build?.sha256, "扩展视觉采集程序哈希与当前 Windows 构建不一致");
assert(runRecord.build?.bytes === buildManifest.build?.bytes, "扩展视觉采集程序字节数与当前 Windows 构建不一致");
assert(runRecord.evidence_contract?.source?.sha256 === buildManifest.package?.source_sha256, "扩展视觉采集源指纹不一致");
assert(runRecord.evidence_contract?.source?.file_count === buildManifest.package?.source_file_count, "扩展视觉采集源文件数不一致");
assert(runRecord.evidence_contract?.candidate_package?.sha256 === buildManifest.package?.sha256, "扩展视觉采集候选包指纹不一致");
assert(runRecord.evidence_contract?.candidate_package?.file_count === buildManifest.package?.file_count, "扩展视觉采集候选包文件数不一致");
assert(Number(runRecord.expected_capture_count) === expectedIds.length, "扩展视觉采集预期数量不一致");
assert(Array.isArray(runRecord.captures) && runRecord.captures.length === expectedIds.length, `扩展视觉采集数量不是 ${expectedIds.length} 项`);

const expandedDirectory = path.join(runDirectory, "reference-evidence/expanded-runtime-matrix");
const capturesById = new Map();
for (const capture of runRecord.captures) {
  assert(!capturesById.has(capture.id), `扩展视觉采集存在重复 id：${capture.id}`);
  capturesById.set(capture.id, capture);
}
for (const id of expectedIds) {
  const capture = capturesById.get(id);
  assert(capture, `扩展视觉采集缺少项目：${id}`);
  const filePath = path.join(expandedDirectory, `${id}.png`);
  assert(fs.existsSync(filePath), `扩展视觉 PNG 不存在：${filePath}`);
  const dimensions = pngSize(filePath);
  assert(dimensions.width === 1280 && dimensions.height === 720, `扩展视觉 PNG 尺寸异常：${id} -> ${dimensions.width}x${dimensions.height}`);
  assert(hash(filePath) === capture.sha256, `扩展视觉 PNG 哈希不一致：${id}`);
  assert(capture.visual_status === "unverified", `扩展视觉项目不得自动通过：${id}`);
  assert(capture.asset_catalog_path === expectedAssetCatalogPath, `扩展视觉项目没有绑定包内候选资产目录：${id}`);
}

console.log(`Windows 扩展视觉采集静态核验通过：${expectedIds.length} 项；源指纹 ${buildManifest.package.source_sha256}/${buildManifest.package.source_file_count}；视觉仍为 unverified`);
