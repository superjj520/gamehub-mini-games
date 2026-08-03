import test from 'node:test';
import assert from 'node:assert/strict';
import registry from '../../app/platform/game-registry-v2.js';

test('游玩路由始终显式携带玩法类型和配置引用', () => {
  registry.clear();
  registry.register({ manifest: { type: 'wheel', configVersion: 1 }, routes: { create: 'builder-v2.html', play: 'play.html' } });
  assert.equal(registry.resolveRoute('wheel', 'play', 'summer-spin'), 'play.html?game=wheel&config=summer-spin');
});

test('创建路由不混入配置实例', () => {
  assert.equal(registry.resolveRoute('wheel', 'create'), 'builder-v2.html?game=wheel');
});
