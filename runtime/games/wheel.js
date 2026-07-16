/**
 * 大转盘 — 基于开源组件 spin-wheel (348★, MIT)
 * https://github.com/CrazyTim/spin-wheel
 *
 * 集成: CDN IIFE → 全局 spinWheel
 */
var WheelGame = (function() {
  var _wheel = null, _ctx = null;

  function start(gameCtx) {
    _ctx = gameCtx;
    var prizes = getPrizes(gameCtx);
    if (prizes.length === 0) { prizes = [{title:'一等奖',weight:5},{title:'二等奖',weight:10},{title:'三等奖',weight:20},{title:'谢谢参与',weight:65}]; }

    var container = gameCtx.container;
    container.innerHTML = '';

    var wrap = document.createElement('div');
    wrap.style.cssText = 'width:min(340px,90vw);height:min(340px,90vw);margin:0 auto;';
    container.appendChild(wrap);

    var colors = ['#7C3AED','#EC4899','#F59E0B','#22C55E','#3B82F6','#EF4444','#8B5CF6','#F97316','#06B6D4','#84CC16','#E11D48','#6366F1'];
    var items = prizes.map(function(p, i){ return {label:p.title||'奖品'+i,weight:p.weight||1,backgroundColor:colors[i%colors.length]}; });

    _wheel = new spinWheel.Wheel(wrap, {
      items:items, radius:0.88, itemLabelRadius:0.75, itemLabelRadiusMax:0.38,
      itemLabelFontSizeMax:13, itemLabelColors:['#fff'], itemLabelStrokeColor:'#000',
      itemLabelStrokeWidth:1, lineColor:'rgba(0,0,0,0.3)', lineWidth:1,
      rotationSpeedMax:500, rotationResistance:-60,
      onRest: function(e) {
        var prize = prizes[e.currentIndex];
        if (_ctx && _ctx.engine) { _ctx.engine.emit('game:status','🎉 恭喜: '+(prize?prize.title:'?')); _ctx.engine.emit('wheel:result',{index:e.currentIndex,prize:prize}); }
      },
    });

    if (_ctx.engine) _ctx.engine.emit('game:ready',{game:'wheel'});
  }

  function spin() {
    if (_wheel) { _wheel.spin(); if (_ctx&&_ctx.engine) _ctx.engine.emit('game:status','🎡 转动中...'); }
  }

  function getPrizes(ctx) {
    var blocks = (ctx&&ctx.config&&ctx.config.blocks)||[];
    for (var i=0;i<blocks.length;i++){ var b=blocks[i]; if(b.type==='collection'&&b.label.indexOf('奖')>=0) return b.config.cards||[]; }
    return [];
  }

  function destroy() { if(_wheel){_wheel.remove();_wheel=null;} _ctx=null; }

  return {start:start,spin:spin,destroy:destroy};
})();
