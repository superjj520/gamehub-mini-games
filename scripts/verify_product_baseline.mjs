import fs from "node:fs";
import {scopeDefinitions} from "./release_scope.mjs";

const decisionPath = "docs/product-baseline-decision.json";
const decision = JSON.parse(fs.readFileSync(decisionPath, "utf8"));
const errors = [];
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
const isObject = (value) => value !== null && typeof value === "object" && !Array.isArray(value);
const isNonEmptyString = (value) => typeof value === "string" && value.trim().length > 0;
const isStringArray = (value) => Array.isArray(value) && value.every(isNonEmptyString);
const canonicalUtcTimestamp = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;
const supportedLaunchScopes = new Set(Object.keys(scopeDefinitions));

if (!isObject(decision)) errors.push("产品基线不是 JSON 对象");
for (const field of requiredFields) {
  if (!Object.prototype.hasOwnProperty.call(decision, field)) errors.push(`产品基线缺少字段：${field}`);
}
if (decision.schema_version !== 1) errors.push("产品基线 schema_version 必须为 1");
if (!isNonEmptyString(decision.decision_owner)) errors.push("产品基线 decision_owner 不能为空");
if (!new Set(["pending_user_confirmation", "approved"]).has(decision.status)) {
  errors.push("产品基线 status 不受支持");
}
if (decision.copyright_boundary !== "original_assets_only") {
  errors.push("产品基线 copyright_boundary 必须为 original_assets_only");
}
if (!new Set(["unknown", "confirmed_allowed", "confirmed_denied"]).has(decision.reference_media_commercial_rights)) {
  errors.push("参考媒体商业权利字段不受支持");
}
for (const field of ["launch_platforms", "launch_devices", "launch_regions_and_languages", "launch_scope"]) {
  if (!isStringArray(decision[field])) errors.push(`产品基线 ${field} 必须是字符串数组`);
}

if (decision.status === "pending_user_confirmation") {
  if (decision.confirmed_at !== null) errors.push("待确认产品基线 confirmed_at 必须为空");
} else if (decision.status === "approved") {
  if (!isNonEmptyString(decision.product_name)) errors.push("已确认产品基线 product_name 不能为空");
  if (decision.launch_platforms.length === 0) errors.push("已确认产品基线首发平台不能为空");
  if (decision.launch_devices.length === 0) errors.push("已确认产品基线首发设备不能为空");
  if (decision.launch_regions_and_languages.length === 0) errors.push("已确认产品基线地区与语言不能为空");
  if (decision.launch_scope.length === 0) errors.push("已确认产品基线首发范围不能为空");
  if (decision.launch_scope.length !== 1 || !supportedLaunchScopes.has(decision.launch_scope[0])) {
    errors.push("已确认产品基线 launch_scope 必须是 office_vertical_slice 或 office_and_city，且只能选择一个");
  }
  if (!isNonEmptyString(decision.visual_direction)) errors.push("已确认产品基线 visual_direction 不能为空");
  if (decision.reference_media_commercial_rights === "unknown") errors.push("已确认产品基线不能保留未知参考媒体权利");
  if (!isNonEmptyString(decision.commercialization)) errors.push("已确认产品基线 commercialization 不能为空");
  if (!(isNonEmptyString(decision.budget_or_person_weeks) || (typeof decision.budget_or_person_weeks === "number" && Number.isFinite(decision.budget_or_person_weeks) && decision.budget_or_person_weeks > 0))) {
    errors.push("已确认产品基线 budget_or_person_weeks 无效");
  }
  if (!isNonEmptyString(decision.target_launch_window)) errors.push("已确认产品基线 target_launch_window 不能为空");
  if (typeof decision.confirmed_at !== "string" || !canonicalUtcTimestamp.test(decision.confirmed_at) || Number.isNaN(Date.parse(decision.confirmed_at)) || new Date(decision.confirmed_at).toISOString() !== decision.confirmed_at || Date.parse(decision.confirmed_at) > Date.now()) {
    errors.push("已确认产品基线 confirmed_at 必须是有效的 UTC 时间");
  }
}

if (errors.length > 0) {
  console.error(`产品基线格式验证阻断：${errors.length} 项`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`产品基线格式验证通过：${decision.status}`);
