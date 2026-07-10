/**
 * 2048 — 滑动合并，键盘方向键
 * 依赖：GridRenderer, RuleEngine, PieceController
 */
const Game2048 = (() => {
  var ctx = null, state = null;

  function start(gameCtx) {
    ctx = gameCtx;
    var gridBlock = findBlock('grid');
    var ruleBlock = findBlock('rule');
    var ruleCfg = getRuleVars(ruleBlock);
    var size = gridBlock ? (gridBlock.config.rows || 4) : 4;
    state = {
      size: size,
      grid: createEmpty(size),
      score: 0,
      gameOver: false,
      winValue: ruleCfg.winValue || 2048,
    };
    addRandom();
    addRandom();
    renderGrid();
    document.addEventListener('keydown', handleKey);
    emitStatus('🕹️ 使用方向键滑动方块');
  }

  function createEmpty(n) {
    var g = [];
    for (var r = 0; r < n; r++) { g[r] = []; for (var c = 0; c < n; c++) g[r][c] = 0; }
    return g;
  }

  function addRandom() {
    var empty = [];
    for (var r = 0; r < state.size; r++) for (var c = 0; c < state.size; c++) if (state.grid[r][c] === 0) empty.push({r:r,c:c});
    if (empty.length === 0) return;
    var pos = empty[Math.floor(Math.random() * empty.length)];
    state.grid[pos.r][pos.c] = Math.random() < 0.9 ? 2 : 4;
  }

  function handleKey(e) {
    var moved = false;
    switch(e.key) {
      case 'ArrowUp':    moved = move('up'); e.preventDefault(); break;
      case 'ArrowDown':  moved = move('down'); e.preventDefault(); break;
      case 'ArrowLeft':  moved = move('left'); e.preventDefault(); break;
      case 'ArrowRight': moved = move('right'); e.preventDefault(); break;
      default: return;
    }
    if (moved) {
      addRandom();
      renderGrid();
      emitState();
      if (checkWin()) { state.gameOver = true; emitStatus('🏆 达到 ' + state.winValue + '！你赢了！'); }
      if (checkLose()) { state.gameOver = true; emitStatus('💀 无法移动，游戏结束'); }
    }
  }

  function move(dir) {
    var n = state.size, g = state.grid, moved = false;
    var vectors = { up: [-1,0], down: [1,0], left: [0,-1], right: [0,1] };
    var v = vectors[dir];

    var traversals = { r: [], c: [] };
    for (var i = 0; i < n; i++) { traversals.r.push(i); traversals.c.push(i); }
    if (v[0] === 1) traversals.r.reverse();
    if (v[1] === 1) traversals.c.reverse();

    var merged = createEmpty(n);

    for (var ri = 0; ri < n; ri++) {
      for (var ci = 0; ci < n; ci++) {
        var r = traversals.r[ri], c = traversals.c[ci];
        if (g[r][c] === 0) continue;
        var nr = r, nc = c;
        while (true) {
          var tr = nr + v[0], tc = nc + v[1];
          if (tr < 0 || tr >= n || tc < 0 || tc >= n) break;
          if (g[tr][tc] === 0) { nr = tr; nc = tc; moved = true; }
          else if (g[tr][tc] === g[r][c] && !merged[tr][tc]) { nr = tr; nc = tc; merged[tr][tc] = true; moved = true; break; }
          else break;
        }
        if (nr !== r || nc !== c) {
          g[nr][nc] = (g[nr][nc] || 0) + g[r][c];
          if (merged[nr][nc]) state.score += g[nr][nc];
          g[r][c] = 0;
        }
      }
    }
    return moved;
  }

  function checkWin() { for (var r = 0; r < state.size; r++) for (var c = 0; c < state.size; c++) if (state.grid[r][c] >= state.winValue) return true; return false; }
  function checkLose() { for (var r = 0; r < state.size; r++) for (var c = 0; c < state.size; c++) { if (state.grid[r][c] === 0) return false; if (c < state.size-1 && state.grid[r][c] === state.grid[r][c+1]) return false; if (r < state.size-1 && state.grid[r][c] === state.grid[r+1][c]) return false; } return true; }

  function renderGrid() {
    ctx.container.innerHTML = '';
    var board = document.createElement('div');
    board.style.cssText = 'display:grid;grid-template-columns:repeat(' + state.size + ',1fr);grid-template-rows:repeat(' + state.size + ',1fr);gap:4px;width:100%;max-width:360px;aspect-ratio:1;margin:0 auto;background:rgba(255,255,255,0.03);padding:4px;border-radius:8px;';
    var colors = { 0:'rgba(255,255,255,0.03)', 2:'#eee4da', 4:'#ede0c8', 8:'#f2b179', 16:'#f59563', 32:'#f67c5f', 64:'#f65e3b', 128:'#edcf72', 256:'#edcc61', 512:'#edc850', 1024:'#edc53f', 2048:'#edc22e' };
    for (var r = 0; r < state.size; r++) {
      for (var c = 0; c < state.size; c++) {
        var v = state.grid[r][c];
        var cell = document.createElement('div');
        cell.style.cssText = 'display:flex;align-items:center;justify-content:center;font-size:' + (v >= 1000 ? '18px' : '22px') + ';font-weight:800;border-radius:4px;background:' + (colors[v] || '#3c3a32') + ';color:' + (v <= 4 ? '#776e65' : '#fff') + ';';
        cell.textContent = v || '';
        board.appendChild(cell);
      }
    }
    ctx.container.appendChild(board);
  }

  function getRuleVars(block) { var v = {}; if (block) (block.config.variables || []).forEach(function(x) { v[x.key] = x.value; }); return v; }
  function findBlock(type) { var b = ctx.config.blocks || []; for (var i = 0; i < b.length; i++) if (b[i].type === type) return b[i]; return null; }
  function emitState() { if (ctx && ctx.engine) ctx.engine.emit('game:state', { score: state.score, gameOver: state.gameOver, grid: state.grid }); }
  function emitStatus(msg) { if (ctx && ctx.engine) ctx.engine.emit('game:status', msg); }
  function getState() { return state; }
  return { start, getState };
})();
