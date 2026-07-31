(function () {
  GameHubLegacyAdapter.mount({ id:'slingshot', page:'slingshot', meta:{ name:'弹弓', category:'动作', accent:'#FF6078' }, handleAction:function (action) { if (action === 'start' && typeof startGame === 'function') startGame(); } });
}());
