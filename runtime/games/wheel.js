/**
 * 大转盘 — spin-wheel + GameJuice 品质效果
 * 粒子彩带 · 程序化音效 · 触觉震动 · 弹性动画
 */
var WheelGame = (function() {
  var _wheel = null, _ctx = null, _wrap = null, _btnEl = null, _resultEl = null;

  function start(gameCtx) {
    _ctx = gameCtx;
    var prizes = getPrizes(gameCtx);
    if (!prizes.length) prizes = [{title:'一等奖',weight:5},{title:'二等奖',weight:10},{title:'三等奖',weight:20},{title:'谢谢参与',weight:65}];

    var container = gameCtx.container;
    container.innerHTML = '';

    _resultEl = document.createElement('div');
    _resultEl.style.cssText = 'text-align:center;font-size:18px;font-weight:700;color:var(--gold,#F5C842);min-height:30px;margin-bottom:12px;transition:all 0.3s';
    container.appendChild(_resultEl);

    _wrap = document.createElement('div');
    _wrap.style.cssText = 'width:min(320px,85vw);height:min(320px,85vw);margin:0 auto;position:relative;';
    container.appendChild(_wrap);

    // 指针
    var pointer = document.createElement('div');
    pointer.style.cssText = 'position:absolute;top:-12px;left:50%;transform:translateX(-50%);width:0;height:0;border-left:12px solid transparent;border-right:12px solid transparent;border-top:20px solid var(--gold,#F5C842);z-index:10;filter:drop-shadow(0 2px 4px rgba(0,0,0,.3));animation:pointerBounce 1s ease-in-out infinite;';
    _wrap.appendChild(pointer);

    var colors = ['#7C3AED','#EC4899','#F59E0B','#22C55E','#3B82F6','#EF4444','#8B5CF6','#F97316','#06B6D4','#84CC16','#E11D48','#6366F1'];
    var items = prizes.map(function(p,i){ return {label:p.title||'奖品'+i,weight:p.weight||1,backgroundColor:colors[i%colors.length]}; });

    _wheel = new spinWheel.Wheel(_wrap, {
      items:items, radius:0.88, itemLabelRadius:0.72, itemLabelRadiusMax:0.36,
      itemLabelFontSizeMax:12, itemLabelColors:['#fff'], itemLabelStrokeColor:'#000',
      itemLabelStrokeWidth:1, lineColor:'rgba(0,0,0,0.3)', lineWidth:1,
      rotationSpeedMax:500, rotationResistance:-55,
      onRest: onWin,
      onSpin: function(){ SoundFX.play('spin'); }
    });

    // 复用外部按钮或创建新按钮
    _btnEl = document.getElementById('spinBtn') || document.getElementById('btnRoll');
    if (_btnEl) {
      _btnEl.textContent = '🎡 开始抽奖';
      _btnEl.style.cssText = 'display:block;margin:20px auto 0;padding:14px 40px;border:none;border-radius:14px;'+
        'background:linear-gradient(135deg,#7C3AED,#EC4899);color:#fff;font-size:16px;font-weight:700;'+
        'cursor:pointer;box-shadow:0 4px 16px rgba(124,58,237,.4);transition:all .15s;width:auto;min-height:44px;';
      _btnEl.onclick = function(){ spin(); SoundFX.play('click'); Juice.vibrate('light'); };
    } else {
      _btnEl = document.createElement('button');
      _btnEl.textContent = '🎡 开始抽奖';
      _btnEl.style.cssText = 'display:block;margin:20px auto 0;padding:14px 40px;border:none;border-radius:14px;'+
        'background:linear-gradient(135deg,#7C3AED,#EC4899);color:#fff;font-size:16px;font-weight:700;'+
        'cursor:pointer;box-shadow:0 4px 16px rgba(124,58,237,.4);transition:all .15s;width:auto;';
      _btnEl.addEventListener('click', function(){ spin(); SoundFX.play('click'); Juice.vibrate('light'); });
      container.appendChild(_btnEl);
    }
    _btnEl.addEventListener('mousedown',function(){ Juice.pressDown(_btnEl); });
    _btnEl.addEventListener('mouseup',function(){ Juice.pressUp(_btnEl); });
    _btnEl.addEventListener('mouseleave',function(){ Juice.pressUp(_btnEl); });
    _btnEl.addEventListener('touchstart',function(){ Juice.pressDown(_btnEl); });
    _btnEl.addEventListener('touchend',function(){ Juice.pressUp(_btnEl); });

    if (_ctx&&_ctx.engine) _ctx.engine.emit('game:ready',{game:'wheel'});
  }

  function onWin(e) {
    var prize = (getPrizes(_ctx)||[])[e.currentIndex];
    if (!prize) prize = {title:'?'};

    // 粒子彩带
    Particles.confetti(_wrap.parentElement, {count:80, colors:['#F5C842','#EC4899','#7C3AED','#22C55E','#F97316']});

    // 音效
    SoundFX.play('win');

    // 震动
    Juice.vibrate('win');

    // 结果显示
    if (_resultEl) {
      _resultEl.textContent = '🎉 ' + prize.title;
      Juice.popIn(_resultEl);
      Juice.bounce(_resultEl, 1.2);
    }

    // 按钮复位
    if (_btnEl) { _btnEl.textContent = '🎡 再抽一次'; _btnEl.disabled = false; }

    if (_ctx&&_ctx.engine) {
      _ctx.engine.emit('game:status','🎉 恭喜获得: '+(prize.title||'?'));
      _ctx.engine.emit('wheel:result',{index:e.currentIndex,prize:prize});
    }
  }

  function spin() {
    if (!_wheel) return;
    if (_btnEl) { _btnEl.textContent = '🎡 转动中...'; _btnEl.disabled = true; }
    if (_resultEl) _resultEl.textContent = '';
    _wheel.spin();
    if (_ctx&&_ctx.engine) _ctx.engine.emit('game:status','🎡 转盘转动中...');
  }

  function getPrizes(ctx){
    var blocks = (ctx&&ctx.config&&ctx.config.blocks)||[];
    for (var i=0;i<blocks.length;i++){ if(blocks[i].type==='collection') return blocks[i].config.cards||[]; }
    return [];
  }

  function destroy(){
    if(_wheel){_wheel.remove();_wheel=null;}
    _ctx=null; _wrap=null; _btnEl=null; _resultEl=null;
  }

  return {start:start,spin:spin,destroy:destroy};
})();
