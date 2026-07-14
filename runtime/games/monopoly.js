/**
 * 大富翁游戏逻辑 — Block 驱动，回合制
 * 依赖：GameEngine, GridRenderer, CollectionManager, EffectEngine, StoreManager, PieceController, RuleEngine, PlayerManager
 */
const MonopolyGame = (() => {
  var ctx = null;
  var state = null;
  var animating = false;

  function start(gameCtx) {
    ctx = gameCtx;
    var players = gameCtx.players;

    state = {
      players: players.map(function(p) { return { ...p }; }),
      currentPlayer: 0,
      round: 1,
      gameOver: false,
      winner: null,
      pieceEls: [],
      log: [],
    };

    // 获取棋盘容器并在其上放置棋子
    var gridResult = findGridResult();
    if (!gridResult) {
      addLog('❌ 未找到棋盘 Block，请确保配置中包含 Grid 类型的 Block');
      return;
    }

    // 在棋盘容器上放棋子
    if (typeof PieceController !== 'undefined') {
      var gridContainer = gridResult.element;
      // 确保容器有 position:relative
      gridContainer.style.position = 'relative';
      state.pieceEls = [];
      for (var i = 0; i < players.length; i++) {
        var pieceEl = PieceController.createPieceEl(players[i], i);
        gridContainer.appendChild(pieceEl);
        state.pieceEls.push(pieceEl);
      }
      placeAllPieces();
    }

    // 渲染 UI
    emitState();
    emitStatus('🎲 ' + players[0].name + ' 的回合，请掷骰子');

    // 如果当前玩家是 AI，自动掷骰子
    if (players[0].isAI) {
      setTimeout(function() { handleRollDice(); }, 1200);
    }
  }

  // ─── 掷骰子 ───
  function handleRollDice() {
    if (state.gameOver || animating) return;
    var pi = state.currentPlayer;
    var player = state.players[pi];

    // 检查是否被跳过
    if (player.skipNext) {
      state.players[pi] = { ...player, skipNext: false };
      addLog(player.emoji + ' ' + player.name + ' 本回合被跳过');
      emitStatus(player.emoji + ' ' + player.name + ' ⏸️ 暂停一回合');
      setTimeout(function() { nextTurn(); }, 1200);
      return;
    }

    // 骰子
    var ruleCfg = getRuleConfig();
    var diceMin = ruleCfg.diceMin || 1;
    var diceMax = ruleCfg.diceMax || 6;
    var steps = Math.floor(Math.random() * (diceMax - diceMin + 1)) + diceMin;

    addLog(player.emoji + ' ' + player.name + ' 掷出 ' + steps + ' 点');
    emitStatus('🎲 ' + player.name + ' 掷出 ' + steps + ' 点');

    // 计算新位置
    var gridBlock = findBlockByType('grid');
    var totalCells = (gridBlock && gridBlock.config.cells) ? gridBlock.config.cells.length : 24;
    var fromPos = player.position;

    animating = true;
    animateStepByStep(pi, fromPos, steps, totalCells, function(newPos, passedStart) {
      // 更新玩家位置
      var newPlayer = { ...state.players[pi], position: newPos };
      if (passedStart) {
        var startBonus = ruleCfg.startBonus || 200;
        newPlayer = PlayerManager.addGold(newPlayer, startBonus);
        newPlayer.laps += 1;
        addLog('🚩 ' + player.name + ' 经过起点 +' + startBonus + ' 金币 (第' + newPlayer.laps + '圈)');
        emitStatus('🚩 ' + player.name + ' 经过起点 +' + startBonus + ' 金币');
      }
      state.players[pi] = newPlayer;

      // 落地效果
      var cellData = findCellData(newPos);
      if (cellData) {
        handleLandOnCell(pi, cellData);
      }

      // 检查胜利
      var maxLaps = ruleCfg.maxLaps || 5;
      if (newPlayer.laps >= maxLaps) {
        state.gameOver = true;
        state.winner = newPlayer;
        emitStatus('🏆 ' + newPlayer.name + ' 获得胜利！走了 ' + newPlayer.laps + ' 圈');
        emitState();
        animating = false;
        return;
      }

      animating = false;
      emitState();

      // 下一个玩家
      setTimeout(function() { nextTurn(); }, 800);
    });
  }

  // ─── 逐格动画移动 ───
  function animateStepByStep(playerIdx, fromPos, steps, totalCells, callback) {
    var gridResult = findGridResult();
    if (!gridResult || !state.pieceEls) { callback(fromPos, false); return; }

    var current = fromPos;
    var moved = 0;
    var passedStart = false;
    var pieceEl = state.pieceEls[playerIdx];
    var offsetY = playerIdx * 8 - 4;
    var offsetX = playerIdx * 10 - 5;

    function moveNext() {
      if (moved >= steps) {
        GridRenderer.clearHighlights(gridResult.board);
        callback(current, passedStart);
        return;
      }

      current = (current + 1) % totalCells;
      if (current === 0) passedStart = true;
      moved++;

      GridRenderer.clearHighlights(gridResult.board);
      GridRenderer.updateCell(gridResult.board, current, { highlight: true });

      var pos = GridRenderer.getCellPosition(gridResult.board, current);
      PieceController.animatePiece(pieceEl, pos, 250, offsetX, offsetY).then(function() {
        moveNext();
      });
    }

    moveNext();
  }

  // ─── 落地格处理 ───
  function handleLandOnCell(pi, cellData) {
    var player = state.players[pi];

    switch (cellData.type) {
      case 'property':
        if (!cellData.price) return;
        emitStatus('🏠 ' + cellData.name + ' — 购买价 ' + cellData.price + ' 金币，当前租金 ' + (cellData.rent ? cellData.rent[0] : 0));
        addLog('📍 ' + player.name + ' 到达 ' + cellData.name + '（可购买）');
        break;

      case 'chance':
        emitStatus('🃏 ' + player.name + ' 抽机会卡...');
        setTimeout(function() { drawCard(pi, 'chance'); }, 600);
        break;

      case 'destiny':
        emitStatus('🔮 ' + player.name + ' 抽命运卡...');
        setTimeout(function() { drawCard(pi, 'destiny'); }, 600);
        break;

      case 'jail':
        state.players[pi] = { ...player, skipNext: true };
        addLog('🚔 ' + player.name + ' 被监禁！下回合跳过');
        emitStatus('🚔 ' + player.name + ' 被监禁！下回合跳过');
        break;

      case 'shop':
        addLog('🏪 ' + player.name + ' 到达商铺街');
        emitStatus('🏪 ' + player.name + ' 到达商铺街，可获得商铺奖励');
        break;

      case 'event':
        if (cellData.effect && cellData.effect.gold) {
          state.players[pi] = PlayerManager.addGold(player, cellData.effect.gold);
          if (cellData.effect.gold > 0) {
            addLog('🍀 ' + player.name + ' +' + cellData.effect.gold + ' 金币');
            emitStatus('🍀 ' + player.name + ' +' + cellData.effect.gold + ' 金币');
          } else {
            addLog('💸 ' + player.name + ' ' + cellData.effect.gold + ' 金币');
            emitStatus('💸 ' + player.name + ' ' + cellData.effect.gold + ' 金币');
          }
        }
        break;

      case 'start':
        // 已经在 passedStart 中处理
        break;

      default:
        addLog('📍 ' + player.name + ' 到达 ' + (cellData.name || '未知格'));
    }

    emitState();
  }

  // ─── 抽卡 ───
  function drawCard(pi, deckType) {
    var player = state.players[pi];
    var label = deckType === 'chance' ? '机会卡' : '命运卡';
    var block = findBlockByType('collection', label);
    if (!block) {
      addLog('❌ 未找到' + label + ' Block');
      return;
    }

    var result = CollectionManager.draw(block.config);
    if (!result.card) return;

    var card = result.card;
    addLog('🃏 ' + player.name + ' 抽到: ' + card.title);
    emitStatus('🃏 ' + card.title);

    if (!card.effect) return;

    var p = state.players[pi];

    if (card.effect.gold) {
      p = PlayerManager.addGold(p, card.effect.gold);
      addLog('💰 ' + (card.effect.gold > 0 ? '+' : '') + card.effect.gold + ' 金币');
    }
    if (card.effect.move) {
      var gridBlock = findBlockByType('grid');
      var totalCells = (gridBlock && gridBlock.config.cells) ? gridBlock.config.cells.length : 24;
      p = PlayerManager.movePlayer(p, card.effect.move, totalCells);
      addLog('➡️ 移动 ' + card.effect.move + ' 格');
    }
    if (card.effect.skip) {
      p = { ...p, skipNext: true };
    }
    if (card.effect.swap) {
      var other = pi === 0 ? 1 : 0;
      var tempPos = p.position;
      p = { ...p, position: state.players[other].position };
      state.players[other] = { ...state.players[other], position: tempPos };
      addLog('🔄 与对手交换位置！');
      placeAllPieces();
    }
    if (card.effect.prize) {
      p = PlayerManager.addPrize(p, card.effect.prize);
    }

    state.players[pi] = p;
    emitState();
  }

  // ─── 购买地产 ───
  function buyProperty() {
    if (state.gameOver || animating) return;
    var pi = state.currentPlayer;
    var player = state.players[pi];
    var cellData = findCellData(player.position);

    if (!cellData || cellData.type !== 'property' || !cellData.price) {
      emitStatus('❌ 当前位置不可购买');
      return;
    }
    if (player.properties.indexOf(cellData.index) !== -1) {
      emitStatus('❌ 你已经拥有 ' + cellData.name);
      return;
    }
    if (player.gold < cellData.price) {
      emitStatus('❌ 金币不足！需要 ' + cellData.price + ' 金币，当前 ' + player.gold);
      return;
    }

    state.players[pi] = PlayerManager.addProperty(
      PlayerManager.addGold(player, -cellData.price),
      cellData.index
    );
    addLog('🏠 ' + player.name + ' 购买了 ' + cellData.name + '！(-' + cellData.price + ' 金币)');
    emitStatus('🏠 ' + player.name + ' 购买了 ' + cellData.name + '！');
    emitState();
  }

  // ─── 建造建筑 ───
  function buildBuilding(itemId) {
    if (state.gameOver || animating) return;
    var pi = state.currentPlayer;
    var player = state.players[pi];
    var storeBlock = findBlockByType('store');
    if (!storeBlock) return;

    var item = StoreManager.findItem(storeBlock.config, itemId);
    if (!item) return;

    if (!StoreManager.canBuy(player, item)) {
      emitStatus('❌ 金币不足！需要 ' + item.cost + ' 金币');
      return;
    }

    state.players[pi] = StoreManager.buy(player, item);
    addLog('🏗️ ' + player.name + ' 建造了 ' + item.name + '！(-' + item.cost + ' 金币)');
    emitStatus('🏗️ ' + player.name + ' 建造了 ' + item.name + '！');
    emitState();
  }

  // ─── 回合切换 ───
  function nextTurn() {
    if (state.gameOver) return;
    state.currentPlayer = (state.currentPlayer + 1) % state.players.length;
    if (state.currentPlayer === 0) state.round++;

    emitState();

    // AI 自动行动
    if (state.players[state.currentPlayer].isAI) {
      emitStatus('🤖 ' + state.players[state.currentPlayer].name + ' 思考中...');
      setTimeout(function() { handleRollDice(); }, 1500);
    } else {
      emitStatus('🎲 ' + state.players[state.currentPlayer].name + ' 的回合，请掷骰子');
    }
  }

  // ─── 辅助 ───
  function findBlockByType(type, labelMatch) {
    var blocks = ctx.config.blocks || [];
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].type !== type) continue;
      if (labelMatch && blocks[i].label.indexOf(labelMatch) === -1) continue;
      return blocks[i];
    }
    return null;
  }

  function findGridResult() {
    var results = ctx.blockResults || {};
    var keys = Object.keys(results);
    for (var i = 0; i < keys.length; i++) {
      if (results[keys[i]].board) return results[keys[i]];
    }
    return null;
  }

  function getRuleConfig() {
    var block = findBlockByType('rule');
    if (!block) return {};
    var vars = {};
    var variables = block.config.variables || [];
    for (var i = 0; i < variables.length; i++) {
      vars[variables[i].key] = variables[i].value;
    }
    return vars;
  }

  function findCellData(index) {
    var block = findBlockByType('grid');
    if (!block) return null;
    var cells = block.config.cells || [];
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].index === index) return cells[i];
    }
    return null;
  }

  function placeAllPieces() {
    var gridResult = findGridResult();
    if (!gridResult || !state.pieceEls) return;
    for (var i = 0; i < state.players.length; i++) {
      var pos = GridRenderer.getCellPosition(gridResult.board, state.players[i].position);
      PieceController.placePiece(state.pieceEls[i], pos, i * 10 - 5, i * 8 - 4);
    }
  }

  function addLog(msg) {
    state.log = (state.log || []).concat([msg]).slice(-50);
  }

  function emitState() {
    if (ctx && ctx.engine) {
      ctx.engine.emit('monopoly:state', {
        players: state.players.map(function(p) { return { ...p }; }),
        currentPlayer: state.currentPlayer,
        round: state.round,
        gameOver: state.gameOver,
        winner: state.winner,
        log: (state.log || []).slice(-10),
      });
    }
  }

  function emitStatus(msg) {
    if (ctx && ctx.engine) {
      ctx.engine.emit('monopoly:status', msg);
    }
  }

  function getState() { return state; }

  return {
    start: start,
    getState: getState,
    rollDice: handleRollDice,
    buyProperty: buyProperty,
    buildBuilding: buildBuilding,
  };
})();
