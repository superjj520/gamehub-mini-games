/**
 * GameHub 通用游戏引擎
 * 依赖：runtime/core/*.js + BlockRegistry
 *
 * 流程：
 *   1. 加载用户配置（blocks JSON）
 *   2. 按 block type 分发到对应核心模块处理
 *   3. 启动游戏专用逻辑（games/xxx.js）
 *   4. 事件总线协调各模块通讯
 */
const GameEngine = (() => {
  var _config = null;
  var _container = null;
  var _listeners = {};
  var _gameModule = null;
  var _ruleState = null;
  var _blockResults = {};

  // ─── 事件总线 ───
  function on(event, callback) {
    if (!_listeners[event]) _listeners[event] = [];
    _listeners[event].push(callback);
  }

  function off(event, callback) {
    if (!_listeners[event]) return;
    _listeners[event] = _listeners[event].filter(function(fn) { return fn !== callback; });
  }

  function emit(event, data) {
    var fns = _listeners[event] || [];
    for (var i = 0; i < fns.length; i++) {
      try { fns[i](data); } catch (e) { console.warn('[Engine] 事件处理错误:', event, e); }
    }
  }

  // ─── 初始化 ───
  /**
   * @param {object} config — user_configs 中的完整配置（包含 blocks 数组和 title 等）
   * @param {HTMLElement} container — 游戏渲染容器
   * @param {object} gameModule — 游戏专用逻辑模块（如 MonopolyGame）
   */
  async function init(config, container, gameModule) {
    _config = config;
    _container = container;
    _gameModule = gameModule;
    _blockResults = {};

    // 1. 按顺序处理每个 Block
    var blocks = config.blocks || [];
    for (var i = 0; i < blocks.length; i++) {
      var block = blocks[i];
      var result = processBlock(block, container);
      _blockResults[block.id] = result;
      emit('block:processed', { block: block, result: result });
    }

    // 2. 初始化规则状态
    var ruleBlock = findBlockByType('rule');
    if (ruleBlock && typeof RuleEngine !== 'undefined') {
      _ruleState = RuleEngine.init(ruleBlock.config.variables || []);
    }

    // 3. 应用主题
    var themeBlock = findBlockByType('theme');
    if (themeBlock && typeof ThemeRenderer !== 'undefined') {
      ThemeRenderer.apply(themeBlock.config);
    }

    // 4. 创建玩家
    var playerBlock = findBlockByType('player');
    var players = [];
    if (playerBlock && typeof PlayerManager !== 'undefined') {
      players = PlayerManager.createPlayers(playerBlock.config);
    }

    // 5. 通知就绪
    var ctx = {
      config: config,
      container: container,
      blockResults: _blockResults,
      ruleState: _ruleState,
      players: players,
      engine: { on: on, emit: emit, getBlockResult: getBlockResult, getRuleState: getRuleState, updateRuleState: updateRuleState, getConfig: getConfig },
    };

    emit('engine:ready', ctx);

    // 6. 调用游戏模块启动
    if (gameModule && gameModule.start) {
      await gameModule.start(ctx);
    }

    return ctx;
  }

  // ─── Block 处理分发 ───
  function processBlock(block, container) {
    var type = block.type;
    var cfg = block.config;
    var id = block.id;

    switch (type) {
      case 'board':
      case 'grid':
        if (typeof GridRenderer !== 'undefined') {
          var gridContainer = document.createElement('div');
          gridContainer.id = 'gh-grid-' + id;
          container.appendChild(gridContainer);
          var board = GridRenderer.render(gridContainer, cfg);
          return { element: gridContainer, board: board, config: cfg };
        }
        break;

      case 'collection':
        if (typeof CollectionManager !== 'undefined') {
          return { manager: CollectionManager, config: cfg };
        }
        break;

      case 'store':
        if (typeof StoreManager !== 'undefined') {
          return { manager: StoreManager, config: cfg };
        }
        break;

      case 'effect':
        if (typeof EffectEngine !== 'undefined') {
          return { engine: EffectEngine, config: cfg };
        }
        break;

      case 'building':
        if (typeof BuildingManager !== 'undefined') {
          return { manager: BuildingManager, config: cfg };
        }
        break;

      case 'rule':
      case 'player':
      case 'theme':
      case 'piece':
        return { config: cfg };

      default:
        return { config: cfg };
    }

    return { config: cfg };
  }

  // ─── 辅助 ───
  function findBlockByType(type) {
    var blocks = _config.blocks || [];
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].type === type) return blocks[i];
    }
    return null;
  }

  function getBlockResult(blockId) {
    return _blockResults[blockId] || null;
  }

  function getRuleState() {
    return _ruleState;
  }

  function updateRuleState(newState) {
    _ruleState = newState;
    emit('rule:changed', newState);
  }

  function getConfig() {
    return _config;
  }

  return { init, on, off, emit, getBlockResult, getRuleState, updateRuleState, getConfig };
})();
