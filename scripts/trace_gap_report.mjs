const isObject = (value) => value !== null && typeof value === "object" && !Array.isArray(value);

export function buildTraceGapReport(traceManifest, acceptance, matrix) {
  const acceptanceById = new Map(acceptance.segments.map((segment) => [segment.id, segment]));
  const matrixIds = new Set(matrix.captures.map((capture) => capture.id));
  const seen = new Set();
  const gaps = [];

  for (const capture of traceManifest.captures) {
    if (seen.has(capture.id)) throw new Error(`运行时事件证据存在重复分段：${capture.id}`);
    seen.add(capture.id);
    if (!matrixIds.has(capture.id)) throw new Error(`运行时事件证据没有对应截图：${capture.id}`);
    if (!Array.isArray(capture.trace_events) || capture.trace_events.length === 0) {
      throw new Error(`运行时事件证据为空：${capture.id}`);
    }
    if (!Number.isInteger(capture.input_event_count) || capture.input_event_count < 0) {
      throw new Error(`运行时输入事件计数无效：${capture.id}`);
    }
    if (!Array.isArray(capture.event_types) || !capture.event_types.includes("visual_capture_ready")) {
      throw new Error(`运行时事件证据没有冻结截图事件：${capture.id}`);
    }
    let previousTime = -1;
    for (const [index, event] of capture.trace_events.entries()) {
      if (!isObject(event)) throw new Error(`运行时事件证据第 ${index} 项不是对象：${capture.id}`);
      if (typeof event.type !== "string" || event.type.trim().length === 0) {
        throw new Error(`运行时事件证据第 ${index} 项类型无效：${capture.id}`);
      }
      if (typeof event.time !== "number" || !Number.isFinite(event.time) || event.time < 0 || event.time < previousTime) {
        throw new Error(`运行时事件证据第 ${index} 项时间无效：${capture.id}`);
      }
      if (!isObject(event.payload)) {
        throw new Error(`运行时事件证据第 ${index} 项 payload 无效：${capture.id}`);
      }
      previousTime = event.time;
    }
    const actualInputCount = capture.trace_events.filter((event) => event?.type === "input").length;
    if (actualInputCount !== capture.input_event_count) {
      throw new Error(`运行时输入事件计数不一致：${capture.id}`);
    }
    const expected = acceptanceById.get(capture.id)?.runtime_events ?? [];
    const missing = expected.filter((eventType) => !capture.event_types.includes(eventType));
    if (missing.length > 0) {
      gaps.push({
        "id": capture.id,
        "expected_events": expected,
        "missing_events": missing,
        "observed_events": capture.event_types
      });
    }
  }
  if (seen.size !== matrixIds.size) throw new Error("运行时事件证据与截图矩阵分段集合不一致");
  return {
    "version": 1,
    "status": gaps.length === 0 ? "complete" : "partial",
    "policy": "期望事件缺失必须保留缺口，不能自动提升行为或视觉验收状态",
    "segment_count": seen.size,
    "gap_count": gaps.length,
    "gaps": gaps
  };
}
