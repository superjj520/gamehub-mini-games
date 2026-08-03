(function (root, factory) {
  var api = factory(); root.GameHubWheelPlayer = api;
  if (typeof module === 'object' && module.exports) module.exports = api;
}(typeof window !== 'undefined' ? window : globalThis, function () {
function createPlayer(context) {
  return { mount: function (container) { container.textContent = context.config.prizes.map(function (prize) { return prize.name; }).join(' · '); }, destroy: function () {} };
}
return { createPlayer: createPlayer };
}));
