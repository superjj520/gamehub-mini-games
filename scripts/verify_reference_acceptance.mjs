import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const evidence = JSON.parse(fs.readFileSync("reference-evidence/manifest.json", "utf8"));
const acceptance = JSON.parse(fs.readFileSync("reference-evidence/acceptance-status.json", "utf8"));
const matrix = JSON.parse(fs.readFileSync("reference-evidence/runtime-matrix/manifest.json", "utf8"));
const traceEvidence = JSON.parse(fs.readFileSync("reference-evidence/runtime-matrix/trace-evidence.json", "utf8"));
const evidenceIds = evidence.sources.flatMap((source) => (source.segments ?? []).map((segment) => segment.id));
const referenceSegmentById = new Map(evidence.sources.flatMap((source) => (source.segments ?? []).map((segment) => [segment.id, segment])));
const entries = acceptance.segments;
const entryIds = entries.map((entry) => entry.id);
const matrixById = new Map((matrix.captures ?? []).map((capture) => [capture.id, capture]));
const traceById = new Map((traceEvidence.captures ?? []).map((capture) => [capture.id, capture]));
const eventAliases = {
  camera: "camera_state",
  perception: "perception_state",
  inventory: "inventory_changed",
};

if (new Set(entryIds).size !== entryIds.length) {
  throw new Error("参考验收清单存在重复分段 ID");
}
if (entryIds.length !== evidenceIds.length || evidenceIds.some((id) => !entryIds.includes(id))) {
  throw new Error("参考验收清单没有覆盖全部证据分段");
}

