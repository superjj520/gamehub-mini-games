import test from 'node:test';
import assert from 'node:assert/strict';
import manifest from '../../app/platform/manifests/wheel.js';

test('大转盘拒绝空奖池', () => {
  assert.throws(() => manifest.validate({ blocks: [{ type: 'collection', config: { cards: [] } }] }), /至少需要 2 个奖项/);
});

test('大转盘规范化奖项名称和权重', () => {
  const result = manifest.validate({ blocks: [{ type: 'collection', config: { cards: [
    { title: ' 一等奖 ', weight: 2 }, { title: '谢谢参与', weight: 1 },
  ] } }] });
  assert.equal(result.blocks[0].config.cards[0].title, '一等奖');
  assert.equal(result.blocks[0].config.cards[0].weight, 2);
});
