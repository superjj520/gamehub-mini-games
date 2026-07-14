/**
 * 大富翁 — boardgame.io 模式重构
 * 阶段: roll → action → endTurn
 * Moves: rollDice, buyProperty, buildBuilding, drawCard, payRent, endTurn
 */
var MonopolyGame = (function() {
  var game = null;
  var _container = null;
  var _gridResult = null; // { board, element, config }
  var _pieceEls = [];
  var _statusEl = null;
  var _renderFn = null;

  // ─── 创建 game 定义 ───
  function createGame(blocks) {
    // 提取 Block 配置
    var gridBlock = findBlock(blocks, 'grid');
    var chanceBlock = findBlock(blocks, 'collection', '机会');
    var destinyBlock = findBlock(blocks, 'collection', '命运');
    var storeBlock = findBlock(blocks, 'store');
    var ruleBlock = findBlock(blocks, 'rule');
    var playerBlock = findBlock(blocks, 'player');

    var cells = (gridBlock && gridBlock.config.cells) || [];
    var chanceCards = (chanceBlock && chanceBlock.config.cards) || [];
    var destinyCards = (destinyBlock && destinyBlock.config.cards) || [];
    var storeItems = (storeBlock && storeBlock.config.items) || [];
    var ruleVars = getRuleVars(ruleBlock);
    var players = (playerBlock && playerBlock.config.players) || [
      { id:'p1', name:'玩家A', emoji:'🧑', isAI:false, color:'#7C3AED' },
      { id:'p2', name:'玩家B', emoji:'🤖', isAI:true,  color:'#EC4899' },
    ];

    return BoardGameEngine.create({
      _startPhase: 'roll',

      // ─── 初始化游戏状态 ───
      setup: function(ctx) {
        return {
          players: players.map(function(p, i) {
            return {
              id: p.id || 'p' + i,
              name: p.name, emoji: p.emoji, isAI: !!p.isAI, color: p.color,
              position: 0, gold: ruleVars.initialGold || 1500, laps: 0,
              skipNext: false, properties: [], prizes: [], buildings: {},
            };
          }),
          cells: cells,
          chanceCards: ctx.random.shuffle(chanceCards),
          destinyCards: ctx.random.shuffle(destinyCards),
          chanceIdx: 0, destinyIdx: 0,
          storeItems: storeItems,
          rules: ruleVars,
          log: [],
        };
      },

      // ─── Moves ───
      moves: {
        // 掷骰子并移动
        rollDice: function(G, ctx) {
          var pi = parseInt(ctx.currentPlayer);
          var p = G.players[pi];
          if (p.skipNext) {
            G.players = updatePlayer(G.players, pi, { skipNext: false });
            G.log = addLog(G.log, p.emoji + ' ' + p.name + ' 本回合跳过');
            return moveToPhase(G, 'endTurn');
          }
          var dice = ctx.random.D6();
          var totalCells = G.cells.length;
          var newPos = (p.position + dice) % totalCells;
          var passedStart = p.position + dice >= totalCells;
          var newGold = p.gold + (passedStart ? (G.rules.startBonus || 200) : 0);
          var newLaps = p.laps + (passedStart ? 1 : 0);

          G.players = updatePlayer(G.players, pi, {
            position: newPos, gold: newGold, laps: newLaps
          });
          G.lastDice = dice;
          G.log = addLog(G.log, p.emoji + ' ' + p.name + ' 掷出 ' + dice + ' 点 → 格' + (newPos+1));
          if (passedStart) G.log = addLog(G.log, '🚩 经过起点 +' + (G.rules.startBonus||200) + ' 金币');

          // 落地自动处理
          var cell = G.cells[newPos];
          if (cell) {
            if (cell.type === 'chance') {
              return moveToPhase(G, 'card');
            } else if (cell.type === 'destiny') {
              return moveToPhase(G, 'card');
            }
          }
          // 检查胜利
          if (newLaps >= (G.rules.maxLaps || 5)) {
            G.log = addLog(G.log, '🏆 ' + p.name + ' 获胜！');
            return { ...G, winner: pi };
          }
          return moveToPhase(G, 'action');
        },

        // 购买当前地产
        buyProperty: function(G, ctx) {
          var pi = parseInt(ctx.currentPlayer);
          var p = G.players[pi];
          var cell = G.cells[p.position];
          if (!cell || cell.type !== 'property' || !cell.price) return G;
          if (p.properties.indexOf(p.position) !== -1) return G;
          if (p.gold < cell.price) return G;

          G.players = updatePlayer(G.players, pi, {
            gold: p.gold - cell.price,
            properties: p.properties.concat([p.position]),
          });
          G.log = addLog(G.log, '🏠 ' + p.name + ' 购买 ' + cell.name + ' (-' + cell.price + ')');
          return G;
        },

        // 建造建筑
        buildBuilding: function(G, ctx, itemId) {
          var pi = parseInt(ctx.currentPlayer);
          var p = G.players[pi];
          var item = null;
          for (var i = 0; i < G.storeItems.length; i++) {
            if (G.storeItems[i].id === itemId) { item = G.storeItems[i]; break; }
          }
          if (!item || p.gold < item.cost) return G;

          var buildings = { ...p.buildings };
          buildings[itemId] = (buildings[itemId] || 0) + 1;
          G.players = updatePlayer(G.players, pi, {
            gold: p.gold - item.cost, buildings: buildings
          });
          G.log = addLog(G.log, '🏗️ ' + p.name + ' 建造 ' + item.name + ' (-' + item.cost + ')');
          return G;
        },

        // 抽卡(机会/命运)
        drawCard: function(G, ctx) {
          var pi = parseInt(ctx.currentPlayer);
          var p = G.players[pi];
          var cell = G.cells[p.position];
          var isChance = cell && cell.type === 'chance';
          var deck = isChance ? G.chanceCards : G.destinyCards;
          var idxKey = isChance ? 'chanceIdx' : 'destinyIdx';
          var card = deck[G[idxKey] % deck.length];
          G[idxKey] = G[idxKey] + 1;

          if (!card) return moveToPhase(G, 'action');

          G.log = addLog(G.log, '🃏 ' + p.name + ' 抽到: ' + card.title);

          if (card.effect) {
            if (card.effect.gold) {
              G.players = updatePlayer(G.players, pi, { gold: Math.max(0, p.gold + card.effect.gold) });
            }
            if (card.effect.move) {
              var totalCells = G.cells.length;
              var newPos = ((p.position + card.effect.move) % totalCells + totalCells) % totalCells;
              G.players = updatePlayer(G.players, pi, { position: newPos });
              G.log = addLog(G.log, '➡️ 移动至格' + (newPos+1));
            }
            if (card.effect.skip) {
              G.players = updatePlayer(G.players, pi, { skipNext: true });
            }
            if (card.effect.swap) {
              var other = pi === 0 ? 1 : 0;
              var otherPos = G.players[other].position;
              G.players = updatePlayer(G.players, pi, { position: otherPos });
              G.players = updatePlayer(G.players, other, { position: p.position });
            }
          }
          return moveToPhase(G, 'action');
        },

        // 结束回合
        endTurn: function(G) {
          return moveToPhase(G, 'roll');
        },
      },

      // ─── Phases ───
      phases: {
        roll: {
          moves: ['rollDice'],
          onEnter: function(G, ctx) {
            var pi = parseInt(ctx.currentPlayer);
            var p = G.players[pi];
            // AI 自动掷骰子
            if (p.isAI) {
              setTimeout(function() {
                if (game) { game.move('rollDice'); handleCellEffect(); }
              }, 1000);
            }
          },
        },
        action: {
          moves: ['buyProperty', 'buildBuilding', 'endTurn'],
          onEnter: function(G, ctx) {
            var pi = parseInt(ctx.currentPlayer);
            var p = G.players[pi];
            // AI 自动决策：能买就买
            if (p.isAI) {
              var cell = G.cells[p.position];
              if (cell && cell.type === 'property' && cell.price && p.gold >= cell.price && p.properties.indexOf(p.position) === -1) {
                setTimeout(function() { game.move('buyProperty'); game.move('endTurn'); }, 800);
              } else {
                setTimeout(function() { game.move('endTurn'); }, 600);
              }
            }
          },
        },
        card: {
          moves: ['drawCard'],
          onEnter: function(G) {
            // 自动抽卡
            setTimeout(function() { game.move('drawCard'); }, 300);
          },
        },
      },

      // ─── 游戏结束条件 ───
      endIf: function(G) {
        return G.winner != null ? G.winner : null;
      },
    });
  }

  // ─── 辅助函数 ───
  function findBlock(blocks, type, labelMatch) {
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].type !== type) continue;
      if (labelMatch && blocks[i].label.indexOf(labelMatch) === -1) continue;
      return blocks[i];
    }
    return null;
  }

  function getRuleVars(block) {
    var vars = {};
    if (!block || !block.config.variables) return vars;
    for (var i = 0; i < block.config.variables.length; i++) {
      vars[block.config.variables[i].key] = block.config.variables[i].value;
    }
    return vars;
  }

  function updatePlayer(players, idx, updates) {
    var copy = players.slice();
    copy[idx] = { ...copy[idx], ...updates };
    return copy;
  }

  function addLog(log, msg) {
    return log.concat([msg]).slice(-50);
  }

  function moveToPhase(G, phase) {
    G._nextPhase = phase;
    return G;
  }

  // ─── 落地格子效果处理 ───
  function handleCellEffect() {
    var state = game.getState();
    var G = state.G;
    var ctx = state.ctx;
    if (!G || ctx.gameover != null) return;

    var pi = parseInt(ctx.currentPlayer);
    var p = G.players[pi];
    var cell = G.cells[p.position];

    // 延迟自动移动到正确阶段
    setTimeout(function() {
      if (!game) return;
      var s = game.getState();
      if (s.ctx.gameover != null) return;

      if (cell && (cell.type === 'chance' || cell.type === 'destiny')) {
        // 已在 card 阶段处理
      }
    }, 100);
  }

  // ─── 渲染 ───
  function renderBoard(G, ctx) {
    if (!_gridResult || !_gridResult.board) return;
    var board = _gridResult.board;

    // 清除高亮
    for (var i = 0; i < G.cells.length; i++) {
      if (typeof GridRenderer !== 'undefined') {
        GridRenderer.updateCell(board, i, { highlight: false });
      }
    }

    // 高亮当前位置
    var pi = parseInt(ctx.currentPlayer);
    var p = G.players[pi];
    if (typeof GridRenderer !== 'undefined') {
      GridRenderer.updateCell(board, p.position, { highlight: true });
    }

    // 放置棋子
    for (var j = 0; j < G.players.length; j++) {
      if (_pieceEls[j]) {
        var pos = typeof GridRenderer !== 'undefined' ? GridRenderer.getCellPosition(board, G.players[j].position) : { x:0, y:0 };
        var ox = j * 8 - 4;
        var oy = j * 6 - 3;
        if (typeof PieceController !== 'undefined') {
          PieceController.placePiece(_pieceEls[j], pos, ox, oy);
        }
      }
    }
  }

  // ─── 启动 ───
  function start(container, blocks) {
    _container = container;
    container.innerHTML = '';

    // 渲染棋盘
    var gridBlock = findBlock(blocks, 'grid');
    if (gridBlock && typeof GridRenderer !== 'undefined') {
      var gridDiv = document.createElement('div');
      gridDiv.style.position = 'relative';
      container.appendChild(gridDiv);
      var board = GridRenderer.render(gridDiv, gridBlock.config);
      _gridResult = { element: gridDiv, board: board, config: gridBlock.config };
    }

    // 创建游戏引擎(不立即启动)
    game = createGame(blocks);

    // ⚠️ 先注册所有监听器，再启动
    game.on('state', function(state) {
      renderBoard(state.G, state.ctx);
      if (typeof window !== 'undefined' && window._onMonopolyState) {
        window._onMonopolyState(state);
      }
    });

    game.on('state', function(state) {
      if (typeof window !== 'undefined' && window._onMonopolyStatus) {
        var G = state.G;
        var ctx = state.ctx;
        var lastLog = G.log && G.log.length > 0 ? G.log[G.log.length - 1] : '';
        if (ctx.gameover != null) {
          window._onMonopolyStatus('🏆 ' + G.players[ctx.gameover].name + ' 获胜！');
        } else {
          var pi = parseInt(ctx.currentPlayer);
          window._onMonopolyStatus(lastLog || ('🎲 ' + (G.players[pi] ? G.players[pi].name : '') + ' 的回合'));
        }
      }
    });

    // 处理 _nextPhase (在 moves 中设置)
    var origMove = game.move.bind(game);
    game.move = function(moveName, args) {
      var result = origMove(moveName, args);
      var G = game.getState().G;
      if (G._nextPhase) {
        game.setPhase(G._nextPhase);
      }
      return result;
    };

    // 启动引擎（触发初始状态→监听器收到通知）
    game.start(container, blocks);

    // 创建棋子
    var G = game.getState().G;
    if (_gridResult && typeof PieceController !== 'undefined') {
      _pieceEls = [];
      for (var i = 0; i < G.players.length; i++) {
        var el = PieceController.createPieceEl(G.players[i], i);
        _gridResult.element.appendChild(el);
        _pieceEls.push(el);
      }
    }

    // 初始渲染
    renderBoard(game.getState().G, game.getState().ctx);

    return game;
  }

  return {
    start: start,
    rollDice:   function() { if (game) game.move('rollDice'); },
    buyProperty: function() { if (game) game.move('buyProperty'); },
    buildBuilding: function(id) { if (game) game.move('buildBuilding', id); },
    endTurn:    function() { if (game) game.move('endTurn'); },
  };
})();