const allowedBehaviorStatuses = new Set(["unimplemented", "partial", "graybox", "passed"]);
const allowedVisualStatuses = new Set(["unverified", "partial", "passed"]);
const allowedVisualReviewMethods = new Set(["manual_frame_review", "manual_device_review"]);
const allowedBehaviorReviewMethods = new Set(["automated_replay", "manual_replay"]);
const canonicalUtcTimestamp = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;
for (const entry of entries) {
  if (!Array.isArray(entry.runtime_events) || entry.runtime_events.length === 0) {
    throw new Error(`参考分段没有运行时事件：${entry.id}`);
  }
  const capture = matrixById.get(entry.id);
  if (!capture) throw new Error(`参考分段没有对应运行时截图矩阵记录：${entry.id}`);
  const screenshotPath = path.join("reference-evidence", capture.path);
  if (!fs.existsSync(screenshotPath)) throw new Error(`参考分段运行时截图不存在：${entry.id}`);
  const screenshotHash = crypto.createHash("sha256").update(fs.readFileSync(screenshotPath)).digest("hex");
  if (screenshotHash !== capture.sha256) throw new Error(`参考分段运行时截图哈希不一致：${entry.id}`);
  const comparisonPath = path.join("reference-evidence", capture.comparison_report);
  if (!fs.existsSync(comparisonPath)) throw new Error(`参考分段视觉对照报告不存在：${entry.id}`);
  const comparison = JSON.parse(fs.readFileSync(comparisonPath, "utf8"));
  if (comparison.candidate_sha256 !== capture.sha256) throw new Error(`参考分段视觉对照报告未绑定当前截图：${entry.id}`);
  const trace = traceById.get(entry.id);
  if (!trace || !Array.isArray(trace.trace_events)) throw new Error(`参考分段没有对应事件轨迹：${entry.id}`);
  const traceTypes = new Set(trace.event_types ?? trace.trace_events.map((event) => event.type));
  for (const expectedEvent of entry.runtime_events) {
    const actualEvent = eventAliases[expectedEvent] ?? expectedEvent;
    if (!traceTypes.has(actualEvent)) throw new Error(`参考分段事件轨迹缺少声明事件：${entry.id}/${expectedEvent}`);
  }
  if (!allowedBehaviorStatuses.has(entry.behavior_status)) {
    throw new Error(`参考分段行为状态非法：${entry.id}`);
  }
  if (!allowedVisualStatuses.has(entry.visual_status)) {
    throw new Error(`参考分段视觉状态非法：${entry.id}`);
  }
  if (entry.visual_status === "passed" && (!entry.runtime_screenshot || !entry.screenshot_sha256)) {
    throw new Error(`视觉标记通过但缺少截图或截图哈希：${entry.id}`);
  }
  if (entry.visual_status === "passed") {
    const referenceSegment = referenceSegmentById.get(entry.id);
    if (!referenceSegment) throw new Error(`视觉标记通过但缺少参考帧记录：${entry.id}`);
    if (entry.runtime_screenshot.replace(/^reference-evidence\//, "") !== capture.path) {
      throw new Error(`视觉标记通过但 runtime_screenshot 未指向当前矩阵截图：${entry.id}`);
    }
    if (entry.screenshot_sha256 !== capture.sha256) {
      throw new Error(`视觉标记通过但 screenshot_sha256 未匹配当前矩阵截图：${entry.id}`);
    }
    const review = entry.visual_review;
    if (!review || typeof review !== "object") {
      throw new Error(`视觉标记通过但缺少人工审阅记录：${entry.id}`);
    }
    if (typeof review.reviewer !== "string" || review.reviewer.trim().length === 0) {
      throw new Error(`视觉标记通过但缺少审阅人：${entry.id}`);
    }
    const reviewedAt = review.reviewed_at;
    const reviewedTimestamp = typeof reviewedAt === "string" ? Date.parse(reviewedAt) : Number.NaN;
    const canonicalTimestamp = !Number.isNaN(reviewedTimestamp) && new Date(reviewedTimestamp).toISOString() === reviewedAt;
    if (typeof reviewedAt !== "string" || !canonicalUtcTimestamp.test(reviewedAt) || !canonicalTimestamp || reviewedTimestamp > Date.now()) {
      throw new Error(`视觉标记通过但审阅时间无效：${entry.id}`);
    }
    if (!allowedVisualReviewMethods.has(review.method)) {
      throw new Error(`视觉标记通过但审阅方式无效：${entry.id}`);
    }
    if (review.reference_sha256 !== referenceSegment.sha256) {
      throw new Error(`视觉标记通过但审阅记录未绑定参考帧哈希：${entry.id}`);
    }
    if (review.runtime_source_fingerprint !== matrix.source_fingerprint) {
      throw new Error(`视觉标记通过但审阅记录未绑定当前运行时源指纹：${entry.id}`);
    }
    if (review.decision !== "passed") {
      throw new Error(`视觉标记通过但审阅记录 decision 不是 passed：${entry.id}`);
    }
    if (!Array.isArray(review.findings) || review.findings.length !== 0) {
      throw new Error(`视觉标记通过但仍有未清零的差异或返工项：${entry.id}`);
    }
  }
  if (entry.behavior_status === "passed") {
    const review = entry.behavior_review;
    if (!review || typeof review !== "object") throw new Error(`行为标记通过但缺少回放审阅记录：${entry.id}`);
    if (typeof review.reviewer !== "string" || review.reviewer.trim().length === 0) throw new Error(`行为标记通过但缺少审阅人：${entry.id}`);
    if (typeof review.replay_id !== "string" || review.replay_id.trim().length === 0) throw new Error(`行为标记通过但缺少 replay_id：${entry.id}`);
    if (!allowedBehaviorReviewMethods.has(review.method)) throw new Error(`行为标记通过但审阅方式无效：${entry.id}`);
    if (review.runtime_source_fingerprint !== matrix.source_fingerprint) throw new Error(`行为标记通过但审阅记录未绑定当前运行时源指纹：${entry.id}`);
    if (review.decision !== "passed") throw new Error(`行为标记通过但审阅记录 decision 不是 passed：${entry.id}`);
    if (!Array.isArray(review.findings) || review.findings.length !== 0) throw new Error(`行为标记通过但仍有未清零的返工项：${entry.id}`);
  }
}

const visualPassed = entries.filter((entry) => entry.visual_status === "passed").length;
const behaviorPassed = entries.filter((entry) => entry.behavior_status === "passed").length;
const behaviorGraybox = entries.filter((entry) => entry.behavior_status === "graybox").length;
console.log(`参考逐项验收清单通过：覆盖 ${entries.length} 个分段，行为已通过 ${behaviorPassed} 个，行为灰盒 ${behaviorGraybox} 个，视觉已通过 ${visualPassed} 个`);
