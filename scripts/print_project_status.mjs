import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";

const root = process.cwd();

function readJson(relativePath) {
  const absolutePath = path.join(root, relativePath);
  return JSON.parse(fs.readFileSync(absolutePath, "utf8"));
}

function currentSource() {
  const output = execFileSync(process.execPath, ["scripts/source_fingerprint.mjs"], {cwd: root, encoding: "utf8"}).trim();
  const match = output.match(/^([0-9a-f]{64}) files=(\d+)$/);
  if (!match) throw new Error(`源码指纹格式无效：${output}`);
  return `${match[1]} / ${match[2]}`;
}

const objective = readJson("docs/objective-completion-status.json");
const readiness = readJson("docs/readiness-report.json");
const dashboard = readJson("docs/release-blocker-dashboard.json");
const graphical = readJson("reference-evidence/candidate-runtime/graphical-capture-readiness.json");
const expandedBehavior = readJson("reference-evidence/expanded-runtime-matrix/behavior-evidence.json");
const counts = objective.counts ?? {};

console.log("《新时代觉醒者》研发状态");
console.log(`源码：${currentSource()}`);
console.log(`行为：${counts.behavior_passed ?? 0}/${counts.segments ?? 0}；扩展行为：${expandedBehavior.counts?.passed ?? 0}/${expandedBehavior.counts?.total ?? 0}`);
console.log(`正式视觉：${counts.visual_passed ?? 0}/${counts.visual_total ?? 0}；扩展视觉：${counts.expanded_visual_passed ?? 0}/${counts.expanded_visual_total ?? 0}；正式资产灰盒：${counts.graybox_assets ?? 0}；候选资产：${counts.candidate_assets ?? 0}`);
console.log(`图形准备度：${graphical.status}；当前源 PNG：${graphical.summary?.current_matrix_pngs ?? 0}/${graphical.summary?.required_matrix_pngs ?? 0}`);
console.log(`发布状态：${readiness.status ?? objective.status}；阻断看板：${dashboard.status}；可发布：否`);
console.log(`自动化阻断：${(objective.blockers ?? []).join("、") || "无"}`);
const currentPngs = Number(graphical.summary?.current_matrix_pngs ?? 0);
const requiredPngs = Number(graphical.summary?.required_matrix_pngs ?? 0);
const nextStep = currentPngs === requiredPngs && requiredPngs > 0
  ? "逐帧视觉签收、扩展视觉采集与签收、最终资产权利、Windows 目标设备和 Steam 负责人资料。"
  : "真实图形窗口或 Windows 目标设备采集、逐帧视觉签收、最终资产权利和 Steam 负责人资料。";
console.log(`外部下一步：${nextStep}`);
