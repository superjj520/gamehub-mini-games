import fs from "node:fs";
import path from "node:path";
import {spawnSync} from "node:child_process";

const root = process.cwd();
const outputPath = path.join(root, "reference-evidence", "candidate-runtime", "local-candidate-qa.json");
const npmBinary = process.platform === "win32" ? "npm.cmd" : "npm";

function sourceFingerprint() {
  const result = spawnSync(process.execPath, ["scripts/source_fingerprint.mjs"], {
    cwd: root,
    encoding: "utf8",
  });
  if (result.status !== 0) throw new Error(`读取源码指纹失败：${result.stderr || result.stdout}`);
  return String(result.stdout || "").trim();
}

const sourceBefore = sourceFingerprint();
const checks = [
  ["test:behavior:current", "当前 21 段行为回放"],
  ["test:expanded-behavior", "扩展行为回放"],
  ["test:combined-office-candidates", "办公室候选隔离运行时"],
  ["verify:candidate:office:configuration", "办公室候选结构配置"],
  ["verify:candidate:city:configuration", "城市候选结构配置"],
  ["verify:makehuman:vehicle-seated-contact", "载具座椅与车把接触"],
  ["verify:candidate:full:launch", "完整候选启动器"],
  ["verify:asset-candidate-adoption", "候选资产接入证据"],
  ["verify:candidate:p0:ledger", "P0 候选质量台账"],
  ["verify:evidence-binding", "证据绑定一致性"],
];

const results = [];
let passed = true;
// 办公室 10 段无图形配置探针会为每个段落启动一次隔离 Godot 进程；
// 在当前 macOS 环境中完整一轮可能超过三分钟，但这不是失败。保留
// 单项硬超时，同时给实际的候选 QA 留出足够时间，避免把慢机器误报为逻辑失败。
const checkTimeoutMs = 420000;
for (const [script, label] of checks) {
  const startedAt = Date.now();
  const result = spawnSync(npmBinary, ["run", script], {
    cwd: root,
    encoding: "utf8",
    timeout: checkTimeoutMs,
    stdio: ["ignore", "pipe", "pipe"],
  });
  const output = `${result.stdout || ""}${result.stderr || ""}`;
  const checkPassed = result.status === 0 && !result.error;
  const after = sourceFingerprint();
  const sourceStable = after === sourceBefore;
  const status = checkPassed && sourceStable ? "passed" : "failed";
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

const report = {
  schema_version: 1,
  generated_at: new Date().toISOString(),
  status: passed ? "local_candidate_qa_passed" : "local_candidate_qa_failed",
  source_fingerprint: sourceBefore.match(/^([0-9a-f]{64}) files=(\d+)$/)?.[1] ?? null,
  source_file_count: Number(sourceBefore.match(/^([0-9a-f]{64}) files=(\d+)$/)?.[2] ?? 0),
  visual_status: "unverified",
  release_allowed: false,
  policy: "本报告只证明本机串行候选回归和证据绑定，不生成视觉 PNG，不替代可见窗口、Windows 真机或人工视觉签收。",
  checks: results,
};
fs.mkdirSync(path.dirname(outputPath), {recursive: true});
fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`, "utf8");

if (!passed) {
  const failed = results.find((entry) => entry.status !== "passed");
  throw new Error(`本地候选 QA 失败：${failed?.label ?? "未知步骤"}；报告已写入 ${outputPath}`);
}
console.log(`本地候选 QA 通过：${results.length}/${checks.length}；源码 ${sourceBefore}；视觉仍为 unverified`);
