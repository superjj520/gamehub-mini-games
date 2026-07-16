/**
 * GameJuice Particles — 轻量 Canvas 粒子系统
 * 支持: 彩带(confetti)、星星(sparkle)、爆炸(burst)、金币雨
 * 用法: Particles.fire(container, 'confetti');
 */
var Particles = (function() {
  var _activeEmitters = [];

  function fire(container, type, opts) {
    opts = opts || {};
    var count = opts.count || 60;
    var colors = opts.colors || ['#F5C842','#EC4899','#7C3AED','#22C55E','#3B82F6','#F97316'];
    var emitters = [];
    for (var i = 0; i < count; i++) {
      emitters.push(createParticle(container, type, colors, opts));
    }
    _activeEmitters.push({emitters:emitters,container:container});
    if (!_activeEmitters[0] || _activeEmitters.length === 1) startLoop();
  }

  function createParticle(container, type, colors, opts) {
    var el = document.createElement('div');
    var size = (opts.sizeMin||4) + Math.random() * (opts.sizeMax||8);
    var color = colors[Math.floor(Math.random() * colors.length)];
    var shapes = type==='burst' ? ['circle'] : ['rect','circle','rect','circle'];
    var shape = shapes[Math.floor(Math.random()*shapes.length)];

    el.style.cssText = 'position:fixed;z-index:9999;pointer-events:none;' +
      'width:'+size+'px;height:'+size+'px;' +
      'background:'+color+';' +
      (shape==='circle'?'border-radius:50%;':'') +
      'left:'+(opts.x||container.clientWidth/2)+'px;top:'+(opts.y||container.clientHeight/2)+'px;';

    var angle = Math.random() * Math.PI * 2;
    var velocity = 2 + Math.random() * 6;
    var life = 1;
    var gravity = type==='confetti'?0.03:0.05;
    var drag = 0.97;
    var rotation = Math.random() * 360;
    var rotationSpeed = (Math.random() - 0.5) * 15;

    container.appendChild(el);

    return {
      el:el, vx:Math.cos(angle)*velocity, vy:Math.sin(angle)*velocity - 3,
      life:1, decay:0.008 + Math.random()*0.012, gravity:gravity, drag:drag,
      rotation:rotation, rotationSpeed:rotationSpeed, size:size
    };
  }

  function startLoop() {
    function tick() {
      var allDone = true;
      for (var i = _activeEmitters.length-1; i >= 0; i--) {
        var emitter = _activeEmitters[i];
        var anyAlive = false;
        for (var j = emitter.emitters.length-1; j >= 0; j--) {
          var p = emitter.emitters[j];
          p.life -= p.decay;
          if (p.life <= 0) { p.el.remove(); emitter.emitters.splice(j,1); continue; }
          anyAlive = true;
          p.vy += p.gravity;
          p.vx *= p.drag; p.vy *= p.drag;
          p.rotation += p.rotationSpeed;
          var l = parseFloat(p.el.style.left) + p.vx;
          var t = parseFloat(p.el.style.top) + p.vy;
          p.el.style.left = l + 'px'; p.el.style.top = t + 'px';
          p.el.style.transform = 'rotate('+p.rotation+'deg)';
          p.el.style.opacity = p.life;
        }
        if (!anyAlive) _activeEmitters.splice(i,1);
        else allDone = false;
      }
      if (!allDone) requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
  }

  // 快捷方法
  function confetti(container, opts) { fire(container, 'confetti', opts); }
  function burst(container, opts) { fire(container, 'burst', opts); }
  function stars(container, count) { fire(container, 'confetti', {count:count||30,colors:['#F5C842'],sizeMin:2,sizeMax:5}); }

  return {fire:fire, confetti:confetti, burst:burst, stars:stars};
})();
