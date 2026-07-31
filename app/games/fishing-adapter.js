// 钓鱼适配器：将旧版页面接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({
    id: 'fishing',
    page: 'fishing',
    meta: { category: '动作', accent: '#8E7DFF' },
    handleAction: function (action) {
      if (action === 'start' && typeof root.startGame === 'function') root.startGame();
    },
  });
}(window));
