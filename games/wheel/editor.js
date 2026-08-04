(function (root, factory) {
  var api = factory(root.GameHubWheelConfig || (typeof require === 'function' ? require('./config.js') : null)); root.GameHubWheelEditor = api;
  if (typeof module === 'object' && module.exports) module.exports = api;
}(typeof window !== 'undefined' ? window : globalThis, function (wheelConfig) {
var normalizeConfig = wheelConfig.normalizeConfig, getPresets = wheelConfig.getPresets;
function escapeHtml(value) { return String(value).replace(/[&<>"']/g, function (character) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[character]; }); }
function updatePrize(config, index, patch) { return normalizeConfig(Object.assign({}, config, { prizes: config.prizes.map(function (prize, itemIndex) { return itemIndex === index ? Object.assign({}, prize, patch) : prize; }) })); }
function createEditor(options) {
  var config = normalizeConfig(options.config), container, tab = 'content';
  function change(next) { config = normalizeConfig(next); options.onChange(config); render(); }
  function renderContent() {
    var presets = getPresets().map(function (preset) { return '<button class="wheel-preset" data-preset="' + preset.id + '">' + escapeHtml(preset.name) + '</button>'; }).join('');
    var prizes = config.prizes.map(function (prize, index) { return '<div class="wheel-prize"><span class="wheel-color" style="background:' + prize.color + '"></span><input data-prize-name="' + index + '" value="' + escapeHtml(prize.name) + '" aria-label="奖项名称"><input data-prize-weight="' + index + '" type="range" min="1" max="10" value="' + prize.weight + '" aria-label="' + escapeHtml(prize.name) + ' 概率"><b>' + prize.weight + '</b><button data-remove="' + index + '" ' + (config.prizes.length <= 2 ? 'disabled' : '') + '>×</button></div>'; }).join('');
    return '<p class="wheel-help">选择预设后继续修改奖项和概率。</p><div class="wheel-presets">' + presets + '</div><label class="wheel-field">游戏标题<input data-title value="' + escapeHtml(config.title) + '"></label><div class="wheel-list">' + prizes + '</div><button class="wheel-add" data-add>＋ 添加奖项</button>';
  }
  function renderStyle() { return '<p class="wheel-help">主题只改变呈现，不改变抽奖概率。</p><div class="wheel-themes">' + ['neon', 'gold', 'candy', 'festival'].map(function (theme) { return '<button data-theme="' + theme + '" class="' + (config.theme === theme ? 'is-active' : '') + '">' + ({ neon: '霓虹极光', gold: '金奢夜场', candy: '糖果聚会', festival: '节日喜庆' }[theme]) + '</button>'; }).join('') + '</div><label class="wheel-check"><input data-label-visible type="checkbox" ' + (config.labels.visible ? 'checked' : '') + '> 显示扇区文字</label><label class="wheel-field">文字方向<select data-label-direction><option value="horizontal">水平</option><option value="outward">向外放射</option><option value="inward">向内放射</option></select></label>';
  }
  function renderGeometry() { var g = config.geometry; return '<p class="wheel-help">高级参数只改变转盘外观。</p><label class="wheel-check"><input data-hollow type="checkbox" ' + (g.hollow ? 'checked' : '') + '> 中空中心</label>' + [['radius','外半径',150,260],['gap','扇区间隙',0,8],['innerRadius','内孔半径',35,130],['outerRound','外圆角',0,28],['innerRound','内圆角',0,22],['startAngle','起始角度',-180,180]].map(function (item) { return '<label class="wheel-range">' + item[1] + '<output>' + g[item[0]] + '</output><input data-geometry="' + item[0] + '" type="range" min="' + item[2] + '" max="' + item[3] + '" value="' + g[item[0]] + '"></label>'; }).join(''); }
  function bind() {
    container.querySelectorAll('[data-tab]').forEach(function (button) { button.onclick = function () { tab = button.dataset.tab; render(); }; });
    container.querySelectorAll('[data-preset]').forEach(function (button) { button.onclick = function () { var preset = getPresets().find(function (item) { return item.id === button.dataset.preset; }); change(preset.config); }; });
    container.querySelectorAll('[data-prize-name]').forEach(function (input) { input.onchange = function () { change(updatePrize(config, Number(input.dataset.prizeName), { name: input.value })); }; });
    container.querySelectorAll('[data-prize-weight]').forEach(function (input) { input.oninput = function () { change(updatePrize(config, Number(input.dataset.prizeWeight), { weight: Number(input.value) })); }; });
    container.querySelectorAll('[data-remove]').forEach(function (button) { button.onclick = function () { change(Object.assign({}, config, { prizes: config.prizes.filter(function (_, index) { return index !== Number(button.dataset.remove); }) })); }; });
    var add = container.querySelector('[data-add]'); if (add) add.onclick = function () { change(Object.assign({}, config, { prizes: config.prizes.concat({ name: '新奖项 ' + (config.prizes.length + 1), weight: 1 }) })); };
    var title = container.querySelector('[data-title]'); if (title) title.onchange = function () { change(Object.assign({}, config, { title: title.value })); };
    container.querySelectorAll('[data-theme]').forEach(function (button) { button.onclick = function () { change(Object.assign({}, config, { theme: button.dataset.theme })); }; });
    var visible = container.querySelector('[data-label-visible]'); if (visible) visible.onchange = function () { change(Object.assign({}, config, { labels: Object.assign({}, config.labels, { visible: visible.checked }) })); };
    var direction = container.querySelector('[data-label-direction]'); if (direction) { direction.value = config.labels.direction; direction.onchange = function () { change(Object.assign({}, config, { labels: Object.assign({}, config.labels, { direction: direction.value }) })); }; }
    var hollow = container.querySelector('[data-hollow]'); if (hollow) hollow.onchange = function () { change(Object.assign({}, config, { geometry: Object.assign({}, config.geometry, { hollow: hollow.checked }) })); };
    container.querySelectorAll('[data-geometry]').forEach(function (input) { input.oninput = function () { change(Object.assign({}, config, { geometry: Object.assign({}, config.geometry, { [input.dataset.geometry]: Number(input.value) }) })); }; });
  }
  function render() { if (!container) return; var content = tab === 'content' ? renderContent() : tab === 'style' ? renderStyle() : renderGeometry(); container.innerHTML = '<div class="wheel-tabs">' + [['content','内容'],['style','样式'],['geometry','高级几何']].map(function (item) { return '<button data-tab="' + item[0] + '" class="' + (tab === item[0] ? 'is-active' : '') + '">' + item[1] + '</button>'; }).join('') + '</div><div class="wheel-panel">' + content + '</div>'; bind(); }
  return { mount: function (target) { container = target; render(); }, getConfig: function () { return config; }, destroy: function () { if (container) container.innerHTML = ''; } };
}
return { createEditor: createEditor, updatePrize: updatePrize };
}));
