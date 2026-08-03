import test from 'node:test';
import assert from 'node:assert/strict';
import contracts from '../../platform/contracts/game-definition.js';

const { createGameDefinition, createGameRecords } = contracts;

test('游戏定义必须提供独立的引擎和玩家工厂', () => {
  assert.throws(() => createGameDefinition({ type: 'wheel' }), /createEngine/);
});

test('游戏配置、会话和结果使用独立记录', () => {
  const records = createGameRecords();
  const config = records.createConfig({ id: 'cfg-1', gameType: 'wheel', gameVersion: 1, payload: { items: [] } });
  const session = records.createSession({ id: 'ses-1', configId: config.id, gameVersion: 1 });
  const outcome = records.createOutcome({ sessionId: session.id, result: '奖品' });
  assert.equal(config.payload.items.length, 0);
  assert.equal(session.configId, 'cfg-1');
  assert.equal(outcome.sessionId, 'ses-1');
});
