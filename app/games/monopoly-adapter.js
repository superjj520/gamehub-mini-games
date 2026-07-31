// 大富翁适配器：将旧版页面接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({
    id: 'monopoly',
    page: 'monopoly',
    meta: { category: '竞技', accent: '#FFD166' },
    handleAction: function (action) {
      if (action === 'start' && typeof root.rollDice === 'function') root.rollDice();
    },
  });
}(window));
