/**
 * GameJuice Sound v2 — 基于 ZzFX (MIT, <1KB)
 * https://github.com/KilledByAPixel/ZzFX
 * CDN: zzfx @ jsdelivr
 *
 * 用法: SoundFX.play('click');
 * 预设: click / win / tick / spin / fail / coin / dice / pop / sweep
 */
var SoundFX = (function() {
  // ── ZzFX 微内核 (MIT) ──
  var zzfxV = 0.3; // 全局音量
  var _audioCtx = null;
  function getCtx() {
    if (!_audioCtx) _audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    if (_audioCtx.state === 'suspended') _audioCtx.resume();
    return _audioCtx;
  }
  function zzfx() {
    var t = arguments.length > 1 ? arguments : arguments[0] || [];
    var p = getCtx();
    var o = p.createOscillator();
    var g = p.createGain();
    var vol = (t[0] || 1) * zzfxV;
    var wave = t[1] || 0; // 0=sine,1=triangle,2=sawtooth,3=square
    var freq = t[2] || 440;
    var attack = t[3] || 0;
    var sustain = t[4] || 0.1;
    var release = t[5] || 0.1;
    var slide = t[6] || 0;
    var lpCut = t[7] || 0;
    var lpSweep = t[8] || 0;
    var noise = t[9] || 0;
    var now = p.currentTime;
    o.type = ['sine', 'triangle', 'sawtooth', 'square'][wave] || 'sine';
    o.frequency.setValueAtTime(freq, now);
    if (slide) o.frequency.linearRampToValueAtTime(freq + slide, now + attack + sustain);
    g.gain.setValueAtTime(vol * 0.01, now);
    g.gain.linearRampToValueAtTime(vol, now + attack);
    g.gain.setValueAtTime(vol, now + attack + sustain);
    g.gain.linearRampToValueAtTime(0.001, now + attack + sustain + release);
    if (noise) { // 噪音层（打击感）
      var n = p.createOscillator();
      var ng = p.createGain();
      n.type = 'sawtooth';
      n.frequency.setValueAtTime(noise, now);
      ng.gain.setValueAtTime(vol * 0.15, now);
      ng.gain.linearRampToValueAtTime(0.001, now + 0.05);
      n.connect(ng); ng.connect(p.destination);
      n.start(now); n.stop(now + 0.05);
    }
    if (lpCut > 0) { // 低通滤波
      var f = p.createBiquadFilter();
      f.type = 'lowpass'; f.frequency.setValueAtTime(lpCut, now);
      if (lpSweep) f.frequency.linearRampToValueAtTime(lpCut + lpSweep, now + attack + sustain);
      o.connect(f); f.connect(g);
    } else { o.connect(g); }
    g.connect(p.destination);
    o.start(now); o.stop(now + attack + sustain + release);
  }

  // ── 音效预设库 ──
  var PRESETS = {
    click:  [0.6, 1, 800, 0, 0.03, 0.02, 0, 0, 0, 0],
    tick:   [0.4, 2, 1200, 0, 0.02, 0.02, 0, 0, 0, 0],
    spin:   [0.3, 1, 600, 0.05, 0.4, 0.1, -200, 0, 0, 0],
    win:    [0.7, 1, 523, 0.05, 0.15, 0.3, 0, 0, 0, 800],
    win2:   [0.7, 1, 659, 0.05, 0.15, 0.2, 0, 0, 0, 800],
    win3:   [0.7, 1, 784, 0.05, 0.15, 0.3, 0, 0, 0, 800],
    fail:   [0.5, 2, 200, 0.02, 0.2, 0.1, -80, 0, 0, 0],
    coin:   [0.6, 1, 988, 0, 0.04, 0.05, 0, 0, 0, 0],
    coin2:  [0.5, 1, 1319, 0, 0.04, 0.05, 0, 0, 0, 0],
    dice:   [0.4, 3, 400, 0, 0.08, 0.05, 0, 0, 0, 0],
    pop:    [0.5, 2, 600, 0, 0.03, 0.03, 0, 0, 0, 0],
    reveal: [0.4, 2, 300, 0.05, 0.08, 0.1, 400, 0, 0, 0],
    sweep:  [0.3, 0, 200, 0.1, 0.3, 0.3, 800, 1000, -800, 0],
    card:   [0.5, 1, 400, 0.02, 0.06, 0.05, 100, 0, 0, 0],
  };

  function play(name) {
    try {
      var p = PRESETS[name];
      if (p) zzfx(p);
      // 特殊复合音效
      if (name === 'win_all') { setTimeout(function(){ play('win2'); }, 120); setTimeout(function(){ play('win3'); }, 240); }
      if (name === 'coin_all') { play('coin'); setTimeout(function(){ play('coin2'); }, 60); }
    } catch(e) {}
  }

  return { play: play, zzfx: zzfx };
})();
