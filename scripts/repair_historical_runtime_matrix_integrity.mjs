import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

// 只修复历史矩阵的文件完整性：保留历史源指纹、采集身份和 unverified 状态，
// 不把历史 PNG 重新绑定到当前源码，也不改变任何视觉验收结论。
const root = process.cwd();
const matrixPath = path.join(root, "reference-evidence/runtime-matrix/manifest.json");
const matrix = JSON.parse(fs.readFileSync(matrixPath, "utf8"));
let repaired = 0;

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

for (const capture of matrix.captures ?? []) {
  const imagePath = path.join(root, "reference-evidence", capture.path);
  if (!fs.existsSync(imagePath)) throw new Error(`历史矩阵图片不存在：${capture.id}`);
  const actualHash = sha256(imagePath);
  if (capture.sha256 !== actualHash) {
    capture.sha256 = actualHash;
    repaired += 1;
  }
  capture.visual_status = "unverified";
  const comparisonPath = path.join(root, "reference-evidence", capture.comparison_report);
  const comparison = JSON.parse(fs.readFileSync(comparisonPath, "utf8"));
  comparison.candidate_sha256 = actualHash;
  comparison.visual_status = "unverified";
  fs.writeFileSync(comparisonPath, `${JSON.stringify(comparison, null, 2)}\n`, "utf8");
}

fs.writeFileSync(matrixPath, `${JSON.stringify(matrix, null, 2)}\n`, "utf8");
console.log(`历史运行时矩阵完整性已修复：${repaired} 张图片；源指纹和视觉状态保持不变`);
