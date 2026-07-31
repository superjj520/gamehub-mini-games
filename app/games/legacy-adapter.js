// 旧版单页游戏的过渡适配器：统一建立会话和注册信息。
(function (root) {
  root.GameHubLegacyAdapter = {
    mount: function (config) {
      var contract = GameHubGameContract({ id: config.id, meta: config.meta, mount: function () {}, handleAction: config.handleAction });
      GameHubGameRegistry.register(contract);
      var app = GameHubAppShell({ page: config.page || 'game' });
      app.enterGame(config.id, 'legacy-adapter');
      return { contract: contract, app: app };
    },
  };
}(window));
