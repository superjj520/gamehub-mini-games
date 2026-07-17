/**
 * 大转盘 v4 — 成品级品质
 *
 * 视觉: 径向光晕背景 · Kenney皇冠图标 · 金属质感容器 · 指针弹跳+光晕
 * 动画: 入场缩放 · 转动时脉冲光 · 减速逐格音效同步 · 中奖段高亮
 * 音效: Kenney真实录音(骰子洗牌/掷骰/筹码碰撞) · ZzFX兜底
 * 粒子: canvas-confetti 中奖爆发
 * 震动: 三档强度
 * 文案: 大奖弹窗(全屏毛玻璃) · 小奖文字弹跳 · 鼓励文案
 */
var WheelGame = (function() {
  var _wheel = null, _ctx = null, _wrap = null, _btn = null, _result = null, _prizes = [];
  var _spinning = false, _tickCount = 0;

  function start(gameCtx) {
    _ctx = gameCtx;
    _prizes = getPrizes(gameCtx);
    if (!_prizes.length) _prizes = [
      {title:'iPhone 15 Pro',weight:3,icon:'📱'},
      {title:'AirPods Pro',weight:8,icon:'🎧'},
      {title:'星巴克礼品卡',weight:15,icon:'☕'},
      {title:'电影票两张',weight:18,icon:'🎬'},
      {title:'积分+500',weight:25,icon:'⭐'},
      {title:'谢谢参与',weight:31,icon:'💪'},
    ];

    var c = gameCtx.container;
    c.innerHTML = '';
    c.style.cssText = 'display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:100%;padding:20px 16px;position:relative;overflow:hidden;';

    // ── 背景光晕 ──
    var glow = document.createElement('div');
    glow.style.cssText = 'position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);' +
      'width:min(500px,100vw);height:min(500px,100vw);border-radius:50%;' +
      'background:radial-gradient(circle,rgba(124,58,237,0.12) 0%,rgba(245,158,11,0.06) 40%,transparent 70%);' +
      'pointer-events:none;animation:pulseGlow 3s ease-in-out infinite;';
    c.appendChild(glow);

    // ── 标题 ──
    var title = document.createElement('div');
    title.textContent = '幸运转盘';
    title.style.cssText = 'font-family:var(--font-display);font-size:28px;font-weight:900;margin-bottom:4px;' +
      'background:linear-gradient(135deg,#F5C842,#FDE68A,#F59E0B);-webkit-background-clip:text;-webkit-text-fill-color:transparent;';
    c.appendChild(title);

    var sub = document.createElement('div');
    sub.textContent = '转动转盘，赢取好礼';
    sub.style.cssText = 'font-size:13px;color:var(--text-tertiary);margin-bottom:24px;font-family:var(--font-display);';
    c.appendChild(sub);

    // ── 转盘容器 ──
    _wrap = document.createElement('div');
    _wrap.style.cssText = 'width:min(320px,78vw);height:min(320px,78vw);position:relative;' +
      'border-radius:50%;padding:8px;' +
      'background:radial-gradient(circle at 45% 35%,#4B3878,#1E1240 55%,#0D0620);' +
      'box-shadow:0 0 0 4px rgba(124,58,237,0.2),0 0 60px rgba(124,58,237,0.08),0 0 120px rgba(124,58,237,0.03),inset 0 2px 0 rgba(255,255,255,0.04);' +
      'animation:wheelEnter .6s var(--ease-bounce) both;';
    c.appendChild(_wrap);

    // ── 指针 ──
    var ptr = document.createElement('div');
    ptr.style.cssText = 'position:absolute;top:-12px;left:50%;transform:translateX(-50%);z-index:10;' +
      'width:0;height:0;border-left:15px solid transparent;border-right:15px solid transparent;' +
      'border-top:28px solid var(--gold);' +
      'filter:drop-shadow(0 3px 6px rgba(0,0,0,0.5))drop-shadow(0 0 10px rgba(245,200,66,0.5));' +
      'animation:pointerBounce 1s ease-in-out infinite;';
    _wrap.appendChild(ptr);

    // ── 转盘主体 ──
    var colors = ['#EF4444','#7C3AED','#22C55E','#F59E0B','#3B82F6','#EC4899','#F97316','#06B6D4','#84CC16','#6366F1','#E11D48','#8B5CF6'];
    var items = _prizes.map(function(p,i){ return {label:p.title||'奖品'+i,weight:p.weight||1,backgroundColor:colors[i%colors.length]}; });

    _wheel = new spinWheel.Wheel(_wrap, {
      items:items, radius:0.80, itemLabelRadius:0.66, itemLabelRadiusMax:0.32,
      itemLabelFontSizeMax:11, itemLabelColors:['#fff'], itemLabelStrokeColor:'rgba(0,0,0,0.6)',
      itemLabelStrokeWidth:1.5, lineColor:'rgba(255,255,255,0.15)', lineWidth:2,
      rotationSpeedMax:550, rotationResistance:-45,
      onRest: onWin,
      onSpin: onSpinStart,
      onCurrentIndexChange: onTick,
    });

    // ── 结果区 ──
    _result = document.createElement('div');
    _result.style.cssText = 'text-align:center;min-height:36px;margin-top:20px;font-family:var(--font-display);font-size:18px;font-weight:800;transition:all .3s var(--ease-bounce);';
    _result.textContent = '试试手气';
    _result.style.color = 'var(--text-tertiary)';
    c.appendChild(_result);

    // ── 按钮 ──
    _btn = document.createElement('button');
    _btn.textContent = '开始抽奖';
    _btn.style.cssText = 'display:block;margin:16px auto 0;padding:16px 56px;border:none;border-radius:var(--radius-full);' +
      'background:linear-gradient(180deg,#A855F7,#7C3AED 50%,#5B21B6);' +
      'color:#fff;font-family:var(--font-display);font-size:18px;font-weight:700;letter-spacing:.04em;' +
      'cursor:pointer;box-shadow:0 4px 24px rgba(124,58,237,.4),inset 0 1px 0 rgba(255,255,255,.12);' +
      'transition:all .15s var(--ease-out);min-height:56px;position:relative;overflow:hidden;' +
      '-webkit-tap-highlight-color:transparent;';
    _btn.addEventListener('mousedown',function(){this.style.transform='scale(.95)';});
    _btn.addEventListener('mouseup',function(){this.style.transform='scale(1)';});
    _btn.addEventListener('mouseleave',function(){this.style.transform='scale(1)';});
    _btn.addEventListener('touchstart',function(){this.style.transform='scale(.95)';Juice.vibrate('light');});
    _btn.addEventListener('touchend',function(){this.style.transform='scale(1)';});
    _btn.addEventListener('click',spin);
    // 光泽扫过
    var shine = document.createElement('div');
    shine.style.cssText = 'position:absolute;top:-60%;left:-70%;width:60%;height:220%;' +
      'background:linear-gradient(90deg,transparent,rgba(255,255,255,.06),transparent);' +
      'transform:skewX(-20deg);animation:btnShine 3s ease-in-out infinite;';
    _btn.appendChild(shine);
    c.appendChild(_btn);

    // ── 中奖弹窗 ──
    var modal = document.createElement('div');
    modal.id = 'winModal';
    modal.style.cssText = 'position:fixed;inset:0;z-index:1000;display:none;align-items:center;justify-content:center;' +
      'background:rgba(0,0,0,.75);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);';
    modal.innerHTML =
      '<div id="winCard" style="background:linear-gradient(160deg,#1E1A3A,#12122A);border:1px solid rgba(245,200,66,.25);border-radius:24px;padding:32px 28px;text-align:center;max-width:340px;width:88vw;box-shadow:0 12px 60px rgba(0,0,0,.6),0 0 80px rgba(245,200,66,.1);transform:scale(.8);transition:transform .3s var(--ease-bounce)">' +
      '<div id="winIcon" style="font-size:64px;margin-bottom:12px"></div>' +
      '<div id="winTitle" style="font-family:var(--font-display);font-size:16px;font-weight:700;color:var(--text-secondary);margin-bottom:4px">恭喜获得</div>' +
      '<div id="winPrize" style="font-family:var(--font-display);font-size:28px;font-weight:900;margin-bottom:24px;background:linear-gradient(135deg,var(--gold),var(--gold-light));-webkit-background-clip:text;-webkit-text-fill-color:transparent"></div>' +
      '<button id="winAgain" class="btn btn-primary" style="width:100%;margin-bottom:8px;font-size:16px">再抽一次</button>' +
      '<button id="winClose" class="btn btn-ghost" style="width:100%;font-size:13px">关闭</button></div>';
    c.appendChild(modal);
    modal.querySelector('#winAgain').addEventListener('click',function(){closeModal();spin();});
    modal.querySelector('#winClose').addEventListener('click',closeModal);

    // CSS 关键帧
    injectStyles();

    if (_ctx&&_ctx.engine) _ctx.engine.emit('game:ready',{game:'wheel'});
  }

  // ═══ 事件处理 ═══
  function onSpinStart() {
    _spinning = true; _tickCount = 0;
    if (typeof KenneyAudio !== 'undefined') KenneyAudio.play('diceShuffle');
    else SoundFX.play('spin');
  }

  function onTick(e) {
    if (!_spinning) return;
    _tickCount++;
    // 每切换5个扇区播放一次音效(模拟指针哒哒声)
    if (_tickCount % 5 === 0) {
      SoundFX.play('tick');
    }
  }

  function onWin(e) {
    _spinning = false;
    var prize = _prizes[e.currentIndex];
    if (!prize) prize = {title:'?',icon:'🎁'};
    var isBig = (prize.weight || 10) <= 8;

    // 粒子
    Particles.fire(isBig?'confetti':'burst',{count:isBig?150:60, y:0.45});

    // 音效: Kenney 优先
    if (typeof KenneyAudio !== 'undefined') {
      KenneyAudio.play('chipsCollide');
      setTimeout(function(){ KenneyAudio.play('diceThrow'); }, 120);
    } else {
      SoundFX.play(isBig?'win_all':'win');
    }

    // 震动
    Juice.vibrate(isBig?'win':'medium');

    // 大/小奖差异化反馈
    if (isBig) {
      showModal(prize);
      _result.textContent = '';
      _result.style.color = 'var(--text-tertiary)';
    } else {
      var texts = ['手气不错!','运气来啦!','恭喜!','好棒!'];
      _result.textContent = texts[Math.floor(Math.random()*texts.length)]+' '+prize.title;
      _result.style.color = 'var(--gold)';
      _result.style.transform='scale(0)';_result.style.opacity='0';
      requestAnimationFrame(function(){_result.style.transform='scale(1)';_result.style.opacity='1';});
    }

    if (_btn && !isBig) { _btn.textContent='再抽一次';_btn.disabled=false; }

    if (_ctx&&_ctx.engine){
      _ctx.engine.emit('game:status',prize.title);
      _ctx.engine.emit('wheel:result',{index:e.currentIndex,prize:prize});
    }
  }

  // ═══ 弹窗 ═══
  function showModal(prize) {
    var m=document.getElementById('winModal'),c=document.getElementById('winCard');
    if(!m)return;
    document.getElementById('winIcon').textContent=prize.icon||'🎁';
    document.getElementById('winPrize').textContent=prize.title;
    m.style.display='flex';
    requestAnimationFrame(function(){c.style.transform='scale(1)';});
    Particles.fire('stars',{count:40,y:.3});
    if(_btn){_btn.textContent='再抽一次';_btn.disabled=false;}
  }

  function closeModal(){
    var m=document.getElementById('winModal'),c=document.getElementById('winCard');
    if(!m)return;c.style.transform='scale(.8)';setTimeout(function(){m.style.display='none';},250);
  }

  // ═══ 抽奖 ═══
  function spin(){
    if(!_wheel||_spinning)return;
    if(_btn){_btn.textContent='转动中...';_btn.disabled=true;}
    if(_result){_result.textContent='';_result.style.color='var(--text-tertiary)';}
    SoundFX.play('click');
    Juice.vibrate('light');
    _wheel.spin();
    if(_ctx&&_ctx.engine)_ctx.engine.emit('game:status','转动中...');
  }

  // ═══ CSS ═══
  function injectStyles(){
    if(document.getElementById('wheelV4Styles'))return;
    var s=document.createElement('style');s.id='wheelV4Styles';
    s.textContent=
      '@keyframes wheelEnter{from{opacity:0;transform:scale(.8)}to{opacity:1;transform:scale(1)}}'+
      '@keyframes pulseGlow{0%,100%{opacity:.6;transform:translate(-50%,-50%) scale(1)}50%{opacity:1;transform:translate(-50%,-50%) scale(1.08)}}'+
      '@keyframes pointerBounce{0%,100%{transform:translateX(-50%) translateY(0)}50%{transform:translateX(-50%) translateY(5px)}}'+
      '@keyframes btnShine{0%{left:-70%}60%{left:130%}100%{left:130%}}';
    document.head.appendChild(s);
  }

  function getPrizes(ctx){
    var blocks=(ctx&&ctx.config&&ctx.config.blocks)||[];
    for(var i=0;i<blocks.length;i++){if(blocks[i].type==='collection')return blocks[i].config.cards||[];}
    return[];
  }

  function destroy(){if(_wheel){_wheel.remove();_wheel=null;}_ctx=null;_wrap=null;_btn=null;_result=null;}

  return{start:start,spin:spin,destroy:destroy};
})();
