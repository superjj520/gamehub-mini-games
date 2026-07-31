// 应用壳入口：统一当前页面、玩家会话和游戏进入事件。
(function (root) {
  var session = { currentGame: null, startedAt: null, history: [] };
  var historyKey = 'gamehub-recent-games';

  function getMeta(gameId) {
    return root.GameHubCatalog && root.GameHubCatalog.get(gameId);
  }

  function rememberGame(gameId, result) {
    var meta = getMeta(gameId);
    var item = { id: gameId, name: meta ? meta.name : gameId, result: result || null, at: Date.now() };
    session.history.unshift(item);
    session.history = session.history.slice(0, 8);
    try { localStorage.setItem(historyKey, JSON.stringify(session.history)); } catch (error) {}
  }

  function toast(message, tone) {
    if (root.GameHubFeedback && typeof root.GameHubFeedback.toast === 'function') {
      root.GameHubFeedback.toast(message, { tone: tone || 'info', duration: 1400 });
      return;
    }
    var host = document.querySelector('[data-gh-toast-host]');
    if (!host) {
      host = document.createElement('div');
      host.dataset.ghToastHost = '';
      host.className = 'gh-toast-host';
      document.body.appendChild(host);
    }
    var item = document.createElement('div');
    item.className = 'gh-toast gh-toast-' + (tone || 'info');
    item.setAttribute('role', 'status');
    item.textContent = message;
    host.appendChild(item);
    requestAnimationFrame(function () { item.classList.add('is-visible'); });
    window.setTimeout(function () {
      item.classList.remove('is-visible');
      window.setTimeout(function () { if (item.parentNode) item.remove(); }, 220);
    }, 1400);
  }

  function bindLifecycleEvents() {
    if (root.__gameHubLifecycleBound || !root.GameHubEventBus) return;
    root.__gameHubLifecycleBound = true;
    root.GameHubEventBus.events.on('game:start', function (payload) {
      var meta = getMeta(payload && payload.gameId);
      toast('已开始：' + (meta ? meta.name : (payload && payload.gameId) || '本局游戏'), 'info');
    });
    root.GameHubEventBus.events.on('game:result', function (payload) {
      if (!payload || !payload.gameId) return;
      var meta = getMeta(payload.gameId);
      rememberGame(payload.gameId, payload.result || null);
      toast((meta ? meta.name : payload.gameId) + ' · ' + (payload.result || '本局结束'), payload.score > 0 ? 'success' : 'warning');
    });
  }

  root.GameHubAppShell = function (options) {
    options = options || {};
    bindLifecycleEvents();
    document.documentElement.dataset.ghPage = options.page || 'unknown';
    root.GameHubApp = {
      page: options.page || 'unknown',
      session: session,
      events: root.GameHubEventBus.events,
      enterGame: function (gameId, source) {
        var meta = getMeta(gameId);
        session.currentGame = gameId;
        session.startedAt = Date.now();
        document.documentElement.dataset.gameId = gameId;
        document.title = (meta ? meta.name : gameId) + ' · GameHub';
        root.GameHubEventBus.events.emit('game:enter', { gameId: gameId, source: source || 'direct' });
      },
    };
    root.GameHubEventBus.events.emit('app:ready', { page: options.page || 'unknown' });
    return root.GameHubApp;
  };
}(window));
