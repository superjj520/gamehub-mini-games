(function () {
  GameHubLegacyAdapter.mount({ id:'jump-game', page:'jump-game', meta:{ name:'跳一跳', category:'动作', accent:'#47F1D0' }, handleAction:function (action) { if (action === 'start' && typeof startGame === 'function') startGame(); } });
}());
