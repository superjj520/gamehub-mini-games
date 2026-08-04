import test from 'node:test';
import assert from 'node:assert/strict';
import wheelConfig from '../config.js';
import wheelPlayer from '../player.js';

test('玩家组件按奖项数量渲染 SVG 扇区', () => {
  const config = wheelConfig.normalizeConfig({ prizes: [{ name: 'A', weight: 1 }, { name: 'B', weight: 1 }] });
  const html = wheelPlayer.renderWheel(config);
  assert.match(html, /data-wheel-sector="0"/);
  assert.match(html, /data-wheel-sector="1"/);
  assert.match(html, /class="wheel-svg"/);
});
