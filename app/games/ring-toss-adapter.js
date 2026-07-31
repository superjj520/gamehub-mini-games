// 套圈适配器：将旧版页面接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({
    id: 'ring-toss',
    page: 'ring-toss',
    meta: { category: '动作', accent: '#FF6078' },
    handleAction: function (action) {
      if (action === 'start' && typeof root.startGame === 'function') root.startGame();
    },
  });
}(window));
