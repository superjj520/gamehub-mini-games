import test from 'node:test';
import assert from 'node:assert/strict';
import storeFactory from '../../app/platform/config-store.js';

const registry = { get() { return { manifest: { type: 'wheel', configVersion: 1, migrate(_version, payload) { return payload; }, validate(payload) { return payload; } } }; } };

test('旧版 blocks 记录会被包装为版本化配置', () => {
  const store = storeFactory.create({ registry });
  assert.deepEqual(store.normalizeRecord({ game_type: 'wheel', version: 1, blocks: [{ id: 'prizes' }] }), {
    type: 'wheel', version: 1, payload: { blocks: [{ id: 'prizes' }] },
  });
});

test('新配置写入时保留旧 blocks 兼容字段', () => {
  const store = storeFactory.create({ registry });
  assert.deepEqual(store.toWritePayload({ type: 'wheel', version: 1, payload: { blocks: [{ id: 'prizes' }] } }), {
    game_type: 'wheel', config_version: 1, config_payload: { blocks: [{ id: 'prizes' }] }, blocks: [{ id: 'prizes' }],
  });
});
