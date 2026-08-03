import test from 'node:test';
import assert from 'node:assert/strict';
import registryFactory from '../../platform/registry/game-registry.js';

test('注册表独立创建游戏实例并拒绝重复类型', () => {
  const registry = registryFactory.create();
  registry.register({ type: 'wheel', createEngine() { return {}; }, createPlayer() { return {}; } });
  assert.equal(registry.get('wheel').type, 'wheel');
  assert.throws(() => registry.register({ type: 'wheel', createEngine() { return {}; }, createPlayer() { return {}; } }), /已注册/);
});
