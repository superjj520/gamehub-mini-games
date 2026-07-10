/**
 * 大转盘 — Canvas 绘制旋转抽奖
 * 依赖：CollectionManager, RuleEngine, ThemeRenderer
 */
const WheelGame = (() => {
  var ctx = null, state = null, canvas = null, spinning = false;

  function start(gameCtx) {
    ctx = gameCtx;
    var collBlock = findBlock('collection');
    var prizes = collBlock ? (collBlock.config.cards || []) : [
      { id: 'p1', title: '一等奖', weight: 5 },
      { id: 'p2', title: '二等奖', weight: 15 },
      { id: 'p3', title: '三等奖', weight: 30 },
      { id: 'p4', title: '谢谢参与', weight: 50 },
    ];

    state = { prizes: prizes, angle: 0, result: null, spinning: false };
    canvas = document.createElement('canvas');
    canvas.width = 380; canvas.height = 380;
    canvas.style.cssText = 'display:block;margin:0 auto;max-width:100%;';
    ctx.container.appendChild(canvas);
    drawWheel(0);
    addSpinButton();
  }

  function addSpinButton() {
    var btn = document.createElement('button');
    btn.textContent = '🎡 开始抽奖';
    btn.style.cssText = 'display:block;margin:16px auto;padding:12px 32px;border-radius:10px;border:none;background:linear-gradient(135deg,var(--accent),var(--accent2));color:white;font-size:16px;font-weight:700;cursor:pointer;font-family:inherit;';
    btn.onclick = spin;
    ctx.container.appendChild(btn);
    state.btnEl = btn;
  }

  function spin() {
    if (state.spinning) return;
    state.spinning = true;
    state.btnEl.disabled = true;
    var collBlock = findBlock('collection');
    var result = CollectionManager.draw(collBlock ? collBlock.config : { cards: state.prizes, drawMode: 'weighted' });
    var prize = (result && result.card) ? result.card : state.prizes[state.prizes.length - 1];
    var targetIndex = state.prizes.findIndex(function(p) { return p.id === prize.id; });
    var total = state.prizes.length;
    var segAngle = 360 / total;
    // 计算目标角度：指向该扇区中间 + 多转几圈
    var targetAngle = 360 * 5 + (360 - targetIndex * segAngle - segAngle / 2);
    var startAngle = state.angle;
    var startTime = Date.now();
    var duration = 4000;

    function anim() {
      var elapsed = Date.now() - startTime;
      var progress = Math.min(elapsed / duration, 1);
      // easeOutCubic
      var eased = 1 - Math.pow(1 - progress, 3);
      var currentAngle = startAngle + targetAngle * eased;
      drawWheel(currentAngle);
      if (progress < 1) {
        requestAnimationFrame(anim);
      } else {
        state.angle = currentAngle;
        state.result = prize;
        state.spinning = false;
        state.btnEl.disabled = false;
        emitStatus('🎉 ' + prize.title + '！');
        emitState();
      }
    }
    requestAnimationFrame(anim);
  }

  function drawWheel(angle) {
    var cvs = canvas;
    var w = cvs.width, h = cvs.height, cx = w/2, cy = h/2, r = 160;
    var ctx2 = cvs.getContext('2d');
    ctx2.clearRect(0, 0, w, h);
    var prizes = state.prizes;
    var total = prizes.length;
    var segAngle = (2 * Math.PI) / total;
    var radAngle = angle * Math.PI / 180;

    var colors = ['#7C3AED', '#EC4899', '#F5C842', '#22C55E', '#3B82F6', '#F97316', '#06B6D4', '#EF4444'];

    for (var i = 0; i < total; i++) {
      var startA = radAngle + i * segAngle;
      var endA = startA + segAngle;
      ctx2.beginPath();
      ctx2.moveTo(cx, cy);
      ctx2.arc(cx, cy, r, startA, endA);
      ctx2.closePath();
      ctx2.fillStyle = colors[i % colors.length];
      ctx2.fill();
      ctx2.strokeStyle = '#1A0A2E';
      ctx2.lineWidth = 2;
      ctx2.stroke();

      // 文字
      ctx2.save();
      ctx2.translate(cx, cy);
      ctx2.rotate(startA + segAngle / 2);
      ctx2.textAlign = 'right';
      ctx2.fillStyle = '#1A0A2E';
      ctx2.font = 'bold 12px "PingFang SC","Microsoft YaHei",sans-serif';
      var txt = prizes[i].title || '';
      if (txt.length > 4) txt = txt.slice(0, 4) + '..';
      ctx2.fillText(txt, r - 8, 4);
      ctx2.restore();
    }

    // 中心圆
    ctx2.beginPath();
    ctx2.arc(cx, cy, 30, 0, 2 * Math.PI);
    ctx2.fillStyle = '#1A0A2E';
    ctx2.fill();
    ctx2.strokeStyle = 'var(--gold)';
    ctx2.lineWidth = 3;
    ctx2.stroke();
    ctx2.fillStyle = 'var(--gold)';
    ctx2.font = 'bold 14px "PingFang SC","Microsoft YaHei",sans-serif';
    ctx2.textAlign = 'center';
    ctx2.textBaseline = 'middle';
    ctx2.fillText('GO', cx, cy);

    // 指针
    ctx2.beginPath();
    ctx2.moveTo(cx - 8, cy - r - 10);
    ctx2.lineTo(cx + 8, cy - r - 10);
    ctx2.lineTo(cx, cy - r + 15);
    ctx2.closePath();
    ctx2.fillStyle = 'var(--gold)';
    ctx2.fill();
  }

  function findBlock(type) {
    var blocks = ctx.config.blocks || [];
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].type === type) return blocks[i];
    }
    return null;
  }

  function emitState() { if (ctx && ctx.engine) ctx.engine.emit('game:state', state); }
  function emitStatus(msg) { if (ctx && ctx.engine) ctx.engine.emit('game:status', msg); }

  function getState() { return state; }
  return { start, getState, spin };
})();
