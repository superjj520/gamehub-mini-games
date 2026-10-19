import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {execFileSync} from "node:child_process";

const root = process.cwd();
const manifestPath = path.join(root, "docs", "windows-build-manifest.json");
const existing = JSON.parse(fs.readFileSync(manifestPath, "utf8"));

const sha256 = (filePath) => crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
const sourceFingerprint = execFileSync("node", ["scripts/source_fingerprint.mjs"], {
  cwd: root,
  encoding: "utf8",
}).trim();
const sourceMatch = sourceFingerprint.match(/^([0-9a-f]{64}) files=(\d+)$/);
if (!sourceMatch) throw new Error(`无法解析运行时源指纹：${sourceFingerprint}`);

const expectedPresets = [
  {name: "新时代觉醒者 Windows 内部测试", path: "build/windows/新时代觉醒者.exe", includes_tests: true},
  {name: "新时代觉醒者 Windows 首发候选", path: "build/windows/新时代觉醒者-首发候选.exe", includes_tests: false},
];
const presets = expectedPresets.map((expected) => {
  const filePath = path.join(root, expected.path);
  if (!fs.existsSync(filePath)) throw new Error(`Windows 构建不存在：${expected.path}`);
  const stat = fs.statSync(filePath);
  return {
    ...expected,
    bytes: stat.size,
    sha256: sha256(filePath),
    target_device_status: "unverified",
  };
});

const templateRoots = [
  process.env.GODOT_WINDOWS_TEMPLATE,
  path.join(os.homedir(), ".local", "share", "godot", "export_templates"),
  path.join(os.homedir(), "Library", "Application Support", "Godot", "export_templates"),
].filter(Boolean);
const templateRoot = templateRoots.find((candidate) => {
  const versionedRoot = path.join(candidate, "4.7.1.stable");
  return ["windows_debug_x86_64.exe", "windows_release_x86_64.exe"].every((name) => fs.existsSync(path.join(versionedRoot, name)));
});
if (!templateRoot) throw new Error("没有找到 Godot 4.7.1 Windows 导出模板目录");

const exportTemplates = {};
for (const name of ["windows_debug_x86_64.exe", "windows_release_x86_64.exe"]) {
  const filePath = path.join(templateRoot, "4.7.1.stable", name);
  exportTemplates[name] = sha256(filePath);
}

const manifest = {
  schema_version: 1,
  status: "generated_target_device_unverified",
  product_name: existing.product_name ?? "新时代觉醒者",
  godot_version: existing.godot_version ?? "4.7.1.stable.official.a13da4feb",
  runtime_source_fingerprint: sourceMatch[1],
  runtime_source_file_count: Number(sourceMatch[2]),
  platform: "Windows Desktop",
  architecture: "x86_64",
  presets,
  export_templates: exportTemplates,
  remaining_gates: [
    "最终资产与权利签收",
    "21 段参考视觉人工签收",
    "扩展视觉人工签收",
    "Windows 10/11 目标设备启动与输入回归",
    "Steam 商店材料和上传前置",
  ],
};

fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
console.log(`Windows 构建清单已重建：${sourceFingerprint}；${presets.length} 个构建`);
