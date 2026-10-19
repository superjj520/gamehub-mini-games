import assert from "node:assert/strict";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

const workspaceRoot = process.cwd();
const temporaryRoot = mkdtempSync(path.join(tmpdir(), "new-era-background-capture-fallback-"));
const fakeBin = path.join(temporaryRoot, "bin");
const fakeApp = path.join(temporaryRoot, "Godot.app");
const outputRoot = path.join(temporaryRoot, "output");
const markerPath = path.join(temporaryRoot, "fallback-marker.txt");
mkdirSync(fakeBin, { recursive: true });
mkdirSync(fakeApp, { recursive: true });

const fakeOpenPath = path.join(fakeBin, "open");
const fakeGodotPath = path.join(fakeBin, "godot");
writeFileSync(fakeOpenPath, "#!/bin/zsh\nprint -u2 'kLSNoExecutableErr: fake LaunchServices failure'\nexit 0\n", "utf8");
writeFileSync(fakeGodotPath, `#!/bin/zsh\nprint -r -- fallback > "${markerPath}"\nexit 0\n`, "utf8");
chmodSync(fakeOpenPath, 0o755);
chmodSync(fakeGodotPath, 0o755);

const env = { ...process.env };
delete env.GODOT_BIN;
env.PATH = `${fakeBin}:${process.env.PATH ?? ""}`;
env.GODOT_APP_PATH = fakeApp;
env.REFERENCE_CAPTURE_USE_OPEN = "1";
env.REFERENCE_MATRIX_REQUIRED_GRAPHICS = "0";
env.REFERENCE_MATRIX_OUTPUT_DIR = outputRoot;
env.REFERENCE_MATRIX_PROGRESS_PATH = path.join(temporaryRoot, "progress.json");

const result = spawnSync("zsh", [
  "scripts/run_reference_capture_in_background.sh",
  "--path", "gta-reference-runtime",
  "--scene", "res://tests/reference_capture_runner.tscn",
  "--quit-after", "1"
], {
  cwd: workspaceRoot,
  env,
  encoding: "utf8"
});

try {
  assert.equal(result.status, 0, `后台回退测试退出码异常：${result.status}\n${result.stderr}`);
  assert.match(result.stderr, /LaunchServices failure/);
  assert.match(result.stderr, /尝试使用实际可执行文件/);
  assert.ok(existsSync(markerPath), "LaunchServices 失败后没有执行 Godot 二进制回退");
  console.log("后台图形采集 LaunchServices 回退回归通过：启动失败会进入实际 Godot 二进制路径");
} finally {
  rmSync(temporaryRoot, { recursive: true, force: true });
}
