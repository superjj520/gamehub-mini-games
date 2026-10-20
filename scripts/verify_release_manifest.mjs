import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

const workspaceRoot = path.resolve(".");
const runtimeRoot = path.join(workspaceRoot, "gta-reference-runtime");
const manifestPath = path.join(workspaceRoot, "docs", "release-manifest.json");
const projectPath = path.join(runtimeRoot, "project.godot");
const ignoredDirectories = new Set([".godot", ".import"]);

function collectFiles(directory) {
  const entries = fs.readdirSync(directory, { withFileTypes: true }).sort((left, right) => left.name.localeCompare(right.name));
  const files = [];
  for (const entry of entries) {
    if (entry.isDirectory() && ignoredDirectories.has(entry.name)) continue;
    const absolutePath = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...collectFiles(absolutePath));
    else if (entry.isFile() && !entry.name.endsWith(".import") && !entry.name.endsWith(".uid")) files.push(absolutePath);
  }
  return files;
}

function fingerprintRuntime() {
  const hash = crypto.createHash("sha256");
  const files = collectFiles(runtimeRoot);
  for (const filePath of files) {
    const relativePath = path.relative(runtimeRoot, filePath).split(path.sep).join("/");
    hash.update(relativePath);
    hash.update("\0");
    hash.update(fs.readFileSync(filePath));
    hash.update("\0");
  }
  return { sha256: hash.digest("hex"), file_count: files.length };
}

function inventoryRuntime() {
  return collectFiles(runtimeRoot).map((filePath) => ({
    path: path.relative(runtimeRoot, filePath).split(path.sep).join("/"),
    bytes: fs.statSync(filePath).size,
    sha256: crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex"),
  }));
}

if (!fs.existsSync(manifestPath)) throw new Error("候选发布清单不存在，请先运行 npm run release:manifest");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const projectText = fs.readFileSync(projectPath, "utf8");
const currentFingerprint = fingerprintRuntime();
const currentInventory = inventoryRuntime();
const currentEngine = execFileSync("godot", ["--version"], { encoding: "utf8" }).trim();
const currentVersion = projectText.match(/config\/version="([^"]+)"/)?.[1];

if (manifest.schema_version !== 1) throw new Error("候选发布清单 schema 版本不受支持");
if (manifest.status !== "internal_no_go") throw new Error("当前候选发布清单不能脱离 internal_no_go 状态");
if (manifest.project?.version !== currentVersion) throw new Error("候选发布清单项目版本已过期");
if (manifest.project?.engine !== currentEngine) throw new Error("候选发布清单 Godot 版本已过期");
if (manifest.source?.sha256 !== currentFingerprint.sha256 || manifest.source?.file_count !== currentFingerprint.file_count) {
  throw new Error("候选发布清单源文件指纹已过期");
}
if (!Array.isArray(manifest.source?.files) || JSON.stringify(manifest.source.files) !== JSON.stringify(currentInventory)) {
  throw new Error("候选发布清单逐文件清单已过期或不完整");
}
if (!manifest.rights?.blocked_assets?.includes("reference_videos")) throw new Error("候选发布清单没有登记参考视频阻断项");
if (!manifest.rights?.excluded_internal_assets?.includes("reference_videos")) throw new Error("候选发布清单没有登记参考视频内部排除项");
if (!Array.isArray(manifest.rights?.required_blocked_assets)) throw new Error("候选发布清单缺少候选包必需权利阻断项");
if (!manifest.excluded_from_runtime?.includes("reference-evidence/")) throw new Error("候选发布清单没有登记内部证据排除边界");
if (manifest.third_party_notices?.path !== "THIRD_PARTY_NOTICES.md") throw new Error("候选发布清单没有登记第三方声明索引");
if (manifest.third_party_notices?.status !== "internal_index_requires_official_license_text_before_release") throw new Error("候选发布清单错误地把第三方声明标记为已完成");
if (!Array.isArray(manifest.release_blockers) || manifest.release_blockers.length < 2) throw new Error("候选发布清单发布阻断项不完整");
if (!manifest.release_blockers.some((blocker) => blocker.includes("视觉"))) throw new Error("候选发布清单缺少视觉验收阻断项");
if (!manifest.release_blockers.some((blocker) => blocker.includes("Steam Windows") || blocker.includes("目标设备"))) throw new Error("候选发布清单缺少目标平台阻断项");
if (!manifest.rights.in_use_components.every((component) => component.release_allowed === true)) {
  throw new Error("候选发布清单包含不可发布的在用组件");
}

console.log(`候选发布清单验证通过：状态 ${manifest.status}，源文件指纹匹配 ${currentFingerprint.file_count} 个文件`);
