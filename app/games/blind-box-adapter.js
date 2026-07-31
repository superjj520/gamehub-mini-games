(function () {
  GameHubLegacyAdapter.mount({ id:'blind-box', page:'blind-box', meta:{ name:'盲盒', category:'抽奖', accent:'#8E7DFF' }, handleAction:function (action) { if (action === 'start' && typeof draw === 'function') draw(1); } });
}());
