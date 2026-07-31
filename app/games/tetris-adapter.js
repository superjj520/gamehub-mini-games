// 俄罗斯方块适配器：将旧版页面接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({ id: 'tetris', page: 'tetris', meta: { category: '街机', accent: '#47F1D0' }, handleAction: function (action) { if (action === 'start' && typeof root.startGame === 'function') root.startGame(); } });
}(window));
