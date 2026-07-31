(function () {
  GameHubLegacyAdapter.mount({ id:'minesweeper', page:'minesweeper', meta:{ name:'扫雷', category:'益智', accent:'#FF6078' }, handleAction:function (action) { if (action === 'start' && typeof restartGame === 'function') restartGame(); } });
}());
