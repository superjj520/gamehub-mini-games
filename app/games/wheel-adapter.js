// 大转盘旧页面适配器：先接入统一协议，再逐步把内部玩法拆出页面。
(function (root) {
  var contract = GameHubGameContract({
    id: 'wheel',
    meta: { name: '大转盘', category: '抽奖', accent: '#FF6078' },
    mount: function () {},
    start: function () { if (root.GameHubApp) root.GameHubApp.enterGame('wheel', 'wheel-adapter'); },
    handleAction: function (action) { if (action === 'spin' && typeof root.spin === 'function') root.spin(); },
    getState: function () { return { spinning: Boolean(root.GameHubWheelState && root.GameHubWheelState.spinning) }; },
  });
  GameHubGameRegistry.register(contract);
  var app = GameHubAppShell({ page: 'wheel' });
  app.enterGame('wheel', 'wheel-page');
  root.GameHubWheelContract = contract;
}(window));
