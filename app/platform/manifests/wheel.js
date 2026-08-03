// 大转盘玩法定义：只描述可分享配置，不包含动画和运行时状态。
(function (root, factory) {
  var manifest = factory();
  root.GameHubWheelManifest = manifest;
  if (typeof module === 'object' && module.exports) module.exports = manifest;
}(typeof window !== 'undefined' ? window : globalThis, function () {
  function clone(value) { return JSON.parse(JSON.stringify(value)); }

  var defaults = {
    blocks: [{
      id: 'wheel-prizes', type: 'collection', label: '奖池',
      config: { drawMode: 'weighted', cards: [
        { id: 'wheel-1', title: '惊喜大奖', weight: 5, icon: '🎁' },
        { id: 'wheel-2', title: '精选好礼', weight: 10, icon: '✨' },
        { id: 'wheel-3', title: '咖啡券', weight: 15, icon: '☕' },
        { id: 'wheel-4', title: '积分奖励', weight: 20, icon: '⭐' },
        { id: 'wheel-5', title: '下次更幸运', weight: 25, icon: '🍀' },
        { id: 'wheel-6', title: '谢谢参与', weight: 25, icon: '💫' },
      ] },
    }],
  };

  function validate(payload) {
    var normalized = clone(payload || {});
    var blocks = Array.isArray(normalized.blocks) ? normalized.blocks : [];
    var collection = blocks.find(function (block) { return block.type === 'collection'; });
    var cards = collection && collection.config && collection.config.cards;
    if (!Array.isArray(cards) || cards.length < 2) throw new Error('大转盘至少需要 2 个奖项');

    var names = {};
    cards.forEach(function (card, index) {
      card.title = String(card.title || '').trim();
      card.weight = Number(card.weight);
      if (!card.title) throw new Error('第 ' + (index + 1) + ' 个奖项缺少名称');
      if (names[card.title]) throw new Error('奖项名称不能重复');
      if (!Number.isFinite(card.weight) || card.weight <= 0) throw new Error('奖项权重必须大于 0');
      names[card.title] = true;
    });
    return normalized;
  }

  return {
    type: 'wheel', name: '大转盘', configVersion: 1, defaults: defaults,
    migrate: function (_version, payload) { return payload; },
    validate: validate,
  };
}));
