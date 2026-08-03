import test from 'node:test';
import assert from 'node:assert/strict';
import wheelConfig from '../config.js';
const { normalizeConfig, pickOutcome } = wheelConfig;

test('大转盘配置拒绝空奖池和重复奖项', () => {
  assert.throws(() => normalizeConfig({ prizes: [] }), /至少/);
  assert.throws(() => normalizeConfig({ prizes: [{ name: 'A', weight: 1 }, { name: 'A', weight: 1 }] }), /重复/);
});

test('大转盘先根据注入随机源确定结果', () => {
  const config = normalizeConfig({ prizes: [{ name: 'A', weight: 1 }, { name: 'B', weight: 3 }] });
  assert.equal(pickOutcome(config, { next: () => 0.9 }).prize.name, 'B');
});
