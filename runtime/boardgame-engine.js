/**
 * GameHub 游戏引擎 v2 — 采用 boardgame.io 架构模式
 *
 * 核心概念:
 *   G (Game State) — 不可变游戏状态, 只通过 moves 修改
 *   moves: (G, ctx, args) => newG — 纯函数, 接收状态返回新状态
 *   phases — 每个阶段有自己的 moves 和 turn 规则
 *   ctx — 引擎托管上下文: currentPlayer, phase, turn, random
 *
 * 用法:
 *   var game = GameEngine.create({
 *     setup: function(ctx) { return { score: 0 }; },
 *     moves: { addScore: function(G, ctx, n) { return { ...G, score: G.score + n }; } },
 *     phases: { play: { moves: ['addScore'], start: true } }
 *   });
 *   game.start(container);       // 启动游戏渲染
 *   game.move('addScore', 10);   // 执行动作
 *   game.on('state', fn);        // 监听状态变化
 */

var BoardGameEngine = (function() {
  function create(config) {
    var game = {
      _config: config,
      _G: null,
      _ctx: null,
      _phaseCfg: null,
      _listeners: {},
      _container: null,
      _gameModule: null,
      _moveCount: 0,
      _randomSeed: Date.now(),
    };

    // 简易确定性随机
    game._random = {
      _seed: Date.now(),
      _next: function() {
        this._seed = (this._seed * 1103515245 + 12345) & 0x7fffffff;
        return this._seed / 0x7fffffff;
      },
      D6: function() { return Math.floor(this._next() * 6) + 1; },
      D20: function() { return Math.floor(this._next() * 20) + 1; },
      shuffle: function(arr) {
        var a = arr.slice();
        for (var i = a.length - 1; i > 0; i--) {
          var j = Math.floor(this._next() * (i + 1));
          var t = a[i]; a[i] = a[j]; a[j] = t;
        }
        return a;
      },
      pick: function(arr) {
        return arr[Math.floor(this._next() * arr.length)];
      }
    };

    // 事件系统
    game.on = function(event, fn) {
      if (!this._listeners[event]) this._listeners[event] = [];
      this._listeners[event].push(fn);
    };
    game._emit = function(event, data) {
      var fns = this._listeners[event] || [];
      for (var i = 0; i < fns.length; i++) { fns[i](data); }
    };

    // 查找阶段配置
    game._getPhaseConfig = function(phaseName) {
      var phases = this._config.phases || {};
      var p = phases[phaseName || this._ctx.phase];
      if (!p) p = phases[Object.keys(phases)[0]];
      return p || { moves: [] };
    };

    // 初始化
    game.start = function(container, blocks) {
      this._container = container;
      this._G = this._config.setup ? this._config.setup({ random: this._random, blocks: blocks }) : {};
      this._ctx = {
        currentPlayer: '0',
        numPlayers: 2,
        phase: this._config._startPhase || Object.keys(this._config.phases || {})[0] || 'play',
        turn: 1,
        gameover: null,
        random: this._random
      };
      this._emit('init', { G: this._G, ctx: this._ctx });
      this._emit('state', this.getState());
      return this;
    };

    // 执行 move
    game.move = function(moveName, args) {
      if (this._ctx.gameover) return this;
      var phaseCfg = this._getPhaseConfig();
      var allowedMoves = phaseCfg.moves || [];
      if (allowedMoves.indexOf(moveName) === -1) {
        console.warn('[Engine] move "' + moveName + '" not allowed in phase "' + this._ctx.phase + '". Allowed:', allowedMoves);
        return this;
      }

      var moveFn = this._config.moves[moveName];
      if (!moveFn) { console.warn('[Engine] move "' + moveName + '" not found'); return this; }

      var prevG = this._G;
      var prevCtx = this._ctx;
      var newG = moveFn(this._G, this._ctx, args);
      if (!newG) { console.warn('[Engine] move "' + moveName + '" returned null — must return new G'); return this; }
      this._G = newG;
      this._moveCount++;
      this._emit('move', { name: moveName, args: args, prevG: prevG, newG: newG });

      // 检查阶段结束条件
      if (phaseCfg.endIf) {
        var nextPhase = phaseCfg.endIf(this._G, this._ctx);
        if (nextPhase) this.setPhase(nextPhase);
      }

      // 检查游戏结束
      if (this._config.endIf) {
        var winner = this._config.endIf(this._G, this._ctx);
        if (winner) this._ctx = { ...this._ctx, gameover: winner };
      }

      this._emit('state', this.getState());
      return this;
    };

    // 切换阶段
    game.setPhase = function(phaseName) {
      var oldPhase = this._ctx.phase;
      this._ctx = { ...this._ctx, phase: phaseName };

      var phaseCfg = this._getPhaseConfig(phaseName);
      if (phaseCfg.onEnter) phaseCfg.onEnter(this._G, this._ctx);

      this._emit('phase', { from: oldPhase, to: phaseName });
      this._emit('state', this.getState());
      return this;
    };

    // 结束回合
    game.endTurn = function() {
      var players = this._G.players || [];
      var currentIdx = parseInt(this._ctx.currentPlayer);
      var nextIdx = (currentIdx + 1) % players.length;
      var wasLastPlayer = nextIdx === 0;

      this._ctx = {
        ...this._ctx,
        currentPlayer: String(nextIdx),
        turn: wasLastPlayer ? this._ctx.turn + 1 : this._ctx.turn,
      };

      // 如果阶段有 onTurnStart
      var phaseCfg = this._getPhaseConfig();
      if (phaseCfg.onTurnStart) phaseCfg.onTurnStart(this._G, this._ctx);

      this._emit('turn', { player: this._ctx.currentPlayer, turn: this._ctx.turn });
      this._emit('state', this.getState());
      return this;
    };

    // 获取完整状态
    game.getState = function() {
      return {
        G: JSON.parse(JSON.stringify(this._G)),
        ctx: {
          currentPlayer: this._ctx.currentPlayer,
          phase: this._ctx.phase,
          turn: this._ctx.turn,
          gameover: this._ctx.gameover,
        },
        moveCount: this._moveCount,
      };
    };

    return game;
  }

  return { create: create };
})();
