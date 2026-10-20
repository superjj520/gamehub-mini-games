import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {execFileSync} from "node:child_process";

const root = process.cwd();
const catalogPath = "res://content/asset-runtime-catalog-original-only.json";
const outputDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "new-era-reference-capture-"));
const logPath = path.join(os.tmpdir(), "新时代觉醒者-reference-capture-asset-binding.log");

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

try {
  execFileSync("godot", [
    "--headless",
    "--log-file",
    logPath,
    "--path",
    "gta-reference-runtime",
    "--audio-driver",
    "Dummy",
    "--rendering-driver",
    "opengl3",
    "--rendering-method",
    "gl_compatibility",
    "--script",
    "res://tests/reference_capture_matrix.gd",
    "-s",
  ], {
    cwd: root,
    env: {
      ...process.env,
      REFERENCE_MATRIX_CAPTURELESS: "1",
      REFERENCE_MATRIX_OUTPUT_DIR: outputDirectory,
      REFERENCE_ASSET_CATALOG_PATH: catalogPath,
    },
    stdio: "pipe",
    encoding: "utf8",
  });

  const manifest = JSON.parse(fs.readFileSync(path.join(outputDirectory, "behavior-matrix-manifest.json"), "utf8"));
  const trace = JSON.parse(fs.readFileSync(path.join(outputDirectory, "behavior-matrix-trace-evidence.json"), "utf8"));
  assert(manifest.asset_catalog_path === catalogPath, "参考矩阵行为清单没有记录原创边界资产目录");
  assert(trace.asset_catalog_path === catalogPath, "参考矩阵轨迹清单没有记录原创边界资产目录");
  assert(Array.isArray(manifest.captures) && manifest.captures.length === 0, "无头绑定测试不应生成视觉截图记录");
  assert(Array.isArray(trace.captures) && trace.captures.length === 21, "无头绑定测试必须覆盖 21 个行为分段");
  for (const capture of trace.captures) {
    assert(capture.asset_catalog_path === catalogPath, `分段未绑定原创边界资产目录：${capture.id}`);
    assert(capture.state_setup === "canonical_candidate_state", `分段状态未标记为候选状态：${capture.id}`);
  }
  console.log(`参考采集资产绑定回归通过：${trace.captures.length}/21；视觉截图 0 张；目录 ${catalogPath}`);
} finally {
  fs.rmSync(outputDirectory, {recursive: true, force: true});
  fs.rmSync(logPath, {force: true});
}
