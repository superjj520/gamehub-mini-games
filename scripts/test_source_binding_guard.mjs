import assert from "node:assert/strict";
import { assertSourceBinding } from "./source_binding_guard.mjs";

const fingerprint = "a".repeat(64);
const label = "测试采集清单";

assert.doesNotThrow(() => assertSourceBinding({
  source_fingerprint: fingerprint,
  source_file_count: 233,
}, label, fingerprint, 233));

assert.throws(
  () => assertSourceBinding({ source_file_count: 233 }, label, fingerprint, 233),
  /源指纹与当前运行时不一致，拒绝同步旧 PNG/,
);
assert.throws(
  () => assertSourceBinding({ source_fingerprint: fingerprint, source_file_count: 232 }, label, fingerprint, 233),
  /源指纹与当前运行时不一致，拒绝同步旧 PNG/,
);
assert.throws(
  () => assertSourceBinding(null, label, fingerprint, 233),
  /缺少采集记录，拒绝同步视觉证据/,
);

console.log("源指纹绑定保护回归通过：匹配、缺失和过期记录均按预期处理");
