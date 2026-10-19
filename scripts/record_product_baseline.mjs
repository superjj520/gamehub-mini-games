import crypto from "node:crypto";
import fs from "node:fs";
import {scopeDefinitions} from "./release_scope.mjs";

const decisionPath = "docs/product-baseline-decision.json";
const requiredFields = [
  "schema_version",
  "status",
  "decision_owner",
  "confirmed_at",
  "product_name",
  "launch_platforms",
  "launch_devices",
  "launch_regions_and_languages",
  "launch_scope",
  "visual_direction",
  "copyright_boundary",
  "reference_media_commercial_rights",
  "commercialization",
  "budget_or_person_weeks",
  "target_launch_window"
];
const canonicalUtcTimestamp = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;
const isObject = (value) => value !== null && typeof value === "object" && !Array.isArray(value);
const isNonEmptyString = (value) => typeof value === "string" && value.trim().length > 0;
const isStringArray = (value) => Array.isArray(value) && value.every(isNonEmptyString);

function usage() {
  console.log([
    "用法：",
    "  npm run product:record -- --source <候选 JSON>",
    "  npm run product:record -- --source <候选 JSON> --write",
    "",
    "默认只预览，不修改 docs/product-baseline-decision.json。",
    "候选 JSON 必须明确填写 approved、平台、设备、范围、视觉方向、权利、商业化、预算和上线窗口。"
  ].join("\n"));
}

function parseArgs(argv) {
  const args = new Map();
  let write = false;
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--write") {
      write = true;
      continue;
    }
    if (arg === "--help" || arg === "-h") {
      usage();
      process.exit(0);
    }
    if (arg.startsWith("--")) {
      const value = argv[index + 1];
      if (!value || value.startsWith("--")) throw new Error(`参数 ${arg} 缺少值`);
      args.set(arg.slice(2), value);
      index += 1;
      continue;
    }
    throw new Error(`不支持的位置参数：${arg}`);
  }
  return {args, write};
}

function validateCandidate(candidate) {
  const errors = [];
  if (!isObject(candidate)) return ["候选产品基线不是 JSON 对象"];
  for (const field of requiredFields) {
    if (!Object.prototype.hasOwnProperty.call(candidate, field)) errors.push(`候选产品基线缺少字段：${field}`);
  }
  if (candidate.schema_version !== 1) errors.push("schema_version 必须为 1");
  if (!isNonEmptyString(candidate.decision_owner)) errors.push("decision_owner 不能为空");
  if (candidate.status !== "approved") errors.push("只有 status=approved 的完整候选才能写入产品基线");
  if (candidate.copyright_boundary !== "original_assets_only") errors.push("copyright_boundary 必须为 original_assets_only");
  if (!["unknown", "confirmed_allowed", "confirmed_denied"].includes(candidate.reference_media_commercial_rights)) {
    errors.push("reference_media_commercial_rights 不受支持");
  }
  for (const field of ["launch_platforms", "launch_devices", "launch_regions_and_languages", "launch_scope"]) {
    if (!isStringArray(candidate[field])) errors.push(`${field} 必须是非空字符串数组`);
  }
  if (!isNonEmptyString(candidate.product_name)) errors.push("product_name 不能为空");
  if (candidate.launch_platforms?.length === 0) errors.push("launch_platforms 不能为空");
  if (candidate.launch_devices?.length === 0) errors.push("launch_devices 不能为空");
  if (candidate.launch_regions_and_languages?.length === 0) errors.push("launch_regions_and_languages 不能为空");
  if (candidate.launch_scope?.length !== 1 || !Object.hasOwn(scopeDefinitions, candidate.launch_scope?.[0])) {
    errors.push("launch_scope 必须且只能是 office_vertical_slice 或 office_and_city");
  }
  if (!isNonEmptyString(candidate.visual_direction)) errors.push("visual_direction 不能为空");
  if (candidate.reference_media_commercial_rights === "unknown") errors.push("已确认基线不能保留未知参考媒体权利");
  if (!isNonEmptyString(candidate.commercialization)) errors.push("commercialization 不能为空");
  if (!(isNonEmptyString(candidate.budget_or_person_weeks) || (typeof candidate.budget_or_person_weeks === "number" && Number.isFinite(candidate.budget_or_person_weeks) && candidate.budget_or_person_weeks > 0))) {
    errors.push("budget_or_person_weeks 必须是正数或非空说明");
  }
  if (!isNonEmptyString(candidate.target_launch_window)) errors.push("target_launch_window 不能为空");
  if (typeof candidate.confirmed_at !== "string" || !canonicalUtcTimestamp.test(candidate.confirmed_at) || Number.isNaN(Date.parse(candidate.confirmed_at)) || new Date(candidate.confirmed_at).toISOString() !== candidate.confirmed_at || Date.parse(candidate.confirmed_at) > Date.now()) {
    errors.push("confirmed_at 必须是有效且不晚于当前时间的 UTC 时间");
  }
  return errors;
}

const {args, write} = parseArgs(process.argv.slice(2));
const sourcePath = args.get("source");
if (!sourcePath) {
  usage();
  process.exit(1);
}

let candidate;
try {
  candidate = JSON.parse(fs.readFileSync(sourcePath, "utf8"));
} catch (error) {
  console.error(`无法读取候选产品基线：${error.message}`);
  process.exit(1);
}

const errors = validateCandidate(candidate);
if (errors.length > 0) {
  console.error(`产品定稿候选验证阻断：${errors.length} 项`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

const previousBytes = fs.readFileSync(decisionPath);
const previousSha256 = crypto.createHash("sha256").update(previousBytes).digest("hex");
const normalized = {...candidate, notes: candidate.notes || "已确认产品基线；最终资产、目标平台构建和商店提交仍需分别通过发布门禁"};
console.log(`产品定稿候选验证通过：${normalized.product_name}；范围 ${normalized.launch_scope[0]}；前一版基线 SHA-256 ${previousSha256}`);
if (!write) {
  console.log("预览模式：未修改产品基线。若确认写入，请重新执行并显式添加 --write。");
  console.log(JSON.stringify(normalized, null, 2));
  process.exit(0);
}

fs.writeFileSync(decisionPath, `${JSON.stringify(normalized, null, 2)}\n`, "utf8");
const nextSha256 = crypto.createHash("sha256").update(fs.readFileSync(decisionPath)).digest("hex");
console.log(`产品基线已写入：${decisionPath}；新 SHA-256 ${nextSha256}`);
