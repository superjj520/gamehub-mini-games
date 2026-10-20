import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const acceptancePath = path.join(root, "reference-evidence/acceptance-status.json");
const evidencePath = path.join(root, "reference-evidence/manifest.json");
const matrixPath = path.join(root, "reference-evidence/runtime-matrix/manifest.json");
const methods = new Set(["manual_frame_review", "manual_device_review"]);
const decisions = new Set(["unverified", "passed", "rejected"]);
const timestampPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;

function usage() {
  console.log("用法：node scripts/apply_visual_review_record.mjs --file <visual-review-record.json> [--write] [--allow-reset]");
}

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (token === "--write" || token === "--allow-reset") {
      args[token.slice(2)] = true;
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

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function validateUtc(value, field) {
  assert(typeof value === "string" && timestampPattern.test(value), `${field} 必须是带毫秒的 UTC 时间`);
  const timestamp = Date.parse(value);
  assert(!Number.isNaN(timestamp) && new Date(timestamp).toISOString() === value, `${field} 不是有效 UTC 时间`);
  assert(timestamp <= Date.now(), `${field} 不能晚于当前时间`);
}

const args = parseArgs(process.argv.slice(2));
if (!args.file || args.help) {
  usage();
  process.exit(args.help ? 0 : 2);
}

const recordPath = path.resolve(args.file);
assert(fs.existsSync(recordPath), `复核记录不存在：${recordPath}`);
const record = readJson(recordPath);
const acceptance = readJson(acceptancePath);
const evidence = readJson(evidencePath);
const matrix = readJson(matrixPath);

assert(record.schema_version === 1, "复核记录 schema_version 必须为 1");
assert(typeof record.reviewer === "string" && record.reviewer.trim().length > 0, "复核记录缺少 reviewer");
assert(methods.has(record.method), "复核记录 method 必须是 manual_frame_review 或 manual_device_review");
validateUtc(record.reviewed_at, "reviewed_at");
assert(record.runtime_source_fingerprint === matrix.source_fingerprint, "复核记录与当前运行时源指纹不一致，请重新导出看板记录");
assert(Array.isArray(record.segments) && record.segments.length === matrix.captures.length, "复核记录必须覆盖全部运行时矩阵分段");

const acceptanceById = new Map(acceptance.segments.map((entry) => [entry.id, entry]));
const captureById = new Map(matrix.captures.map((capture) => [capture.id, capture]));
const referenceById = new Map(evidence.sources.flatMap((source) => source.segments ?? []).map((segment) => [segment.id, segment]));
const seen = new Set();
const nextById = new Map();

for (const review of record.segments) {
  assert(review && typeof review.id === "string" && !seen.has(review.id), `复核记录分段 id 缺失或重复：${review?.id ?? "<empty>"}`);
  seen.add(review.id);
  assert(decisions.has(review.decision), `复核结论不受支持：${review.id}/${review.decision}`);
  assert(Array.isArray(review.findings), `复核差异必须是数组：${review.id}`);
  const entry = acceptanceById.get(review.id);
  const capture = captureById.get(review.id);
  const reference = referenceById.get(review.id);
  assert(entry && capture && reference, `复核记录找不到对应证据分段：${review.id}`);
  const runtimePath = path.join(root, "reference-evidence", capture.path);
  assert(fs.existsSync(runtimePath), `运行时截图不存在：${review.id}`);
  assert(sha256(runtimePath) === capture.sha256, `运行时截图哈希不一致：${review.id}`);

  if (review.decision === "unverified") {
    assert(entry.visual_status !== "passed" || args["allow-reset"], `不能把已通过分段静默降回未复核：${review.id}；如确需返工请追加 --allow-reset`);
    nextById.set(review.id, entry);
    continue;
  }

  if (review.decision === "rejected") {
    assert(review.findings.length > 0, `不通过分段必须填写差异与返工项：${review.id}`);
    assert(entry.visual_status !== "passed" || args["allow-reset"], `已通过分段要改为不通过必须追加 --allow-reset：${review.id}`);
    nextById.set(review.id, {
      ...entry,
      visual_status: "unverified",
      visual_review: {
        reviewer: record.reviewer.trim(),
        reviewed_at: record.reviewed_at,
        method: record.method,
        reference_sha256: reference.sha256,
        runtime_source_fingerprint: matrix.source_fingerprint,
        decision: "rejected",
        findings: review.findings,
      },
    });
    continue;
  }

  assert(review.findings.length === 0, `通过分段不能保留差异或返工项：${review.id}`);
  assert(capture.visual_status === "unverified", `运行时矩阵视觉状态必须保持 unverified：${review.id}`);
  assert(entry.visual_status !== "passed", `分段已经是 passed，拒绝重复签收：${review.id}`);
  nextById.set(review.id, {
    ...entry,
    visual_status: "passed",
    runtime_screenshot: capture.path,
    screenshot_sha256: capture.sha256,
    visual_review: {
      reviewer: record.reviewer.trim(),
      reviewed_at: record.reviewed_at,
      method: record.method,
      reference_sha256: reference.sha256,
      runtime_source_fingerprint: matrix.source_fingerprint,
      decision: "passed",
      findings: [],
    },
  });
}

assert(seen.size === acceptance.segments.length && acceptance.segments.every((entry) => seen.has(entry.id)), "复核记录必须覆盖 acceptance-status.json 的全部分段，不能漏项");
const nextAcceptance = {
  ...acceptance,
  segments: acceptance.segments.map((entry) => nextById.get(entry.id)),
};
const passed = nextAcceptance.segments.filter((entry) => entry.visual_status === "passed").length;
const rejected = nextAcceptance.segments.filter((entry) => entry.visual_review?.decision === "rejected").length;
console.log(`视觉复核记录校验通过：${nextAcceptance.segments.length} 个分段；通过 ${passed}；不通过 ${rejected}；源指纹 ${matrix.source_fingerprint}`);

if (!args.write) {
  console.log("未写入 acceptance-status.json；真实人工复核完成后再追加 --write。 ");
  process.exit(0);
}

fs.writeFileSync(acceptancePath, `${JSON.stringify(nextAcceptance, null, 2)}\n`, "utf8");
console.log("视觉复核记录已写入 acceptance-status.json；随后必须运行 npm run verify:visual-matrix 和 npm run test:reference");
