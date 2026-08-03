(function (root, factory) {
  var api = factory(); root.GameHubWheelConfig = api;
  if (typeof module === 'object' && module.exports) module.exports = api;
}(typeof window !== 'undefined' ? window : globalThis, function () {
function normalizeConfig(input) {
  var prizes = input && input.prizes;
  if (!Array.isArray(prizes) || prizes.length < 2) throw new Error('大转盘至少需要 2 个奖项');
  var seen = {};
  var normalized = prizes.map(function (prize) {
    var name = String(prize.name || '').trim();
    var weight = Number(prize.weight);
    if (!name || seen[name]) throw new Error('奖项名称不能为空或重复');
    if (!Number.isFinite(weight) || weight <= 0) throw new Error('奖项权重必须大于 0');
    seen[name] = true;
    return { id: prize.id || name, name: name, weight: weight, icon: prize.icon || '🎁' };
  });
  return { prizes: normalized, theme: input.theme || 'neon' };
}

function pickOutcome(config, randomSource) {
  var random = randomSource && randomSource.next ? randomSource.next() : Math.random();
  var total = config.prizes.reduce(function (sum, prize) { return sum + prize.weight; }, 0);
  var cursor = random * total;
  for (var index = 0; index < config.prizes.length; index += 1) {
    cursor -= config.prizes[index].weight;
    if (cursor < 0) return { index: index, prize: config.prizes[index] };
  }
  return { index: config.prizes.length - 1, prize: config.prizes[config.prizes.length - 1] };
}

return { normalizeConfig: normalizeConfig, pickOutcome: pickOutcome };
}));
