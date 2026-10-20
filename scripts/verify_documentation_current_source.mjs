import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

const root = process.cwd();
const sourceOutput = execFileSync(process.execPath, ["scripts/source_fingerprint.mjs"], {
  cwd: root,
  encoding: "utf8",
}).trim();
const match = sourceOutput.match(/^([a-f0-9]{64}) files=(\d+)$/);
if (!match) throw new Error(`当前源码指纹格式无效：${sourceOutput}`);

const sourceFingerprint = match[1];
const sourceFileCount = Number(match[2]);
const sourceNeedle = `${sourceFingerprint} / ${sourceFileCount}`;
const documentationPaths = [
  "README.md",
  "docs/release-readiness.md",
  "docs/visual-capture-runbook.md",
  "docs/visual-gap-review-2026-10-14.md",
  "docs/windows-device-qa-runbook.md",
  "docs/3d-asset-pipeline-convention.md",
  "docs/production-roadmap.md",
  "docs/final-asset-production-backlog.md",
  "docs/expanded-content-plan.md",
  "docs/objective-completion-audit.md",
  "docs/internal-playtest-handoff.md",
  "docs/playable-vertical-slice-acceptance.md",
  "docs/visual-gap-register.md",
];

const errors = [];
for (const relativePath of documentationPaths) {
  const absolutePath = path.join(root, relativePath);
  if (!fs.existsSync(absolutePath)) {
    errors.push(`${relativePath} 不存在`);
    continue;
  }
  const contents = fs.readFileSync(absolutePath, "utf8");
  if (!contents.includes(sourceFingerprint)) {
    errors.push(`${relativePath} 没有记录当前源码指纹 ${sourceFingerprint}`);
  }
  if (!contents.includes(sourceNeedle)) {
    errors.push(`${relativePath} 没有记录当前源码文件数 ${sourceNeedle}`);
  }
}

if (errors.length > 0) {
  console.error("文档当前源一致性验证失败：");
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`文档当前源一致性验证通过：${documentationPaths.length} 份文档统一记录 ${sourceFingerprint} / ${sourceFileCount}`);
