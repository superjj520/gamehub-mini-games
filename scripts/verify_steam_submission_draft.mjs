import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const draftPath = path.join(root, "docs/steam-submission-package-draft.md");
const ownerInputsPath = path.join(root, "docs/release-owner-inputs.json");
const draft = fs.readFileSync(draftPath, "utf8");
const ownerInputs = JSON.parse(fs.readFileSync(ownerInputsPath, "utf8"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

assert(draft.includes("状态：`internal_draft / do_not_submit`"), "Steam 提交草案必须保持 do_not_submit");
assert(draft.includes("Steam Windows"), "Steam 提交草案缺少目标平台");
assert(draft.includes("新时代觉醒者"), "Steam 提交草案缺少产品名");
assert(draft.includes("release_allowed=false"), "Steam 提交草案缺少候选不可发布边界");
assert(draft.includes("当前源运行时 PNG、固定镜头、人工视觉签收和 Windows 目标设备证据齐全"), "Steam 截图门槛缺少当前源和目标设备要求");
assert(draft.includes("不使用参考视频"), "Steam 宣传视频缺少参考视频排除规则");
assert(draft.includes("21/21") && draft.includes("0/21"), "Steam 提交草案缺少行为和视觉当前状态");
assert(draft.includes("8 个仍为灰盒"), "Steam 提交草案缺少正式资产阻断");
assert(draft.includes("operating_entity") || draft.includes("运营主体"), "Steam 提交草案缺少运营主体阻断");
assert(draft.includes("release:preflight"), "Steam 提交草案缺少发布前置命令");
assert(draft.includes("../build/新时代觉醒者-原创边界候选-windows-qa.zip"), "Steam 提交草案缺少内部 QA 包链接");

for (const input of ownerInputs.inputs ?? []) {
  if (["support_email", "privacy_policy_url", "operating_entity", "steam_app_id"].includes(input.id)) {
    assert(input.status.startsWith("pending_"), `外部字段不应被草案验证器自动视为已确认：${input.id}`);
  }
}

console.log("Steam 提交草案验证通过：身份、禁止承诺、质量阻断和外部字段边界均已登记；状态保持 do_not_submit");
