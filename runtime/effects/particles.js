/**
 * GameJuice Particles v2 — canvas-confetti 优先 / DOM 粒子兜底
 * CDN: canvas-confetti @ jsdelivr (全局 confetti)
 * 用法: Particles.fire(container, 'confetti');
 */
var Particles = (function() {
  function fire(type, opts) {
    opts = opts || {};
    // 优先使用 canvas-confetti（如果已加载）
    if (typeof confetti !== 'undefined') {
      fireWithConfetti(type, opts);
    } else {
      fireDOM(type, opts);
    }
  }

  // ── canvas-confetti 版本 ──
  function fireWithConfetti(type, opts) {
    var defaults = {
      particleCount: opts.count || 80,
      spread: opts.spread || 70,
      origin: { x: opts.x || 0.5, y: opts.y || 0.5 },
      colors: opts.colors || ['#F5C842', '#EC4899', '#7C3AED', '#22C55E', '#F97316', '#3B82F6'],
      disableForReducedMotion: true,
      startVelocity: 30,
      decay: 0.9,
      ticks: 60,
    };

    if (type === 'confetti') {
      // 左右两侧爆发
      confetti(Object.assign({}, defaults, { angle: 60, spread: 55, origin: { x: 0, y: opts.y || 0.4 } }));
      confetti(Object.assign({}, defaults, { angle: 120, spread: 55, origin: { x: 1, y: opts.y || 0.4 } }));
    } else if (type === 'burst') {
      confetti(defaults);
    } else if (type === 'stars') {
      confetti(Object.assign({}, defaults, {
        particleCount: opts.count || 40,
        spread: 100,
        shapes: ['star'],
        colors: ['#F5C842'],
        scalar: 0.8,
      }));
    } else if (type === 'coins') {
      confetti(Object.assign({}, defaults, {
        particleCount: opts.count || 50,
        spread: 90,
        colors: ['#F5C842', '#F59E0B', '#FDE68A'],
        startVelocity: 25, gravity: 1.5, scalar: 1.2, ticks: 80,
      }));
    }
  }

  // ── DOM 粒子兜底 ──
  function fireDOM(type, opts) {
    opts = opts || {};
    var count = opts.count || 40;
    var colors = opts.colors || ['#F5C842', '#EC4899', '#7C3AED', '#22C55E'];
    var particles = [];
    for (var i = 0; i < count; i++) {
      var el = document.createElement('div');
      var color = colors[Math.floor(Math.random() * colors.length)];
      el.style.cssText = 'position:fixed;z-index:9999;pointer-events:none;width:6px;height:6px;background:' + color + ';border-radius:50%;left:50%;top:50%;opacity:1;';
      document.body.appendChild(el);
      var angle = Math.random() * Math.PI * 2;
      var v = 2 + Math.random() * 5;
      particles.push({ el: el, vx: Math.cos(angle) * v, vy: Math.sin(angle) * v - 2, life: 1, decay: 0.01 + Math.random() * 0.02 });
    }
    (function tick() {
      var alive = false;
      for (var i = particles.length - 1; i >= 0; i--) {
        var p = particles[i];
        p.life -= p.decay;
        if (p.life <= 0) { p.el.remove(); particles.splice(i, 1); continue; }
        alive = true;
        p.vy += 0.05;
        p.el.style.left = (parseFloat(p.el.style.left) + p.vx) + 'px';
        p.el.style.top = (parseFloat(p.el.style.top) + p.vy) + 'px';
        p.el.style.opacity = p.life;
      }
      if (alive) requestAnimationFrame(tick);
    })();
  }

  return { fire: fire };
})();
