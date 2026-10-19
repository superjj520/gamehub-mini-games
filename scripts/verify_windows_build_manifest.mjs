import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {execFileSync} from "node:child_process";

const root = process.cwd();
const manifestPath = path.join(root, "docs", "windows-build-manifest.json");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));

if (manifest.schema_version !== 1) throw new Error("Windows 构建清单 schema 版本不受支持");
if (manifest.status !== "generated_target_device_unverified") {
  throw new Error(`Windows 构建清单状态不符合未验收基线：${manifest.status}`);
}
if (manifest.platform !== "Windows Desktop" || manifest.architecture !== "x86_64") {
  throw new Error("Windows 构建清单的平台或架构不是已确认目标");
}
if (!Number.isInteger(manifest.runtime_source_file_count) || manifest.runtime_source_file_count <= 0) {
  throw new Error("Windows 构建清单缺少有效的运行时源文件数");
}
if (!Array.isArray(manifest.presets) || manifest.presets.length !== 2) {
  throw new Error("Windows 构建清单必须明确包含内部测试和首发候选两个构建");
}

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function inspectPe(filePath) {
  const stat = fs.statSync(filePath);
  if (stat.size < 0x40) throw new Error(`Windows 构建过短，无法读取 DOS 头：${filePath}`);
  const file = fs.openSync(filePath, "r");
  const dosHeader = Buffer.alloc(0x40);
  try {
    const readBytes = fs.readSync(file, dosHeader, 0, dosHeader.length, 0);
    if (readBytes !== dosHeader.length) throw new Error(`Windows 构建 DOS 头读取不完整：${filePath}`);
  } finally {
    fs.closeSync(file);
  }
  if (dosHeader.toString("ascii", 0, 2) !== "MZ") throw new Error(`构建缺少 MZ DOS 头：${filePath}`);
  const peOffset = dosHeader.readUInt32LE(0x3c);
  if (peOffset < 0x40 || peOffset + 6 > stat.size) {
    throw new Error(`构建的 PE 偏移超出文件边界：${filePath}`);
  }
  const peHeader = Buffer.alloc(6);
  const peFile = fs.openSync(filePath, "r");
  try {
    const readBytes = fs.readSync(peFile, peHeader, 0, peHeader.length, peOffset);
    if (readBytes !== peHeader.length) throw new Error(`Windows 构建 PE 头读取不完整：${filePath}`);
  } finally {
    fs.closeSync(peFile);
  }
  if (peHeader.toString("ascii", 0, 4) !== "PE\0\0") {
    throw new Error(`构建缺少 PE 签名：${filePath}`);
  }
  const machine = peHeader.readUInt16LE(4);
  if (machine !== 0x8664) throw new Error(`构建不是 PE x86_64：${filePath}`);
}

const expectedPresets = new Map([
  ["新时代觉醒者 Windows 内部测试", "build/windows/新时代觉醒者.exe"],
  ["新时代觉醒者 Windows 首发候选", "build/windows/新时代觉醒者-首发候选.exe"],
]);
const seenPresetNames = new Set();
for (const preset of manifest.presets ?? []) {
  if (!expectedPresets.has(preset.name) || expectedPresets.get(preset.name) !== preset.path) {
    throw new Error(`Windows 构建清单包含未登记的构建：${preset.name} -> ${preset.path}`);
  }
  if (seenPresetNames.has(preset.name)) throw new Error(`Windows 构建清单构建名称重复：${preset.name}`);
  seenPresetNames.add(preset.name);
  const buildPath = path.resolve(root, preset.path);
  if (!fs.existsSync(buildPath)) throw new Error(`清单中的 Windows 构建不存在：${preset.path}`);
  const stat = fs.statSync(buildPath);
  if (stat.size !== preset.bytes) {
    throw new Error(`Windows 构建体积与清单不一致：${preset.path}；实际 ${stat.size}，清单 ${preset.bytes}`);
  }
  const actualSha256 = sha256(buildPath);
  if (actualSha256 !== preset.sha256) {
    throw new Error(`Windows 构建 SHA-256 与清单不一致：${preset.path}`);
  }
  inspectPe(buildPath);
  if (preset.target_device_status !== "unverified") {
    throw new Error(`构建清单错误地标记了目标设备状态：${preset.path}`);
  }
}

const sourceFingerprint = execFileSync("node", ["scripts/source_fingerprint.mjs"], {cwd: root, encoding: "utf8"}).trim();
const expectedFingerprint = `${manifest.runtime_source_fingerprint} files=${manifest.runtime_source_file_count}`;
if (sourceFingerprint !== expectedFingerprint) {
  throw new Error(`Windows 构建清单源指纹不一致：实际 ${sourceFingerprint}；清单 ${expectedFingerprint}`);
}

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
for (const templateName of ["windows_debug_x86_64.exe", "windows_release_x86_64.exe"]) {
  const templatePath = path.join(templateRoot, "4.7.1.stable", templateName);
  if (!fs.existsSync(templatePath)) throw new Error(`缺少 Windows 导出模板：${templatePath}`);
  const actualSha256 = sha256(templatePath);
  if (actualSha256 !== manifest.export_templates?.[templateName]) {
    throw new Error(`Windows 导出模板 SHA-256 与清单不一致：${templateName}`);
  }
}

console.log(`Windows 构建清单验证通过：${manifest.presets.length} 个构建、源指纹、PE x86_64 结构和导出模板哈希均一致`);
console.log("目标设备仍保持 unverified；本脚本不把静态构建证据升级为 Windows 真机通过");
