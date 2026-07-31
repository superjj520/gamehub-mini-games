(function () {
  var gameId = new URLSearchParams(location.search).get('game') || 'monopoly';
  var game = GameHubCatalog.get(gameId);
  var app = GameHubAppShell({ page: 'game' });
  app.enterGame(game ? game.id : gameId, 'game-route');
  document.documentElement.dataset.gameId = game ? game.id : gameId;
  window.GameHubGameSession = { id: game ? game.id : gameId, meta: game || null, app: app };
}());
