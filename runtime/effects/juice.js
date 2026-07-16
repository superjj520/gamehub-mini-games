/**
 * GameJuice — 震动/抖动/弹性/数字滚动
 * 用法: Juice.vibrate('win'); Juice.bounce(el); Juice.shake(el);
 */
var Juice = (function() {
  function vibrate(type) {
    if (!navigator.vibrate) return;
    switch(type) {
      case 'light': navigator.vibrate(10); break;
      case 'medium': navigator.vibrate([20,30,20]); break;
      case 'heavy': navigator.vibrate([30,50,30,50,30]); break;
      case 'win': navigator.vibrate([20,50,20,50,20,50,100]); break;
      default: navigator.vibrate(15);
    }
  }

  function bounce(el, scale) {
    scale = scale || 1.15;
    el.style.transition = 'transform 0.15s cubic-bezier(.4,1.3,.6,1)';
    el.style.transform = 'scale('+scale+')';
    setTimeout(function(){ el.style.transform = 'scale(1)'; }, 150);
  }

  function pressDown(el) {
    el.style.transition = 'transform 0.1s ease';
    el.style.transform = 'scale(0.95)';
  }

  function pressUp(el) {
    el.style.transition = 'transform 0.2s cubic-bezier(.4,1.3,.6,1)';
    el.style.transform = 'scale(1)';
  }

  function shake(el, intensity) {
    intensity = intensity || 4;
    el.style.transition = 'transform 0.05s linear';
    var orig = el.style.transform || '';
    var count = 0, max = 6;
    function tick() {
      if (count >= max) { el.style.transform = orig; return; }
      var x = (Math.random()-0.5) * intensity * 2;
      el.style.transform = 'translateX('+x+'px)';
      count++;
      requestAnimationFrame(tick);
    }
    tick();
  }

  // 数字滚动动画
  function countUp(el, from, to, duration) {
    duration = duration || 800;
    var start = performance.now();
    function tick(t) {
      var progress = Math.min((t-start)/duration, 1);
      var eased = 1 - Math.pow(1-progress, 3);
      var val = Math.round(from + (to-from) * eased);
      el.textContent = val;
      if (progress < 1) requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
  }

  // 脉冲动画
  function pulse(el, times) {
    times = times || 3;
    var count = 0;
    function beat() {
      if (count >= times) return;
      el.style.transition = 'transform 0.15s ease';
      el.style.transform = 'scale(1.08)';
      setTimeout(function(){ el.style.transform = 'scale(1)'; count++; setTimeout(beat, 100); }, 150);
    }
    beat();
  }

  // 淡入弹出
  function popIn(el) {
    el.style.transition = 'transform 0.3s cubic-bezier(.4,1.3,.6,1), opacity 0.3s ease';
    el.style.transform = 'scale(0)';
    el.style.opacity = '0';
    requestAnimationFrame(function(){
      el.style.transform = 'scale(1)';
      el.style.opacity = '1';
    });
  }

  return {vibrate:vibrate, bounce:bounce, pressDown:pressDown, pressUp:pressUp,
    shake:shake, countUp:countUp, pulse:pulse, popIn:popIn};
})();
