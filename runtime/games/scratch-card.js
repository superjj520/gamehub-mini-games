/**
 * 刮刮乐 — Canvas 刮卡效果
 * 参考: globalCompositeOperation='destination-out' 模式
 */
var ScratchCardGame = (function() {
  var _ctx = null, _canvas = null;

  function start(gameCtx) {
    _ctx = gameCtx;
    var container = gameCtx.container;
    container.innerHTML = '';

    var prizes = getPrizes(gameCtx);
    if (!prizes.length) prizes = [{title:'一等奖',weight:5},{title:'二等奖',weight:15},{title:'三等奖',weight:30},{title:'谢谢参与',weight:50}];

    // 随机选奖
    var total = 0;
    for (var i=0;i<prizes.length;i++) total+=prizes[i].weight||1;
    var r = Math.random()*total, acc=0, prize=prizes[prizes.length-1];
    for (var j=0;j<prizes.length;j++){ acc+=prizes[j].weight||1; if(r<=acc){prize=prizes[j];break;} }

    var wrap = document.createElement('div');
    wrap.style.cssText = 'position:relative;width:300px;height:200px;margin:20px auto;cursor:pointer;border-radius:12px;overflow:hidden;';
    container.appendChild(wrap);

    // 底层奖品文字
    var result = document.createElement('div');
    result.style.cssText = 'position:absolute;inset:0;display:flex;align-items:center;justify-content:center;background:linear-gradient(135deg,#7C3AED,#EC4899);font-size:18px;font-weight:700;color:#fff;text-align:center;padding:20px;';
    result.textContent = '🎉 '+prize.title;
    wrap.appendChild(result);

    // Canvas 刮层
    _canvas = document.createElement('canvas');
    _canvas.width = 300; _canvas.height = 200;
    _canvas.style.cssText = 'position:absolute;top:0;left:0;width:100%;height:100%;';
    wrap.appendChild(_canvas);

    var ctx2 = _canvas.getContext('2d');
    ctx2.fillStyle = '#C0C0C0';
    ctx2.fillRect(0,0,300,200);
    ctx2.fillStyle = '#AAA';
    ctx2.font = 'bold 16px sans-serif';
    ctx2.textAlign = 'center';
    ctx2.fillText('刮开此处',150,100);
    ctx2.font = '12px sans-serif';
    ctx2.fillText('用手指或鼠标刮开',150,130);

    var scratching = false, scratched = 0;

    function scratch(e){
      var rect = _canvas.getBoundingClientRect();
      var x = (e.clientX||e.touches[0].clientX)-rect.left;
      var y = (e.clientY||e.touches[0].clientY)-rect.top;
      ctx2.globalCompositeOperation = 'destination-out';
      ctx2.beginPath();
      ctx2.arc(x,y,25,0,Math.PI*2);
      ctx2.fill();
      scratched++;
      if(scratched > 30) checkReveal();
    }

    function checkReveal(){
      var data = ctx2.getImageData(0,0,300,200).data;
      var clear = 0;
      for(var i=3;i<data.length;i+=4){ if(data[i]===0) clear++; }
      if(clear/data.length*4 > 0.5){
        if(typeof confetti!=='undefined') confetti({particleCount:60,spread:50,origin:{y:.6},colors:['#F5C842','#EC4899','#7C3AED','#22C55E'],disableForReducedMotion:true});
        if(typeof KenneyAudio!=='undefined'){KenneyAudio.play('chipsCollide');setTimeout(function(){KenneyAudio.play('cardSlide');},120);}else SoundFX.play('win');
        try{navigator.vibrate(30);}catch(e){}
        if(_ctx&&_ctx.engine) _ctx.engine.emit('game:status','恭喜: '+prize.title);
      }
    }

    _canvas.addEventListener('mousedown',function(){scratching=true;});
    _canvas.addEventListener('mousemove',function(e){if(scratching)scratch(e);});
    _canvas.addEventListener('mouseup',function(){scratching=false;});
    _canvas.addEventListener('touchstart',function(e){scratching=true;scratch(e.touches[0]);});
    _canvas.addEventListener('touchmove',function(e){e.preventDefault();if(scratching)scratch(e.touches[0]);});
    _canvas.addEventListener('touchend',function(){scratching=false;});

    if(_ctx&&_ctx.engine) _ctx.engine.emit('game:ready',{game:'scratch-card'});
  }

  function getPrizes(ctx){
    var blocks = (ctx&&ctx.config&&ctx.config.blocks)||[];
    for(var i=0;i<blocks.length;i++){ if(blocks[i].type==='collection') return blocks[i].config.cards||[]; }
    return [];
  }

  function destroy(){ _ctx=null; _canvas=null; }
  return {start:start,destroy:destroy};
})();
