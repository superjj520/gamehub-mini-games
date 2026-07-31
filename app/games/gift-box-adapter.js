// 幸运礼盒适配器：将旧版页面接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({ id: 'gift-box', page: 'gift-box', meta: { category: '抽奖', accent: '#8E7DFF' }, handleAction: function (action) { if (action === 'start' && typeof root.startOpen === 'function') root.startOpen(); } });
}(window));
