import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const report = JSON.parse(fs.readFileSync(path.join(root, "docs/requirement-traceability.json"), "utf8"));
const releaseManifest = JSON.parse(fs.readFileSync(path.join(root, "docs/release-manifest.json"), "utf8"));
const source = releaseManifest.source;
const failures = [];

if (report.source?.sha256 !== source.sha256 || Number(report.source?.file_count) !== Number(source.file_count)) {
  failures.push("追踪矩阵与当前发布清单源指纹不一致");
}
if (!Array.isArray(report.requirements) || report.requirements.length < 10) failures.push("要求条目数量不足");
for (const item of report.requirements ?? []) {
  if (!item.id || !item.label || !item.status || !Array.isArray(item.direct_evidence) || !item.acceptance_gate) failures.push(`${item.id ?? "未知条目"} 缺少结构化字段`);
  for (const evidence of item.direct_evidence ?? []) {
    if (!fs.existsSync(path.join(root, evidence))) failures.push(`${item.id} 缺少证据文件：${evidence}`);
  }
}
if (report.objective_status !== "incomplete" && report.objective_status !== "complete_candidate") failures.push(`未知目标状态：${report.objective_status}`);

if (failures.length) {
  console.error("目标要求追踪矩阵验证失败：");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}
console.log(`目标要求追踪矩阵验证通过：${report.requirements.length} 项；当前源 ${source.sha256}/${source.file_count}`);
