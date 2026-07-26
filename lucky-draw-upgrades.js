/* 抽奖类游戏批次 2：统一导航，不改变各页玩法脚本 */
(function () {
  var nav = document.querySelector('.nav');
  if (!nav) return;
  var current = location.pathname.split('/').pop() || 'index.html';
  var links = [
    ['首页', 'index.html'],
    ['排行榜', 'leaderboard.html'],
    ['商城', 'shop.html'],
    ['个人中心', 'profile.html']
  ];
  nav.innerHTML = '<a class="nav-logo" href="index.html">Game<span>Hub</span></a>' +
    '<div class="nav-tabs">' + links.map(function (item) {
      var active = item[1] === current ? ' active' : '';
      return '<a class="nav-tab' + active + '" href="' + item[1] + '">' + item[0] + '</a>';
    }).join('') + '</div>';
})();
