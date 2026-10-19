import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {spawnSync} from "node:child_process";

const workspaceRoot = path.resolve(".");
const godotBinary = process.env.GODOT_BIN?.trim() || "godot";
const packages = [
  {variant: "makehuman", root: path.join(workspaceRoot, "build/internal-full-candidate")},
  {variant: "original", root: path.join(workspaceRoot, "build/internal-full-candidate-original")},
  {variant: "original_only", root: path.join(workspaceRoot, "build/internal-full-candidate-original-only")},
];

for (const candidate of packages) {
  if (!fs.existsSync(candidate.root)) throw new Error(`缺少${candidate.variant}完整候选包：${candidate.root}`);
  try {
    const result = spawnSync(godotBinary, [
      "--headless",
      "--path",
      candidate.root,
      "--audio-driver",
      "Dummy",
      "--rendering-driver",
      "opengl3",
      "--rendering-method",
      "gl_compatibility",
      "--log-file",
      path.join(os.tmpdir(), `新时代觉醒者-candidate-launch-${candidate.variant}.log`),
      "-s",
      "res://tests/launcher_candidate_preview_test.gd",
    ], {
      cwd: workspaceRoot,
      stdio: ["ignore", "pipe", "pipe"],
      encoding: "utf8",
      timeout: 60000,
    });
    const output = `${result.stdout ?? ""}\n${result.stderr ?? ""}`;
    if (result.error) throw new Error(`${candidate.variant} 候选启动器测试失败：${result.error.message}`);
    if (result.status !== 0 || !output.includes("启动器候选资产预览入口通过")) {
      throw new Error(`${candidate.variant} 候选启动器测试失败：${output.slice(-3000)}`);
    }
  } finally {}
  console.log(`完整候选启动器测试通过：${candidate.variant}`);
}

console.log("完整候选包启动器 QA 通过：MakeHuman、原创角色与原创边界三套入口均可独立启动");
