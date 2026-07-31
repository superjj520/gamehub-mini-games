(function () {
  GameHubLegacyAdapter.mount({ id:'nine-grid', page:'nine-grid', meta:{ name:'九宫格', category:'抽奖', accent:'#8E7DFF' }, handleAction:function (action) { if (action === 'start' && typeof startSpin === 'function') startSpin(); } });
}());
