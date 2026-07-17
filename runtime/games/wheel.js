/**
 * 大转盘 v3 — 开源组件品质版
 * 视觉: CSS金属质感+光泽动画+指针弹跳+弹性按钮
 * 粒子: canvas-confetti (开源)
 * 音效: ZzFX 程序化合成 (MIT)
 * 震动: Navigator.vibrate API
 */
var WheelGame = (function() {
  var _wheel = null, _ctx = null, _wrap = null, _btnEl = null, _resultEl = null, _prizes = [];

  function start(gameCtx) {
    _ctx = gameCtx;
    _prizes = getPrizes(gameCtx);
    if (!_prizes.length) _prizes = [{title:'一等奖',weight:5},{title:'二等奖',weight:10},{title:'三等奖',weight:20},{title:'谢谢参与',weight:65}];

    var container = gameCtx.container;
    container.innerHTML = '';

    // ── 结果展示区 ──
    _resultEl = document.createElement('div');
    _resultEl.style.cssText = 'text-align:center;font-size:20px;font-weight:800;color:var(--gold);min-height:36px;margin-bottom:16px;font-family:var(--font-display);transition:all .3s var(--ease-bounce)';
    container.appendChild(_resultEl);

    // ── 转盘容器 (金属质感) ──
    _wrap = document.createElement('div');
    _wrap.style.cssText = 'width:min(320px,80vw);height:min(320px,80vw);margin:0 auto;position:relative;' +
      'border-radius:50%;padding:6px;' +
      'background:radial-gradient(circle at 50% 40%,#3B2F5A,#1A1030 60%,#0D0620);' +
      'box-shadow:0 0 0 3px rgba(124,58,237,0.25),0 0 40px rgba(124,58,237,0.1),inset 0 2px 0 rgba(255,255,255,0.06);';
    container.appendChild(_wrap);

    // ── 指针 (三角形+阴影+弹跳) ──
    var pointer = document.createElement('div');
    pointer.style.cssText = 'position:absolute;top:-10px;left:50%;transform:translateX(-50%);z-index:10;' +
      'width:0;height:0;border-left:14px solid transparent;border-right:14px solid transparent;' +
      'border-top:26px solid var(--gold);' +
      'filter:drop-shadow(0 2px 6px rgba(0,0,0,0.4))drop-shadow(0 0 8px rgba(245,200,66,0.4));' +
      'animation:pointerBounce 1.2s ease-in-out infinite;';
    _wrap.appendChild(pointer);

    // ── 中心装饰圆 ──
    var center = document.createElement('div');
    center.style.cssText = 'position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);z-index:11;pointer-events:none;' +
      'width:60px;height:60px;border-radius:50%;' +
      'background:radial-gradient(circle at 40% 35%,#FDE68A,#F5C842 40%,#B8860B);' +
      'box-shadow:0 0 20px rgba(245,200,66,0.4),inset 0 2px 3px rgba(255,255,255,0.3);' +
      'display:flex;align-items:center;justify-content:center;font-size:22px;';
    center.textContent = '⭐';
    _wrap.appendChild(center);

    // ── 转盘主体 (spin-wheel) ──
    var colors = ['#EF4444','#7C3AED','#22C55E','#F59E0B','#3B82F6','#EC4899','#F97316','#06B6D4','#84CC16','#6366F1','#E11D48','#8B5CF6'];
    var items = _prizes.map(function(p,i){ return {label:p.title||'奖品'+i,weight:p.weight||1,backgroundColor:colors[i%colors.length]}; });

    _wheel = new spinWheel.Wheel(_wrap, {
      items:items, radius:0.82, itemLabelRadius:0.68, itemLabelRadiusMax:0.34,
      itemLabelFontSizeMax:11, itemLabelColors:['#fff'], itemLabelStrokeColor:'rgba(0,0,0,0.5)',
      itemLabelStrokeWidth:1, lineColor:'rgba(255,255,255,0.2)', lineWidth:1.5,
      rotationSpeedMax:500, rotationResistance:-50,
      onRest: onWin,
      onSpin: function(){ SoundFX.play('spin'); }
    });

    // ── 中奖弹窗容器 ──
    var modal = document.createElement('div');
    modal.id = 'winModal';
    modal.style.cssText = 'position:fixed;inset:0;z-index:1000;display:none;align-items:center;justify-content:center;' +
      'background:rgba(0,0,0,0.7);backdrop-filter:blur(4px);-webkit-backdrop-filter:blur(4px);';
    modal.innerHTML = '<div id="winCard" style="background:linear-gradient(160deg,#1E1A3A,#12122A);border:1px solid rgba(245,200,66,0.3);border-radius:var(--radius-xl);padding:var(--space-8);text-align:center;max-width:320px;width:90vw;box-shadow:0 8px 48px rgba(0,0,0,0.6),0 0 60px rgba(245,200,66,0.15);transform:scale(0.8);transition:transform .3s var(--ease-bounce)">' +
      '<div id="winIcon" style="font-size:56px;margin-bottom:var(--space-3)">🎁</div>' +
      '<div id="winTitle" style="font-family:var(--font-display);font-size:18px;font-weight:800;margin-bottom:var(--space-2);background:linear-gradient(135deg,var(--gold),var(--gold-light));-webkit-background-clip:text;-webkit-text-fill-color:transparent">恭喜获得</div>' +
      '<div id="winPrize" style="font-family:var(--font-display);font-size:26px;font-weight:900;margin-bottom:var(--space-6);color:var(--text-white)"></div>' +
      '<button id="winCloseBtn" class="btn btn-primary" style="width:100%;margin-bottom:var(--space-2)">🎡 再抽一次</button>' +
      '<button id="winDismissBtn" class="btn btn-ghost" style="width:100%;font-size:13px">关闭</button>' +
      '</div>';
    container.appendChild(modal);
    modal.querySelector('#winCloseBtn').addEventListener('click', function(){ closeModal(); spin(); });
    modal.querySelector('#winDismissBtn').addEventListener('click', closeModal);

    // ── 按钮 (光泽质感) ──
    _btnEl = document.createElement('button');
    _btnEl.textContent = '开始抽奖';
    _btnEl.style.cssText = 'display:block;margin:24px auto 0;padding:14px 48px;border:none;border-radius:var(--radius-full);' +
      'background:linear-gradient(180deg,#A855F7,#7C3AED 50%,#5B21B6);' +
      'color:#fff;font-family:var(--font-display);font-size:17px;font-weight:700;letter-spacing:0.02em;' +
      'cursor:pointer;box-shadow:0 4px 20px rgba(124,58,237,0.4),inset 0 1px 0 rgba(255,255,255,0.15);' +
      'transition:all var(--duration-fast) var(--ease-out);min-height:52px;' +
      '-webkit-tap-highlight-color:transparent;position:relative;overflow:hidden;';
    _btnEl.addEventListener('mousedown',function(){ this.style.transform='scale(0.96)'; });
    _btnEl.addEventListener('mouseup',function(){ this.style.transform='scale(1)'; });
    _btnEl.addEventListener('mouseleave',function(){ this.style.transform='scale(1)'; });
    _btnEl.addEventListener('touchstart',function(){ this.style.transform='scale(0.96)'; Juice.vibrate('light'); });
    _btnEl.addEventListener('touchend',function(){ this.style.transform='scale(1)'; });
    _btnEl.addEventListener('click',function(){ spin(); SoundFX.play('click'); });
    // 光泽扫过动画
    var shine = document.createElement('div');
    shine.style.cssText = 'position:absolute;top:-50%;left:-60%;width:60%;height:200%;' +
      'background:linear-gradient(90deg,transparent,rgba(255,255,255,0.08),transparent);' +
      'transform:skewX(-20deg);animation:btnShine 3s ease-in-out infinite;';
    _btnEl.appendChild(shine);
    container.appendChild(_btnEl);

    addShineKeyframe();
    if (_ctx&&_ctx.engine) _ctx.engine.emit('game:ready',{game:'wheel'});
  }

  // ── 光泽动画 ──
  function addShineKeyframe() {
    if (document.getElementById('btnShineStyle')) return;
    var s = document.createElement('style');
    s.id = 'btnShineStyle';
    s.textContent = '@keyframes btnShine{0%{left:-60%}50%{left:120%}100%{left:120%}}';
    document.head.appendChild(s);
  }

  // ── 中奖处理 ──
  function onWin(e) {
    var prize = _prizes[e.currentIndex];
    if (!prize) prize = {title:'?'};
    var isBig = prize.weight <= 10;

    // 粒子
    Particles.fire(isBig ? 'confetti' : 'burst', {count: isBig ? 120 : 50, colors: isBig ? undefined : ['#F5C842','#F59E0B']});

    // 音效
    SoundFX.play(isBig ? 'win_all' : 'win');

    // 震动
    Juice.vibrate(isBig ? 'win' : 'medium');

    // 结果文字
    if (_resultEl) {
      var texts = ['太棒了!','运气爆棚!','恭喜!','厉害!','好运来!'];
      _resultEl.textContent = texts[Math.floor(Math.random()*texts.length)] + ' ' + prize.title;
      _resultEl.style.transform = 'scale(0)'; _resultEl.style.opacity = '0';
      requestAnimationFrame(function(){ _resultEl.style.transform='scale(1)'; _resultEl.style.opacity='1'; });
    }

    // 弹窗
    if (isBig) showModal(prize);

    // 按钮
    if (_btnEl && !isBig) { _btnEl.textContent = '再抽一次'; _btnEl.disabled = false; }

    if (_ctx&&_ctx.engine) {
      _ctx.engine.emit('game:status', '恭喜获得: ' + (prize.title || '?'));
      _ctx.engine.emit('wheel:result', {index:e.currentIndex, prize:prize});
    }
  }

  function showModal(prize) {
    var modal = document.getElementById('winModal');
    var card = document.getElementById('winCard');
    if (!modal) return;
    document.getElementById('winPrize').textContent = prize.title;
    modal.style.display = 'flex';
    requestAnimationFrame(function(){ card.style.transform = 'scale(1)'; });
    Particles.fire('stars', {count: 30, y: 0.3});
    SoundFX.play('win_all');
    if (_btnEl) { _btnEl.textContent = '再抽一次'; _btnEl.disabled = false; }
  }

  function closeModal() {
    var modal = document.getElementById('winModal');
    var card = document.getElementById('winCard');
    if (!modal) return;
    card.style.transform = 'scale(0.8)';
    setTimeout(function(){ modal.style.display = 'none'; }, 250);
  }

  // ── 抽奖 ──
  function spin() {
    if (!_wheel) return;
    if (_btnEl) { _btnEl.textContent = '转动中...'; _btnEl.disabled = true; }
    if (_resultEl) _resultEl.textContent = '';
    SoundFX.play('spin');
    Juice.vibrate('light');
    _wheel.spin();
    if (_ctx&&_ctx.engine) _ctx.engine.emit('game:status', '转盘转动中...');
  }

  function getPrizes(ctx){
    var blocks = (ctx&&ctx.config&&ctx.config.blocks)||[];
    for (var i=0;i<blocks.length;i++){ if(blocks[i].type==='collection') return blocks[i].config.cards||[]; }
    return [];
  }

  function destroy(){
    if(_wheel){_wheel.remove();_wheel=null;}
    _ctx=null;_wrap=null;_btnEl=null;_resultEl=null;
  }

  return {start:start,spin:spin,destroy:destroy};
})();
