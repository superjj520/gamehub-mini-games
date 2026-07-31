(function () {
  GameHubLegacyAdapter.mount({ id:'fruit-cut', page:'fruit-cut', meta:{ name:'切水果', category:'反应', accent:'#FF6078' }, handleAction:function (action) { if (action === 'start' && typeof startGame === 'function') startGame(); } });
}());
