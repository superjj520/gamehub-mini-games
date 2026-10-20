import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

const workspaceRoot = path.resolve(".");
const runtimeRoot = path.join(workspaceRoot, "gta-reference-runtime");
const defaultOutput = path.join(workspaceRoot, "build", "internal-candidate");
const defaultManifest = path.join(workspaceRoot, "build", "internal-candidate-manifest.json");
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

function digestDirectory(directory) {
  const hash = crypto.createHash("sha256");
  const files = collectFiles(directory);
  for (const filePath of files) {
    const relativePath = path.relative(directory, filePath).split(path.sep).join("/");
    hash.update(relativePath);
    hash.update("\0");
    hash.update(fs.readFileSync(filePath));
    hash.update("\0");
  }
  return { sha256: hash.digest("hex"), file_count: files.length };
}

function assertSafeOutput(outputPath) {
  const normalized = path.resolve(outputPath);
  if (normalized === workspaceRoot || normalized === runtimeRoot || normalized === path.dirname(runtimeRoot)) {
    throw new Error("候选包输出目录过于宽泛，拒绝覆盖工作区或运行时根目录");
  }
}

function validateCurrentReleaseState() {
  execFileSync(process.execPath, [path.join(workspaceRoot, "scripts", "verify_release_tree.mjs")], { stdio: "inherit" });
  execFileSync(process.execPath, [path.join(workspaceRoot, "scripts", "verify_release_manifest.mjs")], { stdio: "inherit" });
}

function copyCandidate(outputPath) {
  assertSafeOutput(outputPath);
  fs.rmSync(outputPath, { recursive: true, force: true });
  fs.mkdirSync(outputPath, { recursive: true });
  for (const sourcePath of collectFiles(runtimeRoot)) {
    const relativePath = path.relative(runtimeRoot, sourcePath);
    const targetPath = path.join(outputPath, relativePath);
    fs.mkdirSync(path.dirname(targetPath), { recursive: true });
    fs.copyFileSync(sourcePath, targetPath);
  }
  return digestDirectory(outputPath);
}

function parseArgs() {
  const args = process.argv.slice(2);
  const outputIndex = args.indexOf("--output");
  const outputPath = outputIndex >= 0 ? args[outputIndex + 1] : null;
  if (outputIndex >= 0 && (!outputPath || outputPath.startsWith("--"))) {
    throw new Error("--output 必须跟随一个目录路径");
  }
  return {
    outputPath: outputPath ? path.resolve(outputPath) : null,
    verifyReproducible: args.includes("--verify-reproducible"),
  };
}

const options = parseArgs();
validateCurrentReleaseState();

let reproducible = null;
if (options.verifyReproducible) {
  const firstPath = fs.mkdtempSync(path.join(os.tmpdir(), "reference-candidate-a-"));
  const secondPath = fs.mkdtempSync(path.join(os.tmpdir(), "reference-candidate-b-"));
  try {
    const first = copyCandidate(firstPath);
    const second = copyCandidate(secondPath);
    reproducible = {
      passed: first.sha256 === second.sha256 && first.file_count === second.file_count,
      first,
      second,
    };
    if (!reproducible.passed) throw new Error("内部候选包双次构建摘要不一致");
  } finally {
    fs.rmSync(firstPath, { recursive: true, force: true });
    fs.rmSync(secondPath, { recursive: true, force: true });
  }
}

let candidate = null;
if (options.outputPath) {
  candidate = copyCandidate(options.outputPath);
  const manifestPath = path.resolve(path.dirname(options.outputPath), "internal-candidate-manifest.json");
  const manifest = {
    schema_version: 1,
    status: "internal_no_go",
    purpose: "平台无关内部候选树，不是商店导出包",
    source_root: "gta-reference-runtime",
    candidate_root: path.relative(workspaceRoot, options.outputPath).split(path.sep).join("/"),
    candidate: {
      sha256: candidate.sha256,
      file_count: candidate.file_count,
    },
    reproducibility: reproducible,
    excluded: ["reference-evidence/", "参考视频", "未授权商业资产", ".godot/", ".import/"],
  };
  fs.mkdirSync(path.dirname(manifestPath), { recursive: true });
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
  console.log(`内部候选树已生成：${path.relative(workspaceRoot, options.outputPath)}；摘要 ${candidate.sha256}；文件 ${candidate.file_count} 个`);
  console.log(`内部候选树清单已生成：${path.relative(workspaceRoot, manifestPath)}`);
} else if (reproducible) {
  console.log(`内部候选树双次构建验证通过：摘要 ${reproducible.first.sha256}；文件 ${reproducible.first.file_count} 个`);
}
