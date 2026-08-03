import test from 'node:test';
import assert from 'node:assert/strict';
import contracts from '../../app/platform/game-contracts.js';

const manifest = {
  type: 'wheel',
  configVersion: 2,
  migrate(version, payload) {
    return version === 1 ? { items: payload.prizes } : payload;
  },
  validate(payload) {
    return {
      items: payload.items.map((item) => ({ name: item.name.trim(), weight: item.weight })),
    };
  },
};

test('规范化旧版本配置并升级到当前版本', () => {
  const result = contracts.normalizeEnvelope({
    type: 'wheel',
    version: 1,
    payload: { prizes: [{ name: ' 奖品 ', weight: 1 }] },
  }, manifest);

  assert.deepEqual(result, {
    type: 'wheel',
    version: 2,
    payload: { items: [{ name: '奖品', weight: 1 }] },
  });
});

test('运行时会话不污染可分享配置', () => {
  const session = contracts.createSession('wheel-config-1');

  assert.equal(session.configId, 'wheel-config-1');
  assert.equal(session.status, 'active');
  assert.deepEqual(session.outcomes, []);
  assert.equal(typeof session.startedAt, 'number');
});
