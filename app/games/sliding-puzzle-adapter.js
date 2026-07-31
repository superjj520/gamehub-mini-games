// 滑动拼图适配器：将旧版页面接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({ id: 'sliding-puzzle', page: 'sliding-puzzle', meta: { category: '益智', accent: '#FF6078' }, handleAction: function (action) { if (action === 'start' && typeof root.startGame === 'function') root.startGame(); } });
}(window));
