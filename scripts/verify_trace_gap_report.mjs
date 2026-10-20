import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const reportPath = path.join(root, "reference-evidence", "runtime-matrix", "trace-gap-report.json");
const matrixPath = path.join(root, "reference-evidence", "runtime-matrix", "manifest.json");

const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
const matrix = JSON.parse(fs.readFileSync(matrixPath, "utf8"));
const expectedSegmentCount = matrix.captures.length;

if (report.status !== "complete") {
  throw new Error(`运行时事件缺口报告不是 complete：${report.status}`);
}
if (report.gap_count !== 0 || report.gaps.length !== 0) {
  throw new Error(`运行时事件仍有缺口：${report.gap_count}`);
}
if (report.segment_count !== expectedSegmentCount) {
  throw new Error(`运行时事件分段数量不一致：报告 ${report.segment_count}，矩阵 ${expectedSegmentCount}`);
}

console.log(`运行时事件缺口门禁通过：${report.segment_count} 个分段，0 个缺口`);
