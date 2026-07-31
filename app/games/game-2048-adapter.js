// 2048 旧版入口适配器：接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({ id: 'game-2048', page: 'game-2048', meta: { category: '益智', accent: '#47F1D0' }, handleAction: function (action) { if (action === 'start' && typeof root.newGame === 'function') root.newGame(); } });
}(window));
