// 应用壳入口：统一当前页面、玩家会话和游戏进入事件。
(function (root) {
  var session = { currentGame: null, startedAt: null };
  root.GameHubAppShell = function (options) {
    options = options || {};
    document.documentElement.dataset.ghPage = options.page || 'unknown';
    root.GameHubApp = {
      page: options.page || 'unknown',
      session: session,
      events: root.GameHubEventBus.events,
      enterGame: function (gameId, source) { session.currentGame = gameId; session.startedAt = Date.now(); root.GameHubEventBus.events.emit('game:enter', { gameId: gameId, source: source || 'direct' }); },
    };
    root.GameHubEventBus.events.emit('app:ready', { page: options.page || 'unknown' });
    return root.GameHubApp;
  };
}(window));
