// 集章册适配器：将旧版页面接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({ id: 'stamp-collect', page: 'stamp-collect', meta: { category: '收集', accent: '#FFD166' }, handleAction: function (action) { if (action === 'start' && typeof root.drawCard === 'function') root.drawCard(); } });
}(window));
