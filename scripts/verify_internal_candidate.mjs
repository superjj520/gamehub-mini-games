import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const workspaceRoot = path.resolve(".");
const candidateRoot = path.resolve(process.argv[2] || "build/internal-candidate");
const manifestPath = path.resolve(process.argv[3] || path.join(path.dirname(candidateRoot), "internal-candidate-manifest.json"));
const ignoredDirectories = new Set([".godot", ".import"]);
const forbiddenFragments = ["reference-evidence", "video-1-china-gta", "video-2-off-work", "commercial-game-assets"];
const forbiddenExtensions = new Set([".mp4", ".mov", ".avi"]);

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

function inventory(directory) {
  return collectFiles(directory).map((filePath) => ({
    path: path.relative(directory, filePath).split(path.sep).join("/"),
    bytes: fs.statSync(filePath).size,
    sha256: crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex"),
  }));
}

function digest(items) {
  const hash = crypto.createHash("sha256");
  for (const item of items) {
    hash.update(item.path);
    hash.update("\0");
    hash.update(fs.readFileSync(path.join(candidateRoot, item.path)));
    hash.update("\0");
  }
  return hash.digest("hex");
}

if (!fs.existsSync(candidateRoot) || !fs.statSync(candidateRoot).isDirectory()) {
  throw new Error(`内部候选树不存在：${candidateRoot}`);
}
if (!fs.existsSync(manifestPath)) {
  throw new Error(`内部候选树清单不存在：${manifestPath}`);
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const actualInventory = inventory(candidateRoot);
const actualDigest = digest(actualInventory);
if (manifest.schema_version !== 1 || manifest.status !== "internal_no_go") {
  throw new Error("内部候选树清单 schema 或状态不正确");
}
if (manifest.candidate?.file_count !== actualInventory.length || manifest.candidate?.sha256 !== actualDigest) {
  throw new Error("内部候选树与清单摘要或文件数不一致");
}
if (manifest.reproducibility?.passed !== true || manifest.reproducibility?.first?.sha256 !== actualDigest) {
  throw new Error("内部候选树缺少双次可重复构建证明");
}
const expectedPaths = new Set(actualInventory.map((item) => item.path));
for (const requiredPath of ["project.godot", "THIRD_PARTY_NOTICES.md", "content/rights-manifest.json", "scenes/launcher.tscn"]) {
  if (!expectedPaths.has(requiredPath)) throw new Error(`内部候选树缺少关键文件：${requiredPath}`);
}
for (const item of actualInventory) {
  const normalized = item.path.toLowerCase();
  if (forbiddenFragments.some((fragment) => normalized.includes(fragment))) {
    throw new Error(`内部候选树包含禁入内容：${item.path}`);
  }
  if (forbiddenExtensions.has(path.extname(normalized))) {
    throw new Error(`内部候选树包含参考视频格式：${item.path}`);
  }
}
console.log(`内部候选树独立验证通过：摘要 ${actualDigest}；文件 ${actualInventory.length} 个；禁入内容 0 个`);
