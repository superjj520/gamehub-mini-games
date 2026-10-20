import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const workspaceRoot = process.cwd();
const candidateRoot = path.resolve(workspaceRoot, process.env.FULL_CANDIDATE_ROOT?.trim() || "build/internal-full-candidate");
const candidatePackagePath = path.join(candidateRoot, "candidate-package-manifest.json");
const executablePath = path.resolve(workspaceRoot, process.env.FULL_CANDIDATE_WINDOWS_OUTPUT?.trim() || "build/windows/新时代觉醒者-完整候选.exe");
const exportLogPath = path.resolve(workspaceRoot, process.env.FULL_CANDIDATE_WINDOWS_LOG?.trim() || "reference-evidence/candidate-runtime/full-candidate-windows-export.log");
const outputPath = path.resolve(workspaceRoot, process.env.FULL_CANDIDATE_WINDOWS_MANIFEST?.trim() || "reference-evidence/candidate-runtime/full-candidate-windows-build.json");

function workspaceRelative(filePath) {
  return path.relative(workspaceRoot, filePath).split(path.sep).join("/");
}

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function inspectPe(filePath) {
  const file = fs.openSync(filePath, "r");
  try {
    const dosHeader = Buffer.alloc(0x40);
    if (fs.readSync(file, dosHeader, 0, dosHeader.length, 0) !== dosHeader.length || dosHeader.toString("ascii", 0, 2) !== "MZ") {
      throw new Error("候选 Windows 构建缺少有效 MZ 头");
    }
    const peOffset = dosHeader.readUInt32LE(0x3c);
    const peHeader = Buffer.alloc(6);
    if (fs.readSync(file, peHeader, 0, peHeader.length, peOffset) !== peHeader.length || peHeader.toString("ascii", 0, 4) !== "PE\0\0") {
      throw new Error("候选 Windows 构建缺少有效 PE 头");
    }
    const machine = peHeader.readUInt16LE(4);
    if (machine !== 0x8664) throw new Error(`候选 Windows 构建不是 x86_64：0x${machine.toString(16)}`);
    return {signature: "PE\\0\\0", machine: "x86_64", machine_code: "0x8664"};
  } finally {
    fs.closeSync(file);
  }
}

if (!fs.existsSync(candidatePackagePath)) throw new Error("缺少完整候选包清单，请先运行 npm run package:candidate:full");
if (!fs.existsSync(executablePath)) throw new Error("缺少完整候选 Windows 构建，请先导出 build/windows/新时代觉醒者-完整候选.exe");
if (!fs.existsSync(exportLogPath)) throw new Error("缺少完整候选 Windows 导出日志");
const packageManifest = JSON.parse(fs.readFileSync(candidatePackagePath, "utf8"));
const exportLog = fs.readFileSync(exportLogPath, "utf8");
const knownEnvironmentNoise = [
  /Condition "ret != noErr" is true\./i,
  /Cannot save file .*editor_settings-4\.7\.tres/i,
  /Error saving editor settings to .*editor_settings-4\.7\.tres/i,
];
const fatalExportErrors = exportLog
  .split(/\r?\n/)
  .filter((line) => /ERROR:|SCRIPT ERROR|Failed loading resource|Project export .* failed/i.test(line))
  .filter((line) => !knownEnvironmentNoise.some((pattern) => pattern.test(line)));
if (fatalExportErrors.length > 0) {
  throw new Error("完整候选 Windows 导出日志包含错误，拒绝生成通过清单");
}
const stat = fs.statSync(executablePath);
const manifest = {
  schema_version: 1,
  status: "internal_candidate_windows_build_generated",
  product_name: "新时代觉醒者",
  release_allowed: false,
  visual_status: "unverified",
  target_device_status: "unverified",
  candidate_variant: packageManifest.character_variant ?? "makehuman",
  package: {
    root: workspaceRelative(candidateRoot),
    sha256: packageManifest.package.sha256,
    file_count: packageManifest.package.file_count,
    source_sha256: packageManifest.source.sha256,
    source_file_count: packageManifest.source.file_count,
  },
  build: {
    path: workspaceRelative(executablePath),
    bytes: stat.size,
    sha256: sha256(executablePath),
    platform: "Windows Desktop",
    architecture: "x86_64",
    pe: inspectPe(executablePath),
  },
  export_log: {
    path: workspaceRelative(exportLogPath),
    sha256: sha256(exportLogPath),
    errors: 0,
    known_environment_noise: exportLog
      .split(/\r?\n/)
      .filter((line) => knownEnvironmentNoise.some((pattern) => pattern.test(line)))
      .length,
  },
  remaining_gates: [
    "Windows 10/11 目标设备启动与输入回归",
    "候选视觉人工签收",
    "最终资产权利签收",
    "Steam 商店材料和上传前置",
  ],
};
fs.writeFileSync(outputPath, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
console.log(`完整候选 Windows 构建清单已生成：${path.relative(workspaceRoot, outputPath)}；${stat.size} bytes；SHA-256 ${manifest.build.sha256}`);
