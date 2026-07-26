/**
 * GameHub 运行时初始化器
 * 统一加载所有 runtime 模块，提供健康检查和全局命名空间。
 *
 * 加载顺序：bridge → core → effects → games → 全局模块
 * 用法：在所有 runtime/*.js 之后引入本文件
 */
const GameHub = (() => {
  var _status = {};
  var _errors = [];

  // ─── 模块注册表 ───
  var MODULES = [
    { name: 'GameHubBridge',  global: 'GameHubBridge',  required: false },
    { name: 'GameEngine',     global: 'GameEngine',     required: false },
    { name: 'BoardGameEngine',global: 'BoardGameEngine',required: false },
    { name: 'BlockRegistry',  global: 'BlockRegistry',  required: false },
    { name: 'Particles',      global: 'Particles',      required: false },
    { name: 'GameSupabase',   global: 'GameSupabase',   required: false },
    { name: 'GameAchievement',global: 'GameAchievement',required: false },
    { name: 'GameUser',       global: 'GameUser',       required: false },
  ];

  // ─── 核心模块（runtime/core/）─ 按需检查 ───
  var CORE_MODULES = [
    'GridRenderer', 'ThemeRenderer', 'PlayerManager',
    'RuleEngine', 'CollectionManager', 'StoreManager',
    'EffectEngine', 'BuildingManager',
  ];

  // ─── 初始化 ───
  function init() {
    console.log('[GameHub] 运行时初始化...');

    // 1. 检查主模块
    for (var i = 0; i < MODULES.length; i++) {
      var mod = MODULES[i];
      var available = typeof window[mod.global] !== 'undefined';
      _status[mod.name] = available;
      if (!available && mod.required) {
        _errors.push('缺少必需模块: ' + mod.name);
        console.error('[GameHub] 缺少必需模块:', mod.name);
      }
    }

    // 2. 检查核心模块
    var coreStatus = {};
    for (var j = 0; j < CORE_MODULES.length; j++) {
      var name = CORE_MODULES[j];
      coreStatus[name] = typeof window[name] !== 'undefined';
    }
    _status['Core模块'] = coreStatus;

    // 3. 报告状态
    var loadedCount = Object.values(_status).filter(function(v) {
      return v === true || (typeof v === 'object' && Object.values(v).some(function(x) { return x; }));
    }).length;

    console.log('[GameHub] 初始化完成 — ' + loadedCount + ' 个模块就绪', _status);

    if (_errors.length > 0) {
      console.warn('[GameHub] ' + _errors.length + ' 个模块加载异常:', _errors);
    }

    // 4. 触发就绪事件
    if (typeof GameEngine !== 'undefined' && GameEngine.emit) {
      GameEngine.emit('hub:ready', getStatus());
    }
  }

  // ─── 健康检查 ───
  function healthCheck() {
    return {
      ok: _errors.length === 0,
      modules: _status,
      errors: _errors,
      timestamp: Date.now(),
    };
  }

  // ─── 获取状态 ───
  function getStatus() {
    return _status;
  }

  // ─── 版本信息 ───
  function version() {
    return '2.0.0';
  }

  // DOM 就绪后初始化
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  return {
    init: init,
    healthCheck: healthCheck,
    getStatus: getStatus,
    version: version,
  };
})();
