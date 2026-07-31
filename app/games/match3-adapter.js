// 消消乐旧版入口适配器：接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({ id: 'match3', page: 'match3', meta: { category: '益智', accent: '#FF6078' }, handleAction: function (action) { if (action === 'start' && typeof root.startGame === 'function') root.startGame(); } });
}(window));
