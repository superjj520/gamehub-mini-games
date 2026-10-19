import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {spawnSync} from "node:child_process";

const root = process.cwd();
const matrixPath = path.join(root, "reference-evidence/runtime-matrix/manifest.json");
const sourceDir = path.join(root, "reference-evidence/runtime-matrix");
const beforeHash = crypto.createHash("sha256").update(fs.readFileSync(matrixPath)).digest("hex");
const currentResult = spawnSync(process.execPath, ["scripts/finalize_reference_capture.mjs", "--source-dir", sourceDir], {
  cwd: root,
  encoding: "utf8",
});

// 当前版本在尚未完成真实窗口重采集时，正式编辑清单必须继续保留历史源，
// 因此“拒绝旧清单”本身就是预期结果；只有当前图形矩阵已经完整时才要求
// 预检成功，避免为了通过测试而伪造当前源截图绑定。
const currentOutput = `${currentResult.stdout ?? ""}${currentResult.stderr ?? ""}`;
if (currentResult.status !== 0 && !currentOutput.includes("采集清单没有绑定当前源码")) {
  throw new Error(`当前源预检意外失败：${currentOutput}`);
}
const afterHash = crypto.createHash("sha256").update(fs.readFileSync(matrixPath)).digest("hex");
if (beforeHash !== afterHash) throw new Error("预检模式修改了正式矩阵文件");

const staleSourceDir = fs.mkdtempSync(path.join("/tmp", "new-era-stale-capture-"));
try {
  const staleManifest = JSON.parse(fs.readFileSync(path.join(sourceDir, "matrix-manifest-editor.json"), "utf8"));
  const staleTrace = JSON.parse(fs.readFileSync(path.join(sourceDir, "matrix-trace-evidence-editor.json"), "utf8"));
  staleManifest.source_fingerprint = "0".repeat(64);
  staleTrace.source_fingerprint = "0".repeat(64);
  fs.writeFileSync(path.join(staleSourceDir, "matrix-manifest-editor.json"), JSON.stringify(staleManifest));
  fs.writeFileSync(path.join(staleSourceDir, "matrix-trace-evidence-editor.json"), JSON.stringify(staleTrace));

  const staleResult = spawnSync(process.execPath, ["scripts/finalize_reference_capture.mjs", "--source-dir", staleSourceDir], {
    cwd: root,
    encoding: "utf8",
  });
  if (staleResult.status === 0) throw new Error("过期源预检意外通过，可能会误绑历史截图");
  const staleOutput = `${staleResult.stdout ?? ""}${staleResult.stderr ?? ""}`;
  if (!staleOutput.includes("采集清单没有绑定当前源码")) {
    throw new Error(`过期源拒绝原因不符合预期：${staleOutput}`);
  }
} finally {
  fs.rmSync(staleSourceDir, {recursive: true, force: true});
}

const finalHash = crypto.createHash("sha256").update(fs.readFileSync(matrixPath)).digest("hex");
if (beforeHash !== finalHash) throw new Error("过期源拒绝测试修改了正式矩阵文件");

if (process.platform === "darwin") {
  const preflightRoot = fs.mkdtempSync(path.join("/tmp", "new-era-display-preflight-"));
  try {
    const fakeBin = path.join(preflightRoot, "bin");
    const failureRoot = path.join(preflightRoot, "failures");
    fs.mkdirSync(fakeBin, {recursive: true});
    fs.writeFileSync(path.join(fakeBin, "screencapture"), "#!/bin/sh\nexit 1\n", {mode: 0o755});

    const preflightResult = spawnSync("zsh", ["scripts/run_reference_capture_with_timeout.sh", "--version"], {
      cwd: root,
      encoding: "utf8",
      env: {
        ...process.env,
        PATH: `${fakeBin}:${process.env.PATH ?? ""}`,
        GODOT_BIN: "/usr/bin/true",
        REFERENCE_MATRIX_REQUIRED_GRAPHICS: "1",
        REFERENCE_CAPTURE_FAILURE_DIR: failureRoot,
      },
    });
    if (preflightResult.status !== 125) {
      throw new Error(`图形前置检查退出码错误：${preflightResult.status}; ${preflightResult.stdout ?? ""}${preflightResult.stderr ?? ""}`);
    }
    const failureFiles = fs.readdirSync(failureRoot).filter((name) => name.endsWith(".json"));
    if (failureFiles.length !== 1) throw new Error(`图形前置检查失败记录数量错误：${failureFiles.length}`);
    const failure = JSON.parse(fs.readFileSync(path.join(failureRoot, failureFiles[0]), "utf8"));
    if (failure.failure_kind !== "display_unavailable") throw new Error(`图形前置检查失败类型错误：${failure.failure_kind}`);
    if (!/^[0-9a-f]{64}$/.test(failure.source?.sha256 ?? "")) {
      throw new Error("图形前置检查失败记录缺少源码指纹");
    }
  } finally {
    fs.rmSync(preflightRoot, {recursive: true, force: true});
  }
  console.log("图形采集显示前置检查安全测试通过：不可用显示服务快速失败且不启动 Godot");
}

console.log("图形收口脚本安全拒绝测试通过：当前源预检不写入，过期源被拒绝，正式证据未被改写");
