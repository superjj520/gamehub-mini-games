import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";

const root = process.cwd();
const temporaryDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "gta-session-recovery-"));
const markerPath = path.join(temporaryDirectory, "session.json");
const probe = path.join(root, "gta-reference-runtime", "tests", "session_crash_probe.gd");

function runRecoverProbe() {
  return new Promise((resolve, reject) => {
    const child = spawn("godot", ["--headless", "--path", "gta-reference-runtime", "--log-file", "/tmp/godot-session-recover.log", "--script", probe], { cwd: root, env: { ...process.env, GTA_SESSION_PROBE_MODE: "recover", GTA_SESSION_MARKER_PATH: markerPath } });
    let output = "";
    child.stdout.on("data", (chunk) => { output += chunk.toString(); });
    child.stderr.on("data", (chunk) => { output += chunk.toString(); });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) reject(new Error(`恢复探针退出码 ${code}：${output}`));
      else if (!output.includes("recovered=true")) reject(new Error(`恢复探针未确认遗留会话：${output}`));
      else resolve();
    });
  });
}

await new Promise((resolve, reject) => {
  const child = spawn("godot", ["--headless", "--path", "gta-reference-runtime", "--log-file", "/tmp/godot-session-hold.log", "--script", probe], { cwd: root, env: { ...process.env, GTA_SESSION_PROBE_MODE: "hold", GTA_SESSION_MARKER_PATH: markerPath } });
  let output = "";
  let ready = false;
  const timeout = setTimeout(() => {
    child.kill("SIGKILL");
    reject(new Error(`异常退出探针超时：${output}`));
  }, 15000);
  child.stdout.on("data", (chunk) => {
    output += chunk.toString();
    if (!ready && output.includes("会话崩溃探针已准备")) {
      ready = true;
      clearTimeout(timeout);
      child.kill("SIGKILL");
    }
  });
  child.stderr.on("data", (chunk) => { output += chunk.toString(); });
  child.on("error", (error) => {
    clearTimeout(timeout);
    reject(error);
  });
  child.on("close", () => {
    clearTimeout(timeout);
    if (!ready) reject(new Error(`异常退出探针未准备完成：${output}`));
    else if (!fs.existsSync(markerPath)) reject(new Error("强制终止后会话标记不存在"));
    else resolve();
  });
});

await runRecoverProbe();
console.log("进程级异常退出恢复测试通过");
