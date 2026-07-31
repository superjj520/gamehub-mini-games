(function () {
  GameHubLegacyAdapter.mount({ id:'lottery-ball', page:'lottery-ball', meta:{ name:'双色球', category:'抽奖', accent:'#FF6078' }, handleAction:function (action) { if (action === 'start' && typeof handleStart === 'function') handleStart(); } });
}());
