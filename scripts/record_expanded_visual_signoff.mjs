import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const matrixPath = path.join(root, "docs/expanded-visual-acceptance-matrix.json");
const manifestPath = path.join(root, "reference-evidence/expanded-runtime-matrix/manifest.json");
const methods = new Set(["manual_frame_review", "manual_device_review"]);
const decisions = new Set(["passed", "rejected"]);
const timestampPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;

function usage() {
  console.log("用法：node scripts/record_expanded_visual_signoff.mjs --id <扩展项> --reviewer <姓名或团队> --method <manual_frame_review|manual_device_review> --reviewed-at <UTC时间> --decision <passed|rejected> [--device <设备>] [--finding <差异>] [--write] [--allow-reset]");
}

function parseArgs(argv) {
  const args = { findings: [] };
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (token === "--write" || token === "--allow-reset") {
      args[token.slice(2)] = true;
      continue;
    }
    if (!token.startsWith("--")) throw new Error(`未知参数：${token}`);
    const value = argv[index + 1];
    if (!value || value.startsWith("--")) throw new Error(`参数缺少值：${token}`);
    if (token === "--finding") args.findings.push(value);
    else args[token.slice(2)] = value;
    index += 1;
  }
  return args;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function validateUtc(value) {
  assert(typeof value === "string" && timestampPattern.test(value), "--reviewed-at 必须是带毫秒的 UTC 时间");
  const timestamp = Date.parse(value);
  assert(!Number.isNaN(timestamp) && new Date(timestamp).toISOString() === value, "--reviewed-at 不是有效 UTC 时间");
  assert(timestamp <= Date.now(), "--reviewed-at 不能晚于当前时间");
}

const args = parseArgs(process.argv.slice(2));
if (args.help || Object.keys(args).length === 1) {
  usage();
  process.exit(args.help ? 0 : 2);
}

assert(typeof args.id === "string" && args.id.trim().length > 0, "必须提供 --id");
assert(typeof args.reviewer === "string" && args.reviewer.trim().length > 0, "必须提供 --reviewer");
assert(methods.has(args.method), "--method 必须是 manual_frame_review 或 manual_device_review");
assert(decisions.has(args.decision), "--decision 必须是 passed 或 rejected");
validateUtc(args["reviewed-at"]);
if (args.method === "manual_device_review") {
  assert(typeof args.device === "string" && args.device.trim().length > 0, "manual_device_review 必须提供 --device");
}
if (args.decision === "passed") {
  assert(args.findings.length === 0, "通过的扩展视觉项不能保留差异或返工项");
} else {
  assert(args.findings.length > 0, "不通过的扩展视觉项必须至少提供一个 --finding");
}

const matrix = JSON.parse(fs.readFileSync(matrixPath, "utf8"));
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
assert(matrix.status === "supplemental_scope_proposed", "扩展视觉矩阵状态不允许签收");
assert(manifest.source_fingerprint === matrix.source_fingerprint, "扩展视觉矩阵与截图清单源指纹不一致，请先重新绑定当前图形采集");
const entry = matrix.entries.find((candidate) => candidate.id === args.id);
const capture = (manifest.captures ?? []).find((candidate) => candidate.id === args.id);
assert(entry, `不存在扩展视觉项：${args.id}`);
assert(capture, `扩展视觉项没有对应运行时截图：${args.id}`);
assert(capture.visual_status === "unverified", `扩展运行时截图状态不是 unverified：${args.id}`);
assert(entry.visual_status !== "passed" || args["allow-reset"], `扩展视觉项已经通过，拒绝重复覆盖：${args.id}`);

const screenshotPath = path.join(root, capture.path);
assert(fs.existsSync(screenshotPath), `扩展运行时截图不存在：${capture.path}`);
const screenshotSha256 = sha256(screenshotPath);
assert(screenshotSha256 === capture.sha256, `扩展运行时截图哈希不一致：${args.id}`);

const review = {
  reviewer: args.reviewer.trim(),
  reviewed_at: args["reviewed-at"],
  method: args.method,
  device: args.device?.trim() || null,
  runtime_source_fingerprint: matrix.source_fingerprint,
  runtime_screenshot_sha256: capture.sha256,
  decision: args.decision,
  findings: args.findings,
};
const nextEntry = {
  ...entry,
  visual_status: args.decision === "passed" ? "passed" : "unverified",
  review,
};

console.log(`扩展视觉签收预览：${args.id}；结论 ${args.decision}；截图 ${capture.sha256}；源指纹 ${matrix.source_fingerprint}`);
if (!args.write) {
  console.log("未写入扩展视觉矩阵；真实完成人工复核后，需显式追加 --write。");
  process.exit(0);
}

matrix.entries = matrix.entries.map((candidate) => candidate.id === args.id ? nextEntry : candidate);
fs.writeFileSync(matrixPath, `${JSON.stringify(matrix, null, 2)}\n`, "utf8");
console.log(`扩展视觉签收已写入：${args.id}；随后必须运行 npm run verify:visual-expansion`);
