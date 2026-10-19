import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const workspaceRoot = process.cwd();
const manifestPath = path.resolve(workspaceRoot, process.env.FULL_CANDIDATE_WINDOWS_MANIFEST?.trim() || "reference-evidence/candidate-runtime/full-candidate-windows-build.json");

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function inspectPe(filePath) {
  const file = fs.openSync(filePath, "r");
  try {
    const dosHeader = Buffer.alloc(0x40);
    if (fs.readSync(file, dosHeader, 0, dosHeader.length, 0) !== dosHeader.length || dosHeader.toString("ascii", 0, 2) !== "MZ") throw new Error("缺少 MZ 头");
    const peHeader = Buffer.alloc(6);
    if (fs.readSync(file, peHeader, 0, peHeader.length, dosHeader.readUInt32LE(0x3c)) !== peHeader.length || peHeader.toString("ascii", 0, 4) !== "PE\0\0") throw new Error("缺少 PE 头");
    if (peHeader.readUInt16LE(4) !== 0x8664) throw new Error("不是 PE x86_64");
  } finally {
    fs.closeSync(file);
  }
}

if (!fs.existsSync(manifestPath)) throw new Error("缺少完整候选 Windows 构建清单");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const packageManifestPath = path.resolve(workspaceRoot, manifest.package?.root || "build/internal-full-candidate", "candidate-package-manifest.json");
if (!fs.existsSync(packageManifestPath)) throw new Error("缺少清单绑定的完整候选包清单");
const packageManifest = JSON.parse(fs.readFileSync(packageManifestPath, "utf8"));
if (manifest.status !== "internal_candidate_windows_build_generated" || manifest.release_allowed !== false) throw new Error("完整候选 Windows 构建状态或发布边界错误");
if (manifest.package?.sha256 !== packageManifest.package?.sha256 || manifest.package?.file_count !== packageManifest.package?.file_count) throw new Error("Windows 候选构建没有绑定当前候选包指纹");
const buildPath = path.resolve(workspaceRoot, manifest.build.path);
const logPath = path.resolve(workspaceRoot, manifest.export_log.path);
if (!fs.existsSync(buildPath) || !fs.existsSync(logPath)) throw new Error("Windows 候选构建或导出日志不存在");
const stat = fs.statSync(buildPath);
if (stat.size !== manifest.build.bytes || sha256(buildPath) !== manifest.build.sha256) throw new Error("Windows 候选构建大小或 SHA-256 不一致");
inspectPe(buildPath);
const log = fs.readFileSync(logPath, "utf8");
const knownEnvironmentNoise = [
  /Condition "ret != noErr" is true\./i,
  /Cannot save file .*editor_settings-4\.7\.tres/i,
  /Error saving editor settings to .*editor_settings-4\.7\.tres/i,
];
const fatalExportErrors = log
  .split(/\r?\n/)
  .filter((line) => /ERROR:|SCRIPT ERROR|Failed loading resource|Project export .* failed/i.test(line))
  .filter((line) => !knownEnvironmentNoise.some((pattern) => pattern.test(line)));
if (fatalExportErrors.length > 0) throw new Error("Windows 候选导出日志包含错误");
if (sha256(logPath) !== manifest.export_log.sha256) throw new Error("Windows 候选导出日志 SHA-256 不一致");
console.log(`完整候选 Windows 构建验证通过：${manifest.build.path}；${manifest.build.bytes} bytes；PE x86_64；导出错误 0；目标设备仍为 unverified`);
