import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const filePath = path.join(root, "docs", "release-owner-inputs.json");
const document = JSON.parse(fs.readFileSync(filePath, "utf8"));
const expectedIds = [
  "support_email",
  "privacy_policy_url",
  "steam_app_id",
  "age_rating_submission",
  "public_test_date",
  "operating_entity",
];

function fail(message) {
  throw new Error(`发布负责人输入清单校验失败：${message}`);
}

if (document.schema_version !== 1) fail("schema_version 不是 1");
if (document.status !== "pending_owner_inputs") fail(`顶层状态不应为 ${document.status}`);
if (!Array.isArray(document.inputs)) fail("inputs 不是数组");

const actualIds = document.inputs.map((input) => input.id);
if (new Set(actualIds).size !== actualIds.length) fail("存在重复字段 id");
if (JSON.stringify(actualIds) !== JSON.stringify(expectedIds)) {
  fail(`字段集合或顺序不符合约定：${actualIds.join(", ")}`);
}

for (const input of document.inputs) {
  if (!input.label || input.cannot_infer !== true || !Array.isArray(input.required_before) || input.required_before.length === 0) {
    fail(`${input.id} 缺少 label、cannot_infer 或 required_before`);
  }
  if (!String(input.status).startsWith("pending_") && input.status !== "confirmed") {
    fail(`${input.id} 的状态无效：${input.status}`);
  }
  if (input.status.startsWith("pending_") && input.value !== null) {
    fail(`${input.id} 仍是待确认状态，但 value 不是 null`);
  }
  if (input.status === "confirmed" && String(input.value ?? "").trim().length === 0) {
    fail(`${input.id} 标记为 confirmed，但 value 为空`);
  }
}

const pending = document.inputs.filter((input) => input.status !== "confirmed").map((input) => input.id);
console.log(`发布负责人输入清单结构通过：${document.inputs.length} 项；待确认 ${pending.length} 项；未使用默认值或临时值`);

if (process.argv.includes("--strict") && pending.length > 0) {
  console.error(`严格发布负责人门禁阻断：${pending.join(", ")}`);
  process.exit(1);
}
