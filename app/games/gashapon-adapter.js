(function () {
  GameHubLegacyAdapter.mount({ id:'gashapon', page:'gashapon', meta:{ name:'扭蛋机', category:'抽奖', accent:'#47F1D0' }, handleAction:function (action) { if (action === 'start' && typeof spin === 'function') spin(1); } });
}());
