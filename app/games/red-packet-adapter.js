(function () {
  GameHubLegacyAdapter.mount({ id:'red-packet-rain', page:'red-packet-rain', meta:{ name:'红包雨', category:'反应', accent:'#47F1D0' }, handleAction:function (action) { if (action === 'start' && typeof startGame === 'function') startGame(); } });
}());
