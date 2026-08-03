// 平台启动时只注册已完成迁移的玩法；旧游戏继续走兼容链路。
(function (root) {
  if (!root.GameHubGameRegistryV2 || !root.GameHubWheelManifest) return;
  if (root.GameHubGameRegistryV2.get('wheel')) return;
  root.GameHubGameRegistryV2.register({
    manifest: root.GameHubWheelManifest,
    routes: { create: 'builder-v2.html', play: 'play.html' },
  });
}(window));
