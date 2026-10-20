import fs from "node:fs";
import path from "node:path";
import { buildTraceGapReport } from "./trace_gap_report.mjs";

const root = process.cwd();
const tracePath = path.join(root, "reference-evidence", "runtime-matrix", "trace-evidence.json");
const acceptancePath = path.join(root, "reference-evidence", "acceptance-status.json");
const matrixPath = path.join(root, "reference-evidence", "runtime-matrix", "manifest.json");
const outputPath = path.join(root, "reference-evidence", "runtime-matrix", "trace-gap-report.json");
const traceManifest = JSON.parse(fs.readFileSync(tracePath, "utf8"));
const acceptance = JSON.parse(fs.readFileSync(acceptancePath, "utf8"));
const matrix = JSON.parse(fs.readFileSync(matrixPath, "utf8"));
const gapReport = buildTraceGapReport(traceManifest, acceptance, matrix);
fs.writeFileSync(outputPath, `${JSON.stringify(gapReport, null, 2)}\n`, "utf8");
console.log(`运行时事件缺口报告已生成：${gapReport.segment_count} 个分段，${gapReport.gap_count} 个缺口`);
