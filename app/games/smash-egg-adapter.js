// 砸金蛋适配器：将旧版页面接入 GameHub 统一游戏协议。
(function (root) {
  root.GameHubLegacyAdapter.mount({
    id: 'smash-egg',
    page: 'smash-egg',
    meta: { category: '抽奖', accent: '#FFD166' },
    handleAction: function () {},
  });
}(window));
