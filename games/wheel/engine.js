(function (root, factory) {
  var api = factory(root.GameHubWheelConfig || (typeof require === 'function' ? require('./config.js') : null));
  root.GameHubWheelEngine = api;
  if (typeof module === 'object' && module.exports) module.exports = api;
}(typeof window !== 'undefined' ? window : globalThis, function (wheelConfig) {
var pickOutcome = wheelConfig.pickOutcome;

function createEngine(context) {
  var phase = 'idle';
  function spin(randomSource) {
    if (phase === 'spinning') throw new Error('转盘正在运行');
    var outcome = pickOutcome(context.config, randomSource);
    phase = 'spinning';
    return { outcome: outcome, complete: function () { phase = 'result'; return outcome; } };
  }
  return { spin: spin, getState: function () { return { phase: phase }; } };
}
return { createEngine: createEngine };
}));
