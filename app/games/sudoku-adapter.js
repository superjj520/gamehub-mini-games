(function () {
  GameHubLegacyAdapter.mount({ id:'sudoku', page:'sudoku', meta:{ name:'数独', category:'益智', accent:'#47F1D0' }, handleAction:function (action) { if (action === 'start' && typeof startNewGame === 'function') startNewGame(); } });
}());
