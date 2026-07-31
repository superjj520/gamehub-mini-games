// 抓娃娃适配器：将旧版页面接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({
    id: 'claw-machine',
    page: 'claw-machine',
    meta: { category: '抽奖', accent: '#8E7DFF' },
    handleAction: function (action) {
      if (action === 'start' && typeof root.startGame === 'function') root.startGame();
    },
  });
}(window));
