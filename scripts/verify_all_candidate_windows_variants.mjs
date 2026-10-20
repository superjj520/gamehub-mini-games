import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";

const root = process.cwd();
const sourceOutput = execFileSync(process.execPath, ["scripts/source_fingerprint.mjs"], {cwd: root, encoding: "utf8"}).trim();
const sourceMatch = sourceOutput.match(/^([0-9a-f]{64}) files=(\d+)$/);
if (!sourceMatch) throw new Error(`当前源码指纹格式无效：${sourceOutput}`);
const sourceSha = sourceMatch[1];
const sourceFiles = Number(sourceMatch[2]);

const variants = [
  {
    label: "完整候选",
    root: "build/internal-full-candidate",
    buildManifest: "reference-evidence/candidate-runtime/full-candidate-windows-build.json",
    qaManifest: "reference-evidence/candidate-runtime/full-candidate-windows-qa-bundle.json",
    executable: "build/windows/新时代觉醒者-完整候选.exe",
    qaBundle: "build/新时代觉醒者-完整候选-windows-qa.zip",
  },
  {
    label: "原创角色候选",
    root: "build/internal-full-candidate-original",
    buildManifest: "reference-evidence/candidate-runtime/full-candidate-windows-original-build.json",
    qaManifest: "reference-evidence/candidate-runtime/full-candidate-windows-original-qa-bundle.json",
    executable: "build/windows/新时代觉醒者-原创角色候选.exe",
    qaBundle: "build/新时代觉醒者-原创角色候选-windows-qa.zip",
  },
  {
    label: "原创边界候选",
    root: "build/internal-full-candidate-original-only",
    buildManifest: "reference-evidence/candidate-runtime/full-candidate-windows-original-only-build.json",
    qaManifest: "reference-evidence/candidate-runtime/full-candidate-windows-original-only-qa-bundle.json",
    executable: "build/windows/新时代觉醒者-原创边界候选.exe",
    qaBundle: "build/新时代觉醒者-原创边界候选-windows-qa.zip",
  },
];

function read(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
}

function sha256(relativePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(path.join(root, relativePath))).digest("hex");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

for (const variant of variants) {
  const build = read(variant.buildManifest);
  const qa = read(variant.qaManifest);
  const packageManifest = read(path.join(variant.root, "candidate-package-manifest.json"));
  assert(build.package?.source_sha256 === sourceSha && build.package?.source_file_count === sourceFiles, `${variant.label} Windows 构建未绑定当前源码`);
  assert(qa.package?.source_sha256 === sourceSha && qa.package?.source_file_count === sourceFiles, `${variant.label} QA 包未绑定当前源码`);
  assert(packageManifest.source?.sha256 === sourceSha && packageManifest.source?.file_count === sourceFiles, `${variant.label} 候选树未绑定当前源码`);
  assert(build.package?.sha256 === packageManifest.package?.sha256, `${variant.label} 构建清单与候选树哈希不一致`);
  assert(qa.package?.sha256 === packageManifest.package?.sha256, `${variant.label} QA 清单与候选树哈希不一致`);
  assert(build.build?.sha256 === sha256(variant.executable), `${variant.label} Windows 程序哈希不一致`);
  assert(qa.executable?.sha256 === build.build?.sha256, `${variant.label} QA 清单与 Windows 程序哈希不一致`);
  assert(qa.bundle?.sha256 === sha256(variant.qaBundle), `${variant.label} QA 压缩包哈希不一致`);
  for (const record of [build, qa, packageManifest]) {
    assert(record.release_allowed === false, `${variant.label} 候选不得允许发布`);
    assert(record.visual_status === "unverified", `${variant.label} 视觉状态不得绕过验收`);
  }
  assert(build.target_device_status === "unverified" && qa.target_device_status === "unverified", `${variant.label} 目标设备不得伪称通过`);
  console.log(`候选变体通过：${variant.label}；源码 ${sourceSha}/${sourceFiles}；视觉 unverified；发布 false`);
}

console.log(`三套 Windows 候选变体总体验证通过：${variants.length}/3；当前源 ${sourceSha}/${sourceFiles}`);
