// 幸运数字适配器：将旧版页面接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({ id: 'lucky-number', page: 'lucky-number', meta: { category: '抽奖', accent: '#47F1D0' }, handleAction: function (action) { if (action === 'start' && typeof root.startDraw === 'function') root.startDraw(); } });
}(window));
