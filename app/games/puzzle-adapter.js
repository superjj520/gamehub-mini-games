(function () {
  GameHubLegacyAdapter.mount({ id:'puzzle', page:'puzzle', meta:{ name:'拼图', category:'益智', accent:'#8E7DFF' }, handleAction:function (action) { if (action === 'start' && typeof startGame === 'function') startGame(); } });
}());
