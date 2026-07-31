(function () {
  GameHubLegacyAdapter.mount({ id:'scratch-card', page:'scratch-card', meta:{ name:'刮刮乐', category:'抽奖', accent:'#F59E0B' }, handleAction:function (action) { if (action === 'start' && typeof resetCard === 'function') resetCard(); } });
}());
