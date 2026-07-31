// 摇骰子适配器：将旧版页面接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({
    id: 'shake-dice',
    page: 'shake-dice',
    meta: { category: '竞技', accent: '#FF6078' },
    handleAction: function (action) {
      if (action === 'start' && typeof root.shakeDice === 'function') root.shakeDice();
    },
  });
}(window));
