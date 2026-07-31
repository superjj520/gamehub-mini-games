(function () {
  var app = GameHubAppShell({ page: 'home' });
  function resolveCard(card) {
    var href = card.getAttribute('href') || '';
    var queryGame = new URLSearchParams(href.split('?')[1] || '').get('game');
    if (queryGame) return GameHubCatalog.get(queryGame);
    if (href.indexOf('wheel-page') >= 0) return GameHubCatalog.get('wheel');
    return GameHubCatalog.all.find(function (game) { return href.indexOf(game.file) >= 0; }) || null;
  }
  document.querySelectorAll('.game-card').forEach(function (card) {
    var game = resolveCard(card); if (!game) return;
    card.dataset.gameId = game.id; card.dataset.gameCategory = game.category; card.style.setProperty('--game-accent', game.accent); card.setAttribute('aria-label', game.name + '，' + game.category + '，' + game.status);
    card.addEventListener('click', function () { app.enterGame(game.id, 'home-card'); if (GameHubFeedback) GameHubFeedback.toast('正在进入' + game.name, { tone: 'success', duration: 1200 }); });
  });
}());
