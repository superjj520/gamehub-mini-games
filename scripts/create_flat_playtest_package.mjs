import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {execFileSync} from "node:child_process";

const workspaceRoot = path.resolve(".");
const candidateRoot = path.join(workspaceRoot, "build", "internal-candidate");
const candidateManifestPath = path.join(workspaceRoot, "build", "internal-candidate-manifest.json");
const packageReadmePath = path.join(workspaceRoot, "docs", "internal-playtest-package-readme.md");

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function parseArgs() {
  const args = process.argv.slice(2);
  const outputIndex = args.indexOf("--output");
  const outputPath = outputIndex >= 0 ? args[outputIndex + 1] : null;
  if (outputIndex >= 0 && (!outputPath || outputPath.startsWith("--"))) {
    throw new Error("--output 必须跟随压缩包路径");
  }
  return {
    outputPath: outputPath ? path.resolve(outputPath) : null,
  };
}

function assertSafeOutput(outputPath) {
  if (outputPath === workspaceRoot || outputPath === path.join(workspaceRoot, "build")) {
    throw new Error("试玩包输出路径过于宽泛，拒绝覆盖工作区或构建目录");
  }
  if (path.extname(outputPath).toLowerCase() !== ".zip") {
    throw new Error("试玩包输出路径必须是 .zip 文件");
  }
}

function readCandidateManifest() {
  if (!fs.existsSync(candidateManifestPath)) {
    throw new Error("缺少内部候选树清单，请先运行 npm run release:candidate");
  }
  const manifest = JSON.parse(fs.readFileSync(candidateManifestPath, "utf8"));
  if (manifest.status !== "internal_no_go" || !manifest.candidate?.sha256 || !Number.isInteger(manifest.candidate?.file_count)) {
    throw new Error("内部候选树清单状态或摘要字段无效");
  }
  return manifest;
}

function buildReadme(sourceFingerprint, fileCount) {
  const template = fs.readFileSync(packageReadmePath, "utf8");
  return template
    .replaceAll("__SOURCE_FINGERPRINT__", sourceFingerprint)
    .replaceAll("__SOURCE_FILE_COUNT__", String(fileCount))
    .replace(/^状态：.*$/m, "状态：内部研发候选，不是可上架版本。");
}

function setStableTimestamps(directory) {
  const stableTime = new Date("2000-01-01T00:00:00.000Z");
  const entries = fs.readdirSync(directory, {withFileTypes: true}).sort((left, right) => left.name.localeCompare(right.name));
  for (const entry of entries) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) setStableTimestamps(entryPath);
    fs.utimesSync(entryPath, stableTime, stableTime);
  }
  fs.utimesSync(directory, stableTime, stableTime);
}

function createPackage(outputPath, manifest) {
  assertSafeOutput(outputPath);
  if (!fs.existsSync(candidateRoot)) throw new Error("缺少内部候选树目录，请先运行 npm run release:candidate");
  fs.mkdirSync(path.dirname(outputPath), {recursive: true});

  const stagingRoot = fs.mkdtempSync(path.join(os.tmpdir(), "新时代觉醒者-flat-playtest-"));
  try {
    fs.cpSync(candidateRoot, stagingRoot, {recursive: true});
    fs.writeFileSync(path.join(stagingRoot, "README.md"), buildReadme(manifest.candidate.sha256, manifest.candidate.file_count), "utf8");
    setStableTimestamps(stagingRoot);
    fs.rmSync(outputPath, {force: true});
    execFileSync("zip", ["-Xqr", outputPath, "."], {cwd: stagingRoot, stdio: "inherit"});
  } finally {
    fs.rmSync(stagingRoot, {recursive: true, force: true});
  }
  const stat = fs.statSync(outputPath);
  return {bytes: stat.size, sha256: sha256(outputPath)};
}

const options = parseArgs();
const candidateManifest = readCandidateManifest();
execFileSync(process.execPath, [path.join(workspaceRoot, "scripts", "verify_internal_candidate.mjs")], {stdio: "inherit"});
const sourceShort = candidateManifest.candidate.sha256.slice(0, 8);
const outputPath = options.outputPath ?? path.join(workspaceRoot, "build", `internal-playtest-${sourceShort}-flat-v47.zip`);
const packageInfo = createPackage(outputPath, candidateManifest);
const metadataPath = path.join(path.dirname(outputPath), `${path.basename(outputPath, ".zip")}.json`);
const metadata = {
  schema_version: 1,
  status: "internal_no_go",
  package_path: path.relative(workspaceRoot, outputPath).split(path.sep).join("/"),
  source_fingerprint: candidateManifest.candidate.sha256,
  source_file_count: candidateManifest.candidate.file_count,
  bytes: packageInfo.bytes,
  sha256: packageInfo.sha256,
  launch_command: "godot --path . --import && godot --path .",
  excluded: ["reference-evidence/", "参考视频", "未授权商业资产", ".godot/", ".import/"],
  remaining_gates: ["最终资产", "视觉人工签收", "Windows 10/11 真机 QA", "Steam 商店门禁"],
};
fs.writeFileSync(metadataPath, `${JSON.stringify(metadata, null, 2)}\n`, "utf8");
console.log(`扁平源码试玩包已生成：${path.relative(workspaceRoot, outputPath)}；${packageInfo.bytes} bytes；SHA-256 ${packageInfo.sha256}`);
console.log(`试玩包清单已生成：${path.relative(workspaceRoot, metadataPath)}`);
