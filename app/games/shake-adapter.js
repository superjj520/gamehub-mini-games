// 摇一摇旧版入口适配器：接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({ id: 'shake', page: 'shake', meta: { category: '抽奖', accent: '#FFD166' }, handleAction: function (action) { if (action === 'start' && typeof root.triggerShake === 'function') root.triggerShake(); } });
}(window));
