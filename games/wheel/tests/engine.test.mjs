import test from 'node:test';
import assert from 'node:assert/strict';
import wheelConfig from '../config.js';
const { normalizeConfig, pickOutcome, getPresets, getOutcomeAngle } = wheelConfig;

test('大转盘配置拒绝空奖池和重复奖项', () => {
  assert.throws(() => normalizeConfig({ prizes: [] }), /至少/);
  assert.throws(() => normalizeConfig({ prizes: [{ name: 'A', weight: 1 }, { name: 'A', weight: 1 }] }), /重复/);
});

test('大转盘先根据注入随机源确定结果', () => {
  const config = normalizeConfig({ prizes: [{ name: 'A', weight: 1 }, { name: 'B', weight: 3 }] });
  assert.equal(pickOutcome(config, { next: () => 0.9 }).prize.name, 'B');
});

test('预设配置会生成可用的视觉和内容字段', () => {
  const config = normalizeConfig(getPresets()[0].config);
  assert.equal(config.theme, 'neon');
  assert.equal(config.geometry.hollow, true);
  assert.ok(config.prizes.every((prize) => prize.color));
});

test('结果角度落在目标扇区中心', () => {
  const config = normalizeConfig({ prizes: [{ name: 'A', weight: 1 }, { name: 'B', weight: 1 }] });
  assert.equal(getOutcomeAngle(config, { index: 0 }), 0);
});
