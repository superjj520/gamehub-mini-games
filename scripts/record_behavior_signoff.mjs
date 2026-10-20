import fs from "node:fs";

const acceptancePath = "reference-evidence/acceptance-status.json";
const matrixPath = "reference-evidence/runtime-matrix/manifest.json";
const tracePath = "reference-evidence/runtime-matrix/trace-evidence.json";
const methods = new Set(["automated_replay", "manual_replay"]);
const eventAliases = {camera: "camera_state", perception: "perception_state", inventory: "inventory_changed"};

function usage() {
  console.log("用法：node scripts/record_behavior_signoff.mjs --segment <id> --reviewer <姓名或团队> --replay-id <回放编号> --method <automated_replay|manual_replay> [--write]");
}

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (token === "--write") {
      args.write = true;
      continue;
    }
    if (!token.startsWith("--")) throw new Error(`未知参数：${token}`);
    const value = argv[index + 1];
    if (!value || value.startsWith("--")) throw new Error(`参数缺少值：${token}`);
    args[token.slice(2)] = value;
    index += 1;
  }
  return args;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const args = parseArgs(process.argv.slice(2));
if (args.help || Object.keys(args).length === 0) {
  usage();
  process.exit(args.help ? 0 : 2);
}

const segmentId = args.segment;
const reviewer = args.reviewer;
const replayId = args["replay-id"];
const method = args.method;
assert(typeof segmentId === "string" && segmentId.length > 0, "必须提供 --segment");
assert(typeof reviewer === "string" && reviewer.trim().length > 0, "必须提供 --reviewer");
assert(typeof replayId === "string" && replayId.trim().length > 0, "必须提供 --replay-id");
assert(methods.has(method), "--method 必须是 automated_replay 或 manual_replay");

const acceptance = JSON.parse(fs.readFileSync(acceptancePath, "utf8"));
const matrix = JSON.parse(fs.readFileSync(matrixPath, "utf8"));
const traces = JSON.parse(fs.readFileSync(tracePath, "utf8"));
const entry = acceptance.segments.find((candidate) => candidate.id === segmentId);
const capture = matrix.captures.find((candidate) => candidate.id === segmentId);
const trace = traces.captures.find((candidate) => candidate.id === segmentId);
assert(entry, `不存在参考验收分段：${segmentId}`);
assert(capture, `不存在运行时截图矩阵分段：${segmentId}`);
assert(trace, `不存在运行时事件轨迹：${segmentId}`);
assert(entry.behavior_status !== "passed", `分段已经是 passed，拒绝重复签收：${segmentId}`);
assert(traces.source_fingerprint === matrix.source_fingerprint, `事件轨迹清单没有绑定当前运行时源指纹：${segmentId}`);

const traceTypes = new Set(trace.event_types ?? trace.trace_events?.map((event) => event.type) ?? []);
for (const expectedEvent of entry.runtime_events) {
  const actualEvent = eventAliases[expectedEvent] ?? expectedEvent;
  assert(traceTypes.has(actualEvent), `事件轨迹缺少验收要求：${segmentId}/${expectedEvent}`);
}
assert(Number.isInteger(trace.input_event_count) && trace.input_event_count >= 0, `事件轨迹输入计数无效：${segmentId}`);

const nextEntry = {
  ...entry,
  behavior_status: "passed",
  behavior_review: {
    reviewer: reviewer.trim(),
    replay_id: replayId.trim(),
    method,
    runtime_source_fingerprint: matrix.source_fingerprint,
    decision: "passed",
    findings: [],
  },
};

console.log(`行为签收预览：${segmentId}；回放 ${replayId}；事件 ${[...traceTypes].join("、")}；输入 ${trace.input_event_count} 次；源指纹 ${matrix.source_fingerprint}`);
if (!args.write) {
  console.log("未写入 acceptance-status.json；如已完成真实回放审阅，需显式追加 --write。");
  process.exit(0);
}

acceptance.segments = acceptance.segments.map((candidate) => candidate.id === segmentId ? nextEntry : candidate);
fs.writeFileSync(acceptancePath, `${JSON.stringify(acceptance, null, 2)}\n`, "utf8");
console.log(`行为签收已写入：${segmentId}；随后必须运行 node scripts/verify_reference_acceptance.mjs 和 npm run test:reference`);
