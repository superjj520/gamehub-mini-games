// 飞行棋适配器：将旧版页面接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({
    id: 'flying-chess',
    page: 'flying-chess',
    meta: { category: '竞技', accent: '#47F1D0' },
    handleAction: function (action) {
      if (action === 'start' && typeof root.rollDice === 'function') root.rollDice();
    },
  });
}(window));
