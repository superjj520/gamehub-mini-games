/**
 * Kenney Audio Loader — CC0 真实音效
 * 来源: kenney.nl Board Game Pack Bonus
 * 用法: KenneyAudio.play('diceThrow');
 */
var KenneyAudio = (function() {
  var _cache = {};
  var _base = 'assets/kenney/boardgame-pack/Bonus/';

  var _map = {
    diceThrow: 'dieThrow1.ogg',
    diceShuffle: 'dieShuffle1.ogg',
    cardSlide: 'cardSlide1.ogg',
    cardPlace: 'cardPlace1.ogg',
    chipsCollide: 'chipsCollide1.ogg',
  };

  function play(name) {
    try {
      var key = _map[name];
      if (!key) return;
      if (_cache[key]) { _cache[key].currentTime = 0; _cache[key].play().catch(function(){}); return; }
      var audio = new Audio(_base + key);
      audio.volume = 0.5;
      _cache[key] = audio;
      audio.play().catch(function(){});
    } catch(e) {}
  }

  return { play: play };
})();
