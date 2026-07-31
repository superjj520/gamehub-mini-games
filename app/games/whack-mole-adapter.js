(function () {
  GameHubLegacyAdapter.mount({ id:'whack-mole', page:'whack-mole', meta:{ name:'打地鼠', category:'反应', accent:'#FFD166' }, handleAction:function (action) { if (action === 'start' && typeof startGame === 'function') startGame(); } });
}());
