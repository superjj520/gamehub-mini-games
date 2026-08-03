(function () {
  var app = GameHubAppShell({ page: 'home' });
  var cards = Array.prototype.slice.call(document.querySelectorAll('.game-card'));
  var activeFilter = 'all';
  var searchTerm = '';
  function resolveCard(card) {
    var href = card.getAttribute('href') || '';
    var queryGame = new URLSearchParams(href.split('?')[1] || '').get('game');
    if (queryGame) return GameHubCatalog.get(queryGame);
    if (href.indexOf('wheel-page') >= 0) return GameHubCatalog.get('wheel');
    return GameHubCatalog.all.find(function (game) { return href.indexOf(game.file) >= 0; }) || null;
  }
  cards.forEach(function (card) {
    var game = resolveCard(card); if (!game) return;
    card.dataset.gameId = game.id; card.dataset.gameCategory = game.category; card.dataset.gameName = game.name; card.style.setProperty('--game-accent', game.accent); card.setAttribute('aria-label', game.name + '，' + game.category + '，' + game.status);
    card.addEventListener('click', function () { app.enterGame(game.id, 'home-card'); if (GameHubFeedback) GameHubFeedback.toast('正在进入' + game.name, { tone: 'success', duration: 1200 }); });
  });

  function applyFilters() {
    var visible = 0;
    cards.forEach(function (card) {
      var text = (card.textContent || '').toLowerCase();
      var category = card.dataset.gameCategory || '其他';
      var show = (!searchTerm || text.indexOf(searchTerm) >= 0 || category.toLowerCase().indexOf(searchTerm) >= 0) && (activeFilter === 'all' || category === activeFilter);
      card.hidden = !show;
      if (show) visible += 1;
    });
    var count = document.getElementById('gameCount');
    var empty = document.getElementById('gameEmpty');
    if (count) count.textContent = '显示 ' + visible + ' 款';
    if (empty) empty.hidden = visible !== 0;
  }

  var search = document.getElementById('gameSearch');
  if (search) search.addEventListener('input', function (event) { searchTerm = event.target.value.trim().toLowerCase(); applyFilters(); });
  document.querySelectorAll('[data-filter]').forEach(function (button) {
    button.addEventListener('click', function () {
      activeFilter = button.dataset.filter || 'all';
      document.querySelectorAll('[data-filter]').forEach(function (item) {
        var active = item === button;
        item.classList.toggle('is-active', active);
        item.setAttribute('aria-selected', String(active));
      });
      applyFilters();
    });
  });
  applyFilters();
}());
