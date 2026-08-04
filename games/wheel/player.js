(function (root, factory) {
  var api = factory(root.GameHubWheelConfig || (typeof require === 'function' ? require('./config.js') : null)); root.GameHubWheelPlayer = api;
  if (typeof module === 'object' && module.exports) module.exports = api;
}(typeof window !== 'undefined' ? window : globalThis, function (wheelConfig) {
var getOutcomeAngle = wheelConfig.getOutcomeAngle;

function point(angle, radius) {
  var radians = angle * Math.PI / 180;
  return { x: 250 + Math.cos(radians) * radius, y: 250 + Math.sin(radians) * radius };
}
function escapeHtml(value) { return String(value).replace(/[&<>"']/g, function (character) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[character]; }); }
function sectorPath(start, end, outer, inner) {
  var startOuter = point(start, outer), endOuter = point(end, outer), large = end - start > 180 ? 1 : 0;
  if (!inner) return 'M250 250 L' + startOuter.x + ' ' + startOuter.y + ' A' + outer + ' ' + outer + ' 0 ' + large + ' 1 ' + endOuter.x + ' ' + endOuter.y + ' Z';
  var endInner = point(end, inner), startInner = point(start, inner);
  return 'M' + startOuter.x + ' ' + startOuter.y + ' A' + outer + ' ' + outer + ' 0 ' + large + ' 1 ' + endOuter.x + ' ' + endOuter.y + ' L' + endInner.x + ' ' + endInner.y + ' A' + inner + ' ' + inner + ' 0 ' + large + ' 0 ' + startInner.x + ' ' + startInner.y + ' Z';
}
function renderSector(config, prize, index) {
  var count = config.prizes.length, arc = 360 / count, gap = Math.min(config.geometry.gap, arc / 3), start = config.geometry.startAngle + arc * index + gap / 2, end = config.geometry.startAngle + arc * (index + 1) - gap / 2;
  var outer = config.geometry.radius, inner = config.geometry.hollow ? config.geometry.innerRadius : 0, center = config.geometry.startAngle + arc * (index + .5), labelPoint = point(center, outer * config.labels.offset);
  var label = config.labels.visible ? '<text class="wheel-label" x="' + labelPoint.x + '" y="' + labelPoint.y + '" text-anchor="middle" dominant-baseline="middle" transform="rotate(' + (config.labels.direction === 'horizontal' ? 0 : center + (config.labels.direction === 'outward' ? 0 : 180)) + ' ' + labelPoint.x + ' ' + labelPoint.y + ')"><tspan class="wheel-label-icon">' + escapeHtml(prize.icon) + '</tspan><tspan x="' + labelPoint.x + '" dy="18">' + escapeHtml(prize.name) + '</tspan></text>' : '';
  return '<g data-wheel-sector="' + index + '" class="wheel-sector"><path d="' + sectorPath(start, end, outer, inner) + '" fill="' + prize.color + '"></path>' + label + '</g>';
}
function renderWheel(config) {
  var sectors = config.prizes.map(function (prize, index) { return renderSector(config, prize, index); }).join('');
  var core = config.geometry.hollow ? '<circle class="wheel-core-ring" cx="250" cy="250" r="' + (config.geometry.innerRadius - 8) + '"></circle>' : '<circle class="wheel-core" cx="250" cy="250" r="36"></circle>';
  return '<div class="wheel-player theme-' + config.theme + '"><div class="wheel-pointer" aria-hidden="true"></div><svg class="wheel-svg" viewBox="0 0 500 500" role="img" aria-label="' + escapeHtml(config.title) + '"><g class="wheel-rotor">' + sectors + core + '</g></svg></div>';
}
function createPlayer(context) {
  var container, rotor, spinning = false, rotation = 0;
  function mount(nextContainer) { container = nextContainer; container.innerHTML = renderWheel(context.config); rotor = container.querySelector('.wheel-rotor'); return api; }
  function reset() { rotation = 0; spinning = false; if (rotor) { rotor.style.transition = 'none'; rotor.style.transform = 'rotate(0deg)'; rotor.querySelectorAll('.wheel-sector').forEach(function (item) { item.classList.remove('is-winner'); }); } }
  function spin(outcome) {
    if (!rotor || spinning) return Promise.resolve(outcome);
    spinning = true;
    var target = 1440 - 90 - getOutcomeAngle(context.config, outcome); rotation += target + ((360 - rotation % 360) % 360);
    rotor.style.transition = 'transform 3.8s cubic-bezier(.08,.74,.12,1)'; rotor.style.transform = 'rotate(' + rotation + 'deg)';
    return new Promise(function (resolve) { window.setTimeout(function () { rotor.querySelector('[data-wheel-sector="' + outcome.index + '"]').classList.add('is-winner'); spinning = false; resolve(outcome); }, 3850); });
  }
  var api = { mount: mount, spin: spin, reset: reset, destroy: function () { if (container) container.innerHTML = ''; } };
  return api;
}
return { renderWheel: renderWheel, createPlayer: createPlayer };
}));
