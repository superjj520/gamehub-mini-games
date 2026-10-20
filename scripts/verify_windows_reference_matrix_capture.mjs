import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const expectedAssetCatalogPath = "res://tests/asset-runtime-catalog-full-candidates.json";
const runArgIndex = process.argv.indexOf("--run");
const buildManifestFlagIndex = process.argv.indexOf("--build-manifest");
const evidenceRootFlagIndex = process.argv.indexOf("--evidence-root");
const evidenceBase = path.resolve(root, evidenceRootFlagIndex >= 0
  ? (process.argv[evidenceRootFlagIndex + 1] ?? "")
  : "reference-evidence/candidate-windows-device-qa");
const requestedRun = runArgIndex >= 0 ? process.argv[runArgIndex + 1] : null;
const buildManifestPath = path.resolve(root, buildManifestFlagIndex >= 0
  ? (process.argv[buildManifestFlagIndex + 1] ?? "")
  : "reference-evidence/candidate-runtime/full-candidate-windows-build.json");

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function failMissingEvidence(message) {
  console.error(`Windows 参考矩阵尚未形成：${message}`);
  console.error("这表示目标设备还没有执行真实图形采集，不表示候选构建失败；请先运行 Windows 采集脚本，再重新执行本验证器。");
  process.exit(2);
}

function readPngDimensions(filePath) {
  const bytes = fs.readFileSync(filePath);
  assert(bytes.subarray(0, 8).toString("hex") === "89504e470d0a1a0a", `不是 PNG：${filePath}`);
  assert(bytes.toString("ascii", 12, 16) === "IHDR", `PNG 缺少 IHDR：${filePath}`);
  return {width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20)};
}

function chooseRunDirectory() {
  if (requestedRun) return path.resolve(root, requestedRun);
  const candidates = fs.existsSync(evidenceBase)
    ? fs.readdirSync(evidenceBase, {withFileTypes: true})
      .filter((entry) => entry.isDirectory() && entry.name.startsWith("matrix-run-"))
      .map((entry) => path.join(evidenceBase, entry.name))
      .sort()
      .reverse()
    : [];
  const candidate = candidates.find((directory) => fs.existsSync(path.join(directory, "windows-reference-matrix.json")));
  if (!candidate) failMissingEvidence(`未找到运行目录：${evidenceBase}`);
  return candidate;
}

const runDirectory = chooseRunDirectory();
const runRelativeToEvidence = path.relative(evidenceBase, runDirectory);
assert(!runRelativeToEvidence.startsWith("..") && !path.isAbsolute(runRelativeToEvidence), "Windows 参考矩阵运行目录必须位于 candidate-windows-device-qa 内");
const recordPath = path.join(runDirectory, "windows-reference-matrix.json");
assert(fs.existsSync(recordPath), `缺少 Windows 参考矩阵记录：${recordPath}`);
const record = readJson(recordPath);
const buildManifest = readJson(buildManifestPath);
const expectedSegments = [
  "city-01", "city-02", "city-03", "city-04", "city-05", "city-06", "city-07", "city-08", "city-09", "city-10", "city-11",
  "office-01", "office-02", "office-03", "office-04", "office-05", "office-06", "office-07", "office-08", "office-09", "office-10",
];

assert(record.schema_version === 1, "Windows 参考矩阵记录 schema_version 必须为 1");
assert(record.status === "unverified_pending_visual_signoff", `Windows 参考矩阵记录状态不正确：${record.status}`);
assert(record.manual_visual_signoff === "pending", "Windows 参考矩阵不得自动写入视觉通过");
assert(record.asset_catalog_path === expectedAssetCatalogPath, "参考矩阵没有绑定包内候选资产目录");
assert(record.build?.path === buildManifest.build.path, "参考矩阵记录的 Windows 构建路径与清单不一致");
assert(record.build?.bytes === buildManifest.build.bytes, "参考矩阵记录的 Windows 构建字节数与清单不一致");
assert(record.build?.sha256 === buildManifest.build.sha256, "参考矩阵记录的 Windows 构建 SHA-256 与清单不一致");
assert(record.evidence_contract?.source?.sha256 === buildManifest.package.source_sha256, "参考矩阵源指纹与 Windows 构建清单不一致");
assert(record.evidence_contract?.source?.file_count === buildManifest.package.source_file_count, "参考矩阵源文件数与 Windows 构建清单不一致");
assert(record.evidence_contract?.candidate_package?.sha256 === buildManifest.package.sha256, "参考矩阵候选包指纹与 Windows 构建清单不一致");
assert(record.evidence_contract?.candidate_package?.file_count === buildManifest.package.file_count, "参考矩阵候选包文件数与 Windows 构建清单不一致");

const buildPath = path.resolve(root, buildManifest.build.path);
assert(fs.existsSync(buildPath), `缺少当前 Windows 构建：${buildManifest.build.path}`);
assert(fs.statSync(buildPath).size === buildManifest.build.bytes, "Windows 构建字节数已变化");
assert(sha256(buildPath) === buildManifest.build.sha256, "Windows 构建 SHA-256 已变化");

assert(Array.isArray(record.captures), "Windows 参考矩阵记录缺少 captures 数组");
assert(record.captures.length === expectedSegments.length, `参考矩阵记录条目数量不是 21：${record.captures.length}`);
const captures = new Map(record.captures.map((capture) => [capture.id, capture]));
assert(captures.size === expectedSegments.length, `参考矩阵截图数量不是 21：${captures.size}`);
for (const id of expectedSegments) {
  const capture = captures.get(id);
  assert(capture, `缺少参考矩阵分段：${id}`);
  assert(capture.visual_status === "unverified", `参考矩阵分段不得自动通过视觉：${id}`);
  assert(capture.asset_catalog_path === expectedAssetCatalogPath, `参考矩阵分段没有绑定包内候选资产目录：${id}`);
  const capturePath = path.resolve(runDirectory, capture.path);
  const relative = path.relative(runDirectory, capturePath);
  assert(!relative.startsWith("..") && !path.isAbsolute(relative), `参考矩阵截图路径越界：${id}`);
  assert(fs.existsSync(capturePath), `参考矩阵截图不存在：${id}`);
  const dimensions = readPngDimensions(capturePath);
  assert(dimensions.width === 1280 && dimensions.height === 720, `参考矩阵截图尺寸不是 1280x720：${id}`);
  assert(capture.width === dimensions.width && capture.height === dimensions.height, `参考矩阵尺寸记录不一致：${id}`);
  assert(capture.sha256 === sha256(capturePath), `参考矩阵截图 SHA-256 不一致：${id}`);
}

console.log(`Windows 参考矩阵证据验证通过：21/21；源指纹 ${buildManifest.package.source_sha256}/${buildManifest.package.source_file_count}；视觉状态保持 unverified`);
