import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";

const root = process.cwd();
const reportPath = path.join(root, "reference-evidence", "candidate-runtime", "local-candidate-qa.json");
const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
const sourceOutput = execFileSync(process.execPath, ["scripts/source_fingerprint.mjs"], {cwd: root, encoding: "utf8"}).trim();
const sourceMatch = sourceOutput.match(/^([0-9a-f]{64}) files=(\d+)$/);
if (!sourceMatch) throw new Error(`当前源码指纹格式无效：${sourceOutput}`);
if (report.schema_version !== 1 || report.status !== "local_candidate_qa_passed") {
  throw new Error(`本地候选 QA 报告状态不正确：${report.status}`);
}
if (report.visual_status !== "unverified" || report.release_allowed !== false) {
  throw new Error("本地候选 QA 报告不得绕过视觉或发布门禁");
}
if (report.source_fingerprint !== sourceMatch[1] || report.source_file_count !== Number(sourceMatch[2])) {
  throw new Error(`本地候选 QA 报告未绑定当前源码：报告 ${report.source_fingerprint}/${report.source_file_count}；实际 ${sourceOutput}`);
}
if (!Array.isArray(report.checks) || report.checks.length !== 10 || report.checks.some((check) => check.status !== "passed" || check.source_stable !== true)) {
  throw new Error("本地候选 QA 报告必须包含 10 个串行通过且源指纹稳定的检查");
}
console.log(`本地候选 QA 报告验证通过：${report.checks.length}/10；源码 ${sourceMatch[1]} / ${sourceMatch[2]}；视觉仍为 unverified`);
