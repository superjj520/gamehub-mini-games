import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const evidenceRoot = path.join(root, "reference-evidence", "candidate-runtime");
const fullCandidatePlaytestPath = path.join(evidenceRoot, "full-candidate-playtest.json");
const errors = [];
let inspected = 0;
let stale = 0;
let candidateMismatch = 0;
const activeCandidateIds = fs.existsSync(fullCandidatePlaytestPath)
  ? new Set(JSON.parse(fs.readFileSync(fullCandidatePlaytestPath, "utf8")).active_candidate_ids ?? [])
  : new Set();

function collectJsonFiles(directory) {
  if (!fs.existsSync(directory)) return [];
  const files = [];
  for (const entry of fs.readdirSync(directory, {withFileTypes: true}).sort((a, b) => a.name.localeCompare(b.name))) {
    const absolutePath = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...collectJsonFiles(absolutePath));
    else if (entry.isFile() && entry.name.endsWith(".json")) files.push(absolutePath);
  }
  return files;
}

for (const filePath of collectJsonFiles(evidenceRoot)) {
  let payload;
  try {
    payload = JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    errors.push(`${path.relative(root, filePath)} 不是有效 JSON：${error.message}`);
    continue;
  }
  if (!payload || typeof payload !== "object" || !payload.visual_status) continue;
  inspected += 1;
  const relativePath = path.relative(root, filePath);
  if (payload.source_stale_since_capture != null) {
    stale += 1;
    if (payload.visual_status !== "unverified") errors.push(`${relativePath} 已声明源过期，但 visual_status 不是 unverified`);
    if (payload.release_allowed !== false) errors.push(`${relativePath} 已声明源过期，但 release_allowed 不是 false`);
    if (typeof payload.source_stale_since_capture !== "object" || !String(payload.source_stale_since_capture.reason ?? "").trim()) {
      errors.push(`${relativePath} 已声明源过期，但缺少可读 reason`);
    }
  }
  if (Array.isArray(payload.candidate_ids) && activeCandidateIds.size > 0) {
    const mismatched = payload.candidate_ids.filter((candidateId) => !activeCandidateIds.has(candidateId));
    if (mismatched.length > 0) {
      candidateMismatch += 1;
      if (payload.visual_status !== "unverified" || payload.release_allowed !== false) {
        errors.push(`${relativePath} 使用了非当前候选资产 ${mismatched.join("、")}，但没有保持 unverified/release_allowed=false`);
      }
    }
  }
  if (String(payload.status ?? "").includes("graphical_capture") && payload.visual_status === "passed") {
    errors.push(`${relativePath} 图形候选证据不得自动标记 passed`);
  }
}

if (errors.length > 0) {
  console.error(`候选视觉新鲜度门禁失败：${errors.length} 项`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`候选视觉新鲜度门禁通过：检查 ${inspected} 份视觉元数据；源过期 ${stale} 份；候选版本不一致 ${candidateMismatch} 份；不一致证据均保持 unverified/release_allowed=false`);
