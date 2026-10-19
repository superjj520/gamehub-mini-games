import fs from "node:fs";
import path from "node:path";
import {spawnSync} from "node:child_process";

const root = process.cwd();
const outputPath = path.join(root, "reference-evidence", "candidate-runtime", "full-game-qa.json");
const npmBinary = process.platform === "win32" ? "npm.cmd" : "npm";

function sourceFingerprint() {
  const result = spawnSync(process.execPath, ["scripts/source_fingerprint.mjs"], {
    cwd: root,
    encoding: "utf8",
  });
  if (result.status !== 0) {
    throw new Error(`读取源码指纹失败：${result.stderr || result.stdout}`);
  }
  return String(result.stdout || "").trim();
}

const sourceBefore = sourceFingerprint();
const checks = [
  ["verify:visual-concept-manifest", "视觉稿与运行时资产绑定清单"],
  ["test:behavior:current", "当前参考视频 21 段行为回放"],
  ["test:expanded-behavior", "扩展内容行为回放"],
  ["test:campaign-continuity", "办公室到城市的任务连续性"],
  ["test:fun-loop", "城市冲突、逃脱、奖励闭环"],
  ["test:combined-office-candidates", "办公室候选隔离运行时"],
  ["verify:candidate:office:configuration", "办公室候选结构配置"],
  ["verify:candidate:city:configuration", "城市候选结构配置"],
  ["verify:candidate:full:launch", "完整候选启动器"],
  ["verify:candidate:windows:all", "三套 Windows 候选包绑定"],
  ["verify:candidate:mac:original-only", "Mac 原创边界候选启动与入口"],
  ["verify:candidate:windows:qa", "完整候选 Windows QA 包清单"],
  ["verify:candidate:windows:qa:original", "原创角色 Windows QA 包清单"],
  ["verify:candidate:windows:qa:original-only", "原创边界 Windows QA 包清单"],
  ["verify:windows:capture-script-contract", "Windows 视觉采集脚本合同"],
  ["verify:windows:complete-qa-contract", "Windows 完整 QA 编排合同"],
  ["verify:asset-candidate-adoption", "候选资产接入证据"],
  ["verify:asset-handoffs", "资产交付边界"],
  ["candidate:p0:ledger", "刷新 P0 候选质量台账"],
  ["verify:candidate:p0:ledger", "P0 候选质量台账"],
  ["verify:evidence-binding", "证据与当前源码绑定"],
];

const results = [];
let passed = true;

// 办公室配置验证会为 4 套镜头和 10 个状态逐个启动 Godot；统一使用 240 秒
// 会把仍在运行的验证误判成失败。这里按真实成本给长流程单独留出时间，超时
// 仍然是失败，但不会把“验证尚未结束”伪装成“验证失败”。
const timeoutByScript = new Map([
  ["verify:candidate:office:configuration", 1800000],
  ["verify:candidate:city:configuration", 240000],
  ["verify:candidate:windows:all", 300000],
]);

for (const [script, label] of checks) {
  const startedAt = Date.now();
  const result = spawnSync(npmBinary, ["run", script], {
    cwd: root,
    encoding: "utf8",
    timeout: timeoutByScript.get(script) ?? 240000,
    stdio: ["ignore", "pipe", "pipe"],
  });
  const output = `${result.stdout || ""}${result.stderr || ""}`;
  const after = sourceFingerprint();
  const sourceStable = after === sourceBefore;
  const commandPassed = result.status === 0 && !result.error;
  const status = commandPassed && sourceStable ? "passed" : "failed";
  if (status !== "passed") passed = false;
  results.push({
    script,
    label,
    status,
    exit_code: result.status,
    duration_ms: Date.now() - startedAt,
    source_before: sourceBefore,
    source_after: after,
    source_stable: sourceStable,
    output_tail: output.slice(-2500),
    error: result.error?.message ?? null,
  });
  if (status !== "passed") break;
}

const match = sourceBefore.match(/^([0-9a-f]{64}) files=(\d+)$/);
const report = {
  schema_version: 1,
  generated_at: new Date().toISOString(),
  status: passed ? "full_game_candidate_qa_passed" : "full_game_candidate_qa_failed",
  scope: "office_and_city_candidate",
  source_fingerprint: match?.[1] ?? null,
  source_file_count: Number(match?.[2] ?? 0),
  behavior_status: passed ? "verified" : "failed",
  visual_status: "unverified",
  release_allowed: false,
  policy: "本报告只证明办公室与城市候选的串行行为、配置、资产边界和证据绑定；不生成视觉 PNG，不替代可见窗口、Windows 真机或人工视觉签收，也不改变正式首发范围。",
  checks: results,
};

fs.mkdirSync(path.dirname(outputPath), {recursive: true});
fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`, "utf8");

if (!passed) {
  const failed = results.find((entry) => entry.status !== "passed");
  throw new Error(`完整候选 QA 失败：${failed?.label ?? "未知步骤"}；报告已写入 ${outputPath}`);
}

console.log(`办公室 + 城市完整候选 QA 通过：${results.length}/${checks.length}；源码 ${sourceBefore}；视觉仍为 unverified；报告 ${outputPath}`);
