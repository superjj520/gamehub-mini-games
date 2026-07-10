/**
 * 飞行棋 — 4人棋盘竞技，掷骰子推进
 * 依赖：GridRenderer, PieceController, RuleEngine, PlayerManager
 */
const FlyingChessGame = (() => {
  var ctx = null, state = null;

  function start(gameCtx) {
    ctx = gameCtx;
    var gridBlock = findBlock('grid');
    var ruleBlock = findBlock('rule');
    var ruleCfg = getRuleVars(ruleBlock);
    var playerBlock = findBlock('player');
    var gridCfg = gridBlock ? gridBlock.config : { cells: [] };
    var cells = gridCfg.cells || [];

    var players = (playerBlock && playerBlock.config.players) ? playerBlock.config.players : [
      { id:'p1', name:'红队', emoji:'🔴', color:'#EF4444' },
      { id:'p2', name:'蓝队', emoji:'🔵', color:'#3B82F6' },
      { id:'p3', name:'绿队', emoji:'🟢', color:'#22C55E' },
      { id:'p4', name:'黄队', emoji:'🟡', color:'#F59E0B' },
    ];

    state = {
      players: players.map(function(p) { return { id: p.id, name: p.name, emoji: p.emoji, color: p.color, position: 0, finished: false }; }),
      currentPlayer: 0,
      cells: cells,
      pathLength: cells.length || 52,
      gameOver: false,
      diceMin: ruleCfg.diceMin || 1,
      diceMax: ruleCfg.diceMax || 6,
    };

    renderUI();
    emitStatus('🎲 ' + state.players[0].emoji + ' ' + state.players[0].name + ' 的回合');
  }

  function rollAndMove() {
    if (state.gameOver) return;
    var pi = state.currentPlayer;
    var p = state.players[pi];
    var steps = Math.floor(Math.random() * (state.diceMax - state.diceMin + 1)) + state.diceMin;
    var newPos = p.position + steps;
    var finished = false;

    if (newPos >= state.pathLength) {
      newPos = state.pathLength - 1;
      finished = true;
      p.finished = true;
    }
    p.position = newPos;

    emitStatus(p.emoji + ' ' + p.name + ' 掷出 ' + steps + ' 点，到达 ' + (newPos + 1));

    if (finished) {
      var allDone = state.players.every(function(x) { return x.finished; });
      if (allDone) { state.gameOver = true; emitStatus('🏆 游戏结束！'); emitState(); return; }
    }

    renderUI();
    emitState();
    nextTurn();
  }

  function nextTurn() {
    state.currentPlayer = (state.currentPlayer + 1) % state.players.length;
    if (state.players[state.currentPlayer].finished) {
      nextTurn();
      return;
    }
    if (state.players[state.currentPlayer].isAI) {
      setTimeout(function() { rollAndMove(); }, 1200);
    }
  }

  function renderUI() {
    ctx.container.innerHTML = '';
    // 简单路径可视化
    var track = document.createElement('div');
    track.style.cssText = 'display:flex;flex-wrap:wrap;gap:2px;max-width:500px;margin:0 auto 20px;';
    for (var i = 0; i < state.pathLength; i++) {
      var cell = document.createElement('div');
      cell.style.cssText = 'width:16px;height:16px;border-radius:2px;background:var(--card);font-size:10px;display:flex;align-items:center;justify-content:center;';
      // 显示棋子位置
      for (var j = 0; j < state.players.length; j++) {
        if (state.players[j].position === i) {
          cell.style.background = state.players[j].color;
          cell.textContent = state.players[j].emoji;
          cell.style.fontSize = '8px';
          break;
        }
      }
      track.appendChild(cell);
    }
    ctx.container.appendChild(track);

    // 玩家信息
    var info = document.createElement('div');
    info.style.cssText = 'display:grid;grid-template-columns:1fr 1fr;gap:8px;';
    for (var i = 0; i < state.players.length; i++) {
      var p = state.players[i];
      var bg = (i === state.currentPlayer && !state.gameOver) ? 'border:2px solid var(--gold);' : '';
      info.innerHTML += '<div style="padding:8px;border-radius:8px;background:var(--card);' + bg + '"><span>' + p.emoji + '</span> ' + p.name + ' · 位置 ' + (p.position+1) + (p.finished ? ' ✅' : '') + '</div>';
    }
    ctx.container.appendChild(info);

    // 按钮
    var btn = document.createElement('button');
    btn.textContent = '🎲 掷骰子';
    btn.style.cssText = 'display:block;margin:16px auto;padding:12px 32px;border-radius:10px;border:none;background:linear-gradient(135deg,var(--accent),var(--accent2));color:white;font-size:16px;font-weight:700;cursor:pointer;font-family:inherit;';
    btn.onclick = rollAndMove;
    if (!state.gameOver) ctx.container.appendChild(btn);
  }

  function getRuleVars(block) { var v = {}; if (block) (block.config.variables || []).forEach(function(x) { v[x.key] = x.value; }); return v; }
  function findBlock(type) { var b = ctx.config.blocks || []; for (var i = 0; i < b.length; i++) if (b[i].type === type) return b[i]; return null; }
  function emitState() { if (ctx && ctx.engine) ctx.engine.emit('game:state', state); }
  function emitStatus(msg) { if (ctx && ctx.engine) ctx.engine.emit('game:status', msg); }
  function getState() { return state; }
  return { start, getState, rollDice: rollAndMove };
})();
