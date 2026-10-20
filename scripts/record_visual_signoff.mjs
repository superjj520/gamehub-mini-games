import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const acceptancePath = "reference-evidence/acceptance-status.json";
const evidencePath = "reference-evidence/manifest.json";
const matrixPath = "reference-evidence/runtime-matrix/manifest.json";
const methods = new Set(["manual_frame_review", "manual_device_review"]);
const timestampPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;

function usage() {
  console.log("用法：node scripts/record_visual_signoff.mjs --segment <id> --reviewer <姓名或团队> --method <manual_frame_review|manual_device_review> --reviewed-at <UTC时间> [--write]");
}

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (token === "--write") {
      args.write = true;
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

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const args = parseArgs(process.argv.slice(2));
if (Object.keys(args).length === 0 || args.help) {
  usage();
  process.exit(args.help ? 0 : 2);
}

const segmentId = args.segment;
const reviewer = args.reviewer;
const method = args.method;
const reviewedAt = args["reviewed-at"];
assert(typeof segmentId === "string" && segmentId.length > 0, "必须提供 --segment");
assert(typeof reviewer === "string" && reviewer.trim().length > 0, "必须提供 --reviewer");
assert(methods.has(method), "--method 必须是 manual_frame_review 或 manual_device_review");
assert(typeof reviewedAt === "string" && timestampPattern.test(reviewedAt), "--reviewed-at 必须是带毫秒的 UTC 时间");
const reviewedTimestamp = Date.parse(reviewedAt);
assert(!Number.isNaN(reviewedTimestamp) && new Date(reviewedTimestamp).toISOString() === reviewedAt, "--reviewed-at 不是有效 UTC 时间");
assert(reviewedTimestamp <= Date.now(), "--reviewed-at 不能晚于当前时间");

const acceptance = JSON.parse(fs.readFileSync(acceptancePath, "utf8"));
const evidence = JSON.parse(fs.readFileSync(evidencePath, "utf8"));
const matrix = JSON.parse(fs.readFileSync(matrixPath, "utf8"));
const entry = acceptance.segments.find((candidate) => candidate.id === segmentId);
const capture = matrix.captures.find((candidate) => candidate.id === segmentId);
const referenceSegment = evidence.sources.flatMap((source) => source.segments ?? []).find((candidate) => candidate.id === segmentId);
assert(entry, `不存在参考验收分段：${segmentId}`);
assert(capture, `不存在运行时截图矩阵分段：${segmentId}`);
assert(referenceSegment, `不存在参考帧分段：${segmentId}`);
assert(entry.visual_status !== "passed", `分段已经是 passed，拒绝重复签收：${segmentId}`);
assert(capture.visual_status === "unverified", `运行时矩阵视觉状态不是 unverified：${segmentId}`);

const runtimeScreenshotPath = path.join("reference-evidence", capture.path);
assert(fs.existsSync(runtimeScreenshotPath), `运行时截图不存在：${runtimeScreenshotPath}`);
const screenshotSha256 = sha256(runtimeScreenshotPath);
assert(screenshotSha256 === capture.sha256, `运行时截图哈希不一致：${segmentId}`);

const nextEntry = {
  ...entry,
  visual_status: "passed",
  runtime_screenshot: capture.path,
  screenshot_sha256: capture.sha256,
  visual_review: {
    reviewer: reviewer.trim(),
    reviewed_at: reviewedAt,
    method,
    reference_sha256: referenceSegment.sha256,
    runtime_source_fingerprint: matrix.source_fingerprint,
    decision: "passed",
    findings: [],
  },
};

console.log(`视觉签收预览：${segmentId}；参考帧 ${referenceSegment.sha256}；运行时截图 ${capture.sha256}；源指纹 ${matrix.source_fingerprint}`);
if (!args.write) {
  console.log("未写入 acceptance-status.json；如已完成真实人工复核，需显式追加 --write。");
  process.exit(0);
}

acceptance.segments = acceptance.segments.map((candidate) => candidate.id === segmentId ? nextEntry : candidate);
fs.writeFileSync(acceptancePath, `${JSON.stringify(acceptance, null, 2)}\n`, "utf8");
console.log(`视觉签收已写入：${segmentId}；随后必须运行 node scripts/verify_reference_acceptance.mjs 和 npm run test:reference`);
