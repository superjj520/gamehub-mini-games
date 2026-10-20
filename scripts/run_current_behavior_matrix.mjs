import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {spawnSync} from "node:child_process";

const root = process.cwd();
const runtimeRoot = path.join(root, "gta-reference-runtime");
const outputRoot = path.join(root, "reference-evidence/current-runtime-behavior");
const temporaryOutput = fs.mkdtempSync(path.join(os.tmpdir(), "新时代觉醒者-current-behavior-"));
const godotBinary = process.env.GODOT_BIN || "godot";
const sourceFingerprintBefore = String(spawnSync(process.execPath, ["scripts/source_fingerprint.mjs"], {cwd: root, encoding: "utf8"}).stdout || "").trim();
const sourceMatchBefore = sourceFingerprintBefore.match(/^([0-9a-f]{64}) files=(\d+)$/);
if (!sourceMatchBefore) throw new Error(`当前源码指纹格式无效：${sourceFingerprintBefore}`);

try {
  const result = spawnSync(godotBinary, [
    "--headless",
    "--log-file",
    "/tmp/xinjieyuanjuexing-current-behavior.log",
    "--path",
    runtimeRoot,
    "--audio-driver",
    "Dummy",
    "--rendering-driver",
    "opengl3",
    "--rendering-method",
    "gl_compatibility",
    "-s",
    "res://tests/reference_capture_matrix.gd",
  ], {
    cwd: root,
    env: {
      ...process.env,
      REFERENCE_MATRIX_CAPTURELESS: "1",
      REFERENCE_MATRIX_OUTPUT_DIR: temporaryOutput,
    },
    encoding: "utf8",
    // 21 个分段的 Godot 回放会产生大量调试输出；不要把整段输出塞进
    // Node 的同步管道，否则 macOS 可能以 ENOBUFS 终止一个本来成功的回放。
    stdio: ["ignore", "ignore", "ignore"],
    timeout: 180000,
  });
  const logPath = "/tmp/xinjieyuanjuexing-current-behavior.log";
  const output = fs.existsSync(logPath) ? fs.readFileSync(logPath, "utf8") : "";
  if (result.error) throw new Error(`当前行为矩阵进程启动失败：${result.error.message}`);
  if (result.status !== 0 || /SCRIPT ERROR|Parse Error|Assertion failed|ASSERT(?:ION)? FAILED|Invalid access/i.test(output)) {
    throw new Error(`当前行为矩阵回放失败：退出码 ${result.status ?? "null"}\n${output.slice(-6000)}`);
  }

  const tracePath = path.join(temporaryOutput, "behavior-matrix-trace-evidence.json");
  const matrixPath = path.join(temporaryOutput, "behavior-matrix-manifest.json");
  const trace = JSON.parse(fs.readFileSync(tracePath, "utf8"));
  const matrix = JSON.parse(fs.readFileSync(matrixPath, "utf8"));
  if (!Array.isArray(trace.captures) || trace.captures.length !== 21) throw new Error("当前行为矩阵没有覆盖 21 个分段");
  if (Array.isArray(matrix.captures) && matrix.captures.length !== 0) throw new Error("无图形行为矩阵不应携带视觉截图记录");

  const sourceFingerprintAfter = String(spawnSync(process.execPath, ["scripts/source_fingerprint.mjs"], {cwd: root, encoding: "utf8"}).stdout || "").trim();
  if (sourceFingerprintAfter !== sourceFingerprintBefore) {
    throw new Error(`当前行为矩阵回放期间源码指纹发生变化：开始 ${sourceFingerprintBefore}；结束 ${sourceFingerprintAfter}`);
  }

  fs.mkdirSync(outputRoot, {recursive: true});
  const report = {
    schema_version: 1,
    status: "current_behavior_matrix_verified",
    visual_status: "unverified",
    release_allowed: false,
    source_fingerprint: sourceMatchBefore[1],
    source_file_count: Number(sourceMatchBefore[2]),
    generated_at: new Date().toISOString(),
    captureless: true,
    segment_count: trace.captures.length,
    policy: "该证据由当前源码真实创建 21 个场景并回放状态；不生成视觉 PNG，不替代 Windows 图形采集或人工视觉签收。",
  };
  fs.writeFileSync(path.join(outputRoot, "manifest.json"), `${JSON.stringify({...report, captures: matrix.captures}, null, 2)}\n`, "utf8");
  fs.writeFileSync(path.join(outputRoot, "trace-evidence.json"), `${JSON.stringify({...report, captures: trace.captures}, null, 2)}\n`, "utf8");
  console.log(`当前行为矩阵通过：${trace.captures.length}/21；源码 ${sourceMatchBefore[1]} / ${sourceMatchBefore[2]} 个文件；视觉仍未验收`);
} finally {
  fs.rmSync(temporaryOutput, {recursive: true, force: true});
}
