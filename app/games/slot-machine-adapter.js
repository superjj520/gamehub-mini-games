//老虎机适配器：将旧版页面接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({ id: 'slot-machine', page: 'slot-machine', meta: { category: '抽奖', accent: '#FF6078' }, handleAction: function (action) { if (action === 'start' && typeof root.startSpin === 'function') root.startSpin(); } });
}(window));
