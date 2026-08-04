(function (root, factory) {
  var api = factory(); root.GameHubWheelConfig = api;
  if (typeof module === 'object' && module.exports) module.exports = api;
}(typeof window !== 'undefined' ? window : globalThis, function () {
var palette = ['#55E6FF', '#A878FF', '#FF5D91', '#FFC84A', '#55E6B5', '#6E87FF', '#FF8B5C', '#E8ECFF'];
var defaultLabels = { visible: true, direction: 'horizontal', offset: 0.62 };
var defaultGeometry = { radius: 205, gap: 3, hollow: true, innerRadius: 80, outerRound: 18, innerRound: 12, startAngle: -90 };
var defaultPrizes = [
  { id: 'choice-1', name: '你来决定', icon: '✦', weight: 1 },
  { id: 'choice-2', name: '再想想', icon: '◌', weight: 1 },
  { id: 'choice-3', name: '听大家的', icon: '◎', weight: 1 },
  { id: 'choice-4', name: '重新抽', icon: '↻', weight: 1 }
];

function clamp(value, min, max, fallback) {
  value = Number(value);
  if (!Number.isFinite(value)) return fallback;
  return Math.min(max, Math.max(min, value));
}

function normalizeConfig(input) {
  input = input || {};
  var prizes = input.prizes;
  if (!Array.isArray(prizes) || prizes.length < 2) throw new Error('大转盘至少需要 2 个奖项');
  if (prizes.length > 16) throw new Error('大转盘最多支持 16 个奖项');
  var seen = {};
  var normalized = prizes.map(function (prize, index) {
    var name = String(prize.name || '').trim();
    var weight = Number(prize.weight);
    if (!name || seen[name]) throw new Error('奖项名称不能为空或重复');
    if (!Number.isFinite(weight) || weight <= 0) throw new Error('奖项权重必须大于 0');
    seen[name] = true;
    return {
      id: prize.id || 'prize-' + index + '-' + name,
      name: name,
      weight: weight,
      icon: String(prize.icon || '✦').slice(0, 2),
      color: prize.color || palette[index % palette.length]
    };
  });
  var labels = Object.assign({}, defaultLabels, input.labels || {});
  if (['horizontal', 'outward', 'inward'].indexOf(labels.direction) < 0) labels.direction = defaultLabels.direction;
  labels.visible = labels.visible !== false;
  labels.offset = clamp(labels.offset, 0.42, 0.76, defaultLabels.offset);
  var geometry = Object.assign({}, defaultGeometry, input.geometry || {});
  geometry.radius = clamp(geometry.radius, 150, 260, defaultGeometry.radius);
  geometry.gap = clamp(geometry.gap, 0, 8, defaultGeometry.gap);
  geometry.hollow = geometry.hollow !== false;
  geometry.innerRadius = geometry.hollow ? clamp(geometry.innerRadius, 35, Math.min(130, geometry.radius - 55), defaultGeometry.innerRadius) : 0;
  geometry.outerRound = clamp(geometry.outerRound, 0, 28, defaultGeometry.outerRound);
  geometry.innerRound = clamp(geometry.innerRound, 0, 22, defaultGeometry.innerRound);
  geometry.startAngle = clamp(geometry.startAngle, -180, 180, defaultGeometry.startAngle);
  return {
    title: String(input.title || '今晚谁买单？').trim().slice(0, 40) || '未命名转盘',
    prizes: normalized,
    theme: ['neon', 'gold', 'candy', 'festival'].indexOf(input.theme) >= 0 ? input.theme : 'neon',
    labels: labels,
    geometry: geometry
  };
}

function createDefaultConfig() { return normalizeConfig({ prizes: defaultPrizes }); }

function getPresets() {
  return [
    { id: 'party', name: '聚会随机选择', description: '用一转决定今晚的小事。', config: createDefaultConfig() },
    { id: 'draw', name: '活动抽奖', description: '给小型活动准备惊喜结果。', config: normalizeConfig({ title: '好运正在发生', theme: 'gold', prizes: [{ name: '惊喜大奖', icon: '★', weight: 1 }, { name: '精选好礼', icon: '✦', weight: 2 }, { name: '咖啡券', icon: '☕', weight: 3 }, { name: '谢谢参与', icon: '○', weight: 4 }] }) },
    { id: 'truth', name: '真心话大冒险', description: '朋友之间的轻松挑战。', config: normalizeConfig({ title: '轮到谁接招？', theme: 'candy', prizes: [{ name: '真心话', icon: '♥', weight: 1 }, { name: '大冒险', icon: '⚡', weight: 1 }, { name: '指定一人', icon: '◎', weight: 1 }, { name: '逃过一劫', icon: '☁', weight: 1 }] }) }
  ];
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

function getOutcomeAngle(config, outcome) {
  return 360 / config.prizes.length * (Number(outcome.index) + 0.5) + config.geometry.startAngle;
}

return { createDefaultConfig: createDefaultConfig, getPresets: getPresets, normalizeConfig: normalizeConfig, pickOutcome: pickOutcome, getOutcomeAngle: getOutcomeAngle };
}));
