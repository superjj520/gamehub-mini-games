/**
 * GameJuice Sound — Web Audio API 程序化音效
 * 无需外部音频文件, 实时合成
 * 用法: SoundFX.play('click'); SoundFX.play('win');
 */
var SoundFX = (function() {
  var _ctx = null;
  function ctx() {
    if (!_ctx) _ctx = new (window.AudioContext || window.webkitAudioContext)();
    if (_ctx.state === 'suspended') _ctx.resume();
    return _ctx;
  }

  function play(type) {
    try { var c = ctx();
      switch(type) {
        case 'click': beep(c, 800, 0.05, 'square'); break;
        case 'win': winJingle(c); break;
        case 'tick': beep(c, 1200, 0.03, 'sine'); break;
        case 'spin': spinSound(c); break;
        case 'fail': beep(c, 200, 0.2, 'sawtooth'); break;
        case 'correct': beepSeq(c, [523,659,784], 0.08); break;
        case 'reveal': beepSeq(c, [300,600,900], 0.06); break;
        case 'coin': beepSeq(c, [988,1319], 0.06); break;
        case 'dice': beep(c, 400, 0.1, 'triangle'); break;
        case 'pop': beep(c, 600, 0.04, 'sine'); break;
      }
    } catch(e) { /* audio not available */ }
  }

  function beep(c, freq, dur, wave) {
    var o = c.createOscillator(); var g = c.createGain();
    o.type = wave || 'sine'; o.frequency.value = freq;
    g.gain.setValueAtTime(0.15, c.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001, c.currentTime + dur);
    o.connect(g); g.connect(c.destination);
    o.start(); o.stop(c.currentTime + dur);
  }

  function beepSeq(c, freqs, dur) {
    for (var i=0;i<freqs.length;i++) {
      var o=c.createOscillator(),g=c.createGain();
      o.type='sine'; o.frequency.value=freqs[i];
      g.gain.setValueAtTime(0.1, c.currentTime+i*dur);
      g.gain.exponentialRampToValueAtTime(0.001, c.currentTime+i*dur+dur);
      o.connect(g);g.connect(c.destination);
      o.start(c.currentTime+i*dur);o.stop(c.currentTime+i*dur+dur);
    }
  }

  function winJingle(c) {
    var notes=[523,659,784,1047], durations=[0.1,0.1,0.1,0.3];
    for(var i=0;i<notes.length;i++){
      var o=c.createOscillator(),g=c.createGain();
      o.type='sine';o.frequency.value=notes[i];
      var t=c.currentTime+i*0.12;
      g.gain.setValueAtTime(0.12,t);
      g.gain.exponentialRampToValueAtTime(0.001,t+durations[i]);
      o.connect(g);g.connect(c.destination);
      o.start(t);o.stop(t+durations[i]);
    }
  }

  function spinSound(c) {
    var o=c.createOscillator(),g=c.createGain();
    o.type='triangle';o.frequency.value=800;
    g.gain.setValueAtTime(0.06,c.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001,c.currentTime+0.5);
    o.connect(g);g.connect(c.destination);
    o.start();o.stop(c.currentTime+0.5);
  }

  return {play:play};
})();
