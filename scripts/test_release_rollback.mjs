import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const workspaceRoot = path.resolve(".");
const windowsManifestPath = path.join(workspaceRoot, "docs", "windows-build-manifest.json");
const evidencePath = path.join(workspaceRoot, "reference-evidence", "release-rollback-rehearsal.json");

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function copyTree(source, target) {
  fs.mkdirSync(target, {recursive: true});
  for (const entry of fs.readdirSync(source, {withFileTypes: true})) {
    const sourcePath = path.join(source, entry.name);
    const targetPath = path.join(target, entry.name);
    if (entry.isDirectory()) fs.cpSync(sourcePath, targetPath, {recursive: true});
    else fs.copyFileSync(sourcePath, targetPath);
  }
}

if (!fs.existsSync(windowsManifestPath)) throw new Error("缺少 Windows 构建清单，无法进行回滚演练");
const manifest = JSON.parse(fs.readFileSync(windowsManifestPath, "utf8"));
const builds = Array.isArray(manifest.presets) ? manifest.presets : [];
if (builds.length < 2) throw new Error("回滚演练至少需要两个可追溯构建物");

const previous = builds.find((build) => build.includes_tests === true) ?? builds[0];
const candidate = builds.find((build) => build.includes_tests === false) ?? builds[1];
const previousPath = path.join(workspaceRoot, previous.path);
const candidatePath = path.join(workspaceRoot, candidate.path);
if (!fs.existsSync(previousPath) || !fs.existsSync(candidatePath)) throw new Error("回滚演练所需构建物不存在");
if (sha256(previousPath) !== previous.sha256 || sha256(candidatePath) !== candidate.sha256) {
  throw new Error("回滚演练前发现构建物哈希与 Windows 清单不一致");
}

const rehearsalRoot = fs.mkdtempSync(path.join(os.tmpdir(), "新时代觉醒者-rollback-"));
try {
  const previousRelease = path.join(rehearsalRoot, "previous");
  const candidateRelease = path.join(rehearsalRoot, "candidate");
  const activeRelease = path.join(rehearsalRoot, "active");
  const rollbackRelease = path.join(rehearsalRoot, "rollback");
  fs.mkdirSync(previousRelease);
  fs.mkdirSync(candidateRelease);
  fs.copyFileSync(previousPath, path.join(previousRelease, path.basename(previousPath)));
  fs.copyFileSync(candidatePath, path.join(candidateRelease, path.basename(candidatePath)));
  fs.writeFileSync(path.join(previousRelease, "build-identity.json"), JSON.stringify(previous, null, 2));
  fs.writeFileSync(path.join(candidateRelease, "build-identity.json"), JSON.stringify(candidate, null, 2));

  copyTree(previousRelease, activeRelease);
  const previousActiveHash = sha256(path.join(activeRelease, path.basename(previousPath)));
  fs.renameSync(activeRelease, rollbackRelease);
  copyTree(candidateRelease, activeRelease);
  const candidateActiveHash = sha256(path.join(activeRelease, path.basename(candidatePath)));
  fs.rmSync(activeRelease, {recursive: true, force: true});
  fs.renameSync(rollbackRelease, activeRelease);
  const restoredHash = sha256(path.join(activeRelease, path.basename(previousPath)));
  if (previousActiveHash !== previous.sha256 || candidateActiveHash !== candidate.sha256 || restoredHash !== previous.sha256) {
    throw new Error("回滚恢复后的构建身份与原版本不一致");
  }

  const evidence = {
    schema_version: 1,
    status: "internal_rehearsal_passed_target_platform_pending",
    rehearsal_scope: "本地文件级候选构建切换与恢复",
    generated_at: new Date().toISOString(),
    previous_build: {name: previous.name, path: previous.path, sha256: previous.sha256, bytes: previous.bytes},
    candidate_build: {name: candidate.name, path: candidate.path, sha256: candidate.sha256, bytes: candidate.bytes},
    restored_sha256: restoredHash,
    target_platform_status: "unverified",
    remaining: ["Steam 分支/Depot 回滚演练", "Windows 10/11 目标设备回滚验证", "正式发布负责人签署"],
  };
  fs.mkdirSync(path.dirname(evidencePath), {recursive: true});
  fs.writeFileSync(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`, "utf8");
  console.log(`内部文件级回滚演练通过：恢复哈希 ${restoredHash}；目标平台回滚仍未验证`);
} finally {
  fs.rmSync(rehearsalRoot, {recursive: true, force: true});
}
