/**
 * 贪吃蛇 — 实时网格移动，方向键控制
 * 依赖：GameEngine, GridRenderer, PieceController, RuleEngine, EffectEngine
 */
const SnakeGame = (() => {
  var ctx = null, state = null, loopTimer = null;

  function start(gameCtx) {
    ctx = gameCtx;
    var gridBlock = findBlock('grid');
    var ruleBlock = findBlock('rule');
    var ruleCfg = getRuleVars(ruleBlock);
    var rows = gridBlock ? (gridBlock.config.rows || 15) : 15;
    var cols = gridBlock ? (gridBlock.config.cols || 15) : 15;

    state = {
      snake: [{ r: Math.floor(rows/2), c: Math.floor(cols/2) }],
      food: null,
      direction: { dr: 0, dc: 1 },
      nextDir: { dr: 0, dc: 1 },
      score: 0,
      speed: ruleCfg.speed || 150,
      growCount: ruleCfg.growCount || 1,
      gameOver: false,
      gridRows: rows, gridCols: cols,
    };

    // 渲染全网格
    var gridResult = ctx.blockResults[gridBlock.id];
    if (gridResult && gridResult.element) {
      gridResult.element.style.position = 'relative';
      var fullGrid = buildFullGrid(gridResult.element, rows, cols);
      state.gridEl = fullGrid;
      spawnFood();
      renderAll();
    }

    document.addEventListener('keydown', handleKey);
    emitStatus('🐍 使用方向键控制蛇的方向');
    startLoop();
  }

  function buildFullGrid(container, rows, cols) {
    container.innerHTML = '';
    var el = document.createElement('div');
    el.style.cssText = 'display:grid;grid-template-columns:repeat(' + cols + ',1fr);grid-template-rows:repeat(' + rows + ',1fr);gap:1px;width:100%;aspect-ratio:' + cols + '/' + rows + ';background:rgba(255,255,255,0.03);position:relative;';
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        var cell = document.createElement('div');
        cell.id = 'sc-' + r + '-' + c;
        cell.style.cssText = 'background:var(--card);border-radius:2px;transition:background 0.1s;';
        el.appendChild(cell);
      }
    }
    container.appendChild(el);
    return el;
  }

  function handleKey(e) {
    var dir = state.direction;
    switch(e.key) {
      case 'ArrowUp':    if (dir.dr !== 1)  state.nextDir = { dr: -1, dc: 0 }; e.preventDefault(); break;
      case 'ArrowDown':  if (dir.dr !== -1) state.nextDir = { dr: 1,  dc: 0 }; e.preventDefault(); break;
      case 'ArrowLeft':  if (dir.dc !== 1)  state.nextDir = { dr: 0,  dc: -1 }; e.preventDefault(); break;
      case 'ArrowRight': if (dir.dc !== -1) state.nextDir = { dr: 0,  dc: 1 }; e.preventDefault(); break;
    }
  }

  function startLoop() {
    if (loopTimer) clearInterval(loopTimer);
    loopTimer = setInterval(tick, state.speed);
  }

  function tick() {
    if (state.gameOver) { clearInterval(loopTimer); return; }
    state.direction = state.nextDir;
    var head = state.snake[0];
    var newHead = { r: head.r + state.direction.dr, c: head.c + state.direction.dc };

    // 撞墙检测
    if (newHead.r < 0 || newHead.r >= state.gridRows || newHead.c < 0 || newHead.c >= state.gridCols) {
      endGame('撞墙了！');
      return;
    }
    // 撞自己
    for (var i = 0; i < state.snake.length; i++) {
      if (state.snake[i].r === newHead.r && state.snake[i].c === newHead.c) {
        endGame('咬到自己了！');
        return;
      }
    }

    state.snake.unshift(newHead);
    // 吃食物
    if (state.food && newHead.r === state.food.r && newHead.c === state.food.c) {
      state.score += 10;
      spawnFood();
      // 加速
      if (state.speed > 50) { state.speed -= 3; startLoop(); }
    } else {
      state.snake.pop();
    }
    renderAll();
    emitState();
  }

  function spawnFood() {
    var occupied = {};
    for (var i = 0; i < state.snake.length; i++) {
      occupied[state.snake[i].r + ',' + state.snake[i].c] = true;
    }
    var available = [];
    for (var r = 0; r < state.gridRows; r++) {
      for (var c = 0; c < state.gridCols; c++) {
        if (!occupied[r + ',' + c]) available.push({ r: r, c: c });
      }
    }
    if (available.length === 0) { endGame('你赢了！蛇占满了整个棋盘'); return; }
    state.food = available[Math.floor(Math.random() * available.length)];
  }

  function renderAll() {
    if (!state.gridEl) return;
    // 清除所有样式
    var cells = state.gridEl.querySelectorAll('[id^="sc-"]');
    for (var i = 0; i < cells.length; i++) {
      cells[i].style.background = 'var(--card)';
    }
    // 渲染蛇身
    for (var j = 0; j < state.snake.length; j++) {
      var s = state.snake[j];
      var cel = document.getElementById('sc-' + s.r + '-' + s.c);
      if (cel) cel.style.background = j === 0 ? 'var(--accent)' : 'var(--accent2)';
    }
    // 渲染食物
    if (state.food) {
      var fcel = document.getElementById('sc-' + state.food.r + '-' + state.food.c);
      if (fcel) { fcel.style.background = 'var(--gold)'; fcel.style.boxShadow = '0 0 6px var(--gold)'; }
    }
  }

  function endGame(msg) {
    state.gameOver = true;
    clearInterval(loopTimer);
    document.removeEventListener('keydown', handleKey);
    emitStatus('🏁 ' + msg + ' 得分: ' + state.score);
    emitState();
  }

  function getRuleVars(block) {
    var vars = {};
    if (!block) return vars;
    var variables = block.config.variables || [];
    for (var i = 0; i < variables.length; i++) vars[variables[i].key] = variables[i].value;
    return vars;
  }

  function findBlock(type) {
    var blocks = ctx.config.blocks || [];
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].type === type) return blocks[i];
    }
    return null;
  }

  function emitState() {
    if (ctx && ctx.engine) ctx.engine.emit('game:state', { score: state.score, gameOver: state.gameOver, snake: state.snake });
  }
  function emitStatus(msg) {
    if (ctx && ctx.engine) ctx.engine.emit('game:status', msg);
  }

  function getState() { return state; }

  return { start, getState };
})();
