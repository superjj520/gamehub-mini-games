// 翻牌配对适配器：将旧版页面接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({ id: 'flip-match', page: 'flip-match', meta: { category: '益智', accent: '#8E7DFF' }, handleAction: function (action) { if (action === 'start' && typeof root.startGame === 'function') root.startGame(); } });
}(window));
