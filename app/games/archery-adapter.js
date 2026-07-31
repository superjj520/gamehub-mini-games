// 射箭适配器：将旧版页面接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({
    id: 'archery',
    page: 'archery',
    meta: { category: '动作', accent: '#47F1D0' },
    handleAction: function (action) {
      if (action === 'start' && typeof root.startGame === 'function') root.startGame();
    },
  });
}(window));
