(function () {
  GameHubLegacyAdapter.mount({ id:'catch-coins', page:'catch-coins', meta:{ name:'接金币', category:'反应', accent:'#47F1D0' }, handleAction:function (action) { if (action === 'start' && typeof startGame === 'function') startGame(); } });
}());
