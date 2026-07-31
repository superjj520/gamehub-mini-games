(function () {
  GameHubLegacyAdapter.mount({ id:'pinball', page:'pinball', meta:{ name:'弹球', category:'动作', accent:'#FFD166' }, handleAction:function (action) { if (action === 'start' && typeof startGame === 'function') startGame(); } });
}());
