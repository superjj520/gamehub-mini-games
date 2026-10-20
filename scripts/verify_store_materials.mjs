import fs from "node:fs";
import path from "node:path";

const root = path.resolve(".");
const requiredFiles = [
  "docs/store-metadata-draft.md",
  "docs/privacy-policy-draft-zh-CN.md",
  "docs/support-and-rollback-plan.md",
  "docs/age-rating-questionnaire-zh-CN.md",
  "docs/release-owner-inputs.json",
];
const unresolvedMarkers = ["待确认", "待定", "尚未", "不得直接提交"];
const missing = requiredFiles.filter((filePath) => !fs.existsSync(path.join(root, filePath)));
if (missing.length > 0) throw new Error(`商店材料缺少文件：${missing.join(", ")}`);

const unresolved = [];
for (const filePath of requiredFiles) {
  const text = fs.readFileSync(path.join(root, filePath), "utf8");
  for (const marker of unresolvedMarkers) {
    if (text.includes(marker)) unresolved.push(`${filePath}：${marker}`);
  }
}

const ownerInputsPath = path.join(root, "docs/release-owner-inputs.json");
const ownerInputs = JSON.parse(fs.readFileSync(ownerInputsPath, "utf8"));
if (ownerInputs.status !== "pending_owner_inputs" || !Array.isArray(ownerInputs.inputs) || ownerInputs.inputs.length === 0) {
  throw new Error("发行负责人输入清单状态或 inputs 结构错误");
}
for (const input of ownerInputs.inputs) {
  if (!input.id || !input.label || input.status === undefined || input.cannot_infer !== true) {
    throw new Error(`发行负责人输入清单字段不完整：${input.id ?? "未命名"}`);
  }
  if (input.status !== "confirmed") unresolved.push(`docs/release-owner-inputs.json：${input.id} 未确认`);
}

const strict = process.argv.includes("--strict");
if (strict && unresolved.length > 0) {
  console.error(`严格商店材料门禁阻断：${unresolved.length} 个待定字段`);
  for (const item of unresolved) console.error(`- ${item}`);
  process.exit(1);
}
console.log(`商店材料草案结构通过：${requiredFiles.length} 个文件；待定字段 ${unresolved.length} 个；严格模式 ${strict ? "阻断" : "未启用"}`);
