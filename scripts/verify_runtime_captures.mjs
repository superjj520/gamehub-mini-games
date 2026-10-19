import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const manifestPath = path.join(root, "reference-evidence", "runtime-captures", "manifest.json");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
if (!Array.isArray(manifest.captures) || manifest.captures.length === 0) {
  throw new Error("运行时截图清单为空");
}

for (const capture of manifest.captures) {
  if (capture.visual_status !== "unverified") {
    throw new Error(`运行时截图 ${capture.id} 未保持未验收状态`);
  }
  const capturePath = path.join(root, "reference-evidence", capture.path);
  const bytes = fs.readFileSync(capturePath);
  const pngSignature = "89504e470d0a1a0a";
  if (bytes.subarray(0, 8).toString("hex") !== pngSignature) {
    throw new Error(`运行时截图 ${capture.id} 不是 PNG 文件`);
  }
  const sha256 = crypto.createHash("sha256").update(bytes).digest("hex");
  if (sha256 !== capture.sha256) {
    throw new Error(`运行时截图 ${capture.id} 指纹不匹配`);
  }
  for (const report of capture.comparison_reports ?? []) {
    const reportPath = path.join(root, "reference-evidence", "runtime-captures", report);
    const comparison = JSON.parse(fs.readFileSync(reportPath, "utf8"));
    if (comparison.visual_status !== "unverified") {
      throw new Error(`视觉对照报告 ${report} 不得自动改变验收状态`);
    }
    if (comparison.candidate_sha256 !== capture.sha256) {
      throw new Error(`视觉对照报告 ${report} 未指向当前运行时截图`);
    }
  }
}

console.log(`运行时截图证据清单验证通过：${manifest.captures.length} 张，视觉通过仍为 0`);
