/**
 * 消消乐 — 点击交换相邻方块，三连消除
 * 依赖：GridRenderer, RuleEngine, EffectEngine
 */
const Match3Game = (() => {
  var ctx = null, state = null;
  var COLORS = ['🔴','🟠','🟡','🟢','🔵','🟣'];

  function start(gameCtx) {
    ctx = gameCtx;
    var gridBlock = findBlock('grid');
    var ruleBlock = findBlock('rule');
    var ruleCfg = getRuleVars(ruleBlock);
    var rows = gridBlock ? (gridBlock.config.rows || 8) : 8;
    var cols = gridBlock ? (gridBlock.config.cols || 8) : 8;
    var colorCount = ruleCfg.colorCount || 6;

    state = {
      rows: rows, cols: cols, colorCount: colorCount,
      grid: [], score: 0, selected: null, gameOver: false,
      maxMoves: ruleCfg.maxMoves || 30, movesLeft: ruleCfg.maxMoves || 30,
    };
    initGrid();
    while (findMatches().length > 0) { removeMatches(); fillDown(); }
    renderGrid();
    emitStatus('💎 点击两个相邻方块交换');
  }

  function initGrid() {
    for (var r = 0; r < state.rows; r++) {
      state.grid[r] = [];
      for (var c = 0; c < state.cols; c++) {
        state.grid[r][c] = Math.floor(Math.random() * state.colorCount);
      }
    }
  }

  function findMatches() {
    var matches = [];
    // 水平
    for (var r = 0; r < state.rows; r++) {
      for (var c = 0; c < state.cols - 2; c++) {
        if (state.grid[r][c] === -1) continue;
        var v = state.grid[r][c];
        var len = 1;
        while (c + len < state.cols && state.grid[r][c + len] === v) len++;
        if (len >= 3) { for (var i = 0; i < len; i++) matches.push({ r: r, c: c + i }); }
        c += len - 1;
      }
    }
    // 垂直
    for (var c = 0; c < state.cols; c++) {
      for (var r = 0; r < state.rows - 2; r++) {
        if (state.grid[r][c] === -1) continue;
        var v = state.grid[r][c];
        var len = 1;
        while (r + len < state.rows && state.grid[r + len][c] === v) len++;
        if (len >= 3) { for (var i = 0; i < len; i++) matches.push({ r: r + i, c: c }); }
        r += len - 1;
      }
    }
    // 去重
    var seen = {}, unique = [];
    for (var i = 0; i < matches.length; i++) {
      var k = matches[i].r + ',' + matches[i].c;
      if (!seen[k]) { seen[k] = true; unique.push(matches[i]); }
    }
    return unique;
  }

  function removeMatches() {
    var matches = findMatches();
    if (matches.length === 0) return 0;
    for (var i = 0; i < matches.length; i++) {
      state.grid[matches[i].r][matches[i].c] = -1;
    }
    state.score += matches.length * 10;
    return matches.length;
  }

  function fillDown() {
    for (var c = 0; c < state.cols; c++) {
      var col = [];
      for (var r = 0; r < state.rows; r++) {
        if (state.grid[r][c] !== -1) col.push(state.grid[r][c]);
      }
      while (col.length < state.rows) col.unshift(Math.floor(Math.random() * state.colorCount));
      for (var r = 0; r < state.rows; r++) state.grid[r][c] = col[r];
    }
  }

  function swap(r1, c1, r2, c2) {
    var t = state.grid[r1][c1];
    state.grid[r1][c1] = state.grid[r2][c2];
    state.grid[r2][c2] = t;
  }

  function isAdjacent(r1, c1, r2, c2) {
    return Math.abs(r1 - r2) + Math.abs(c1 - c2) === 1;
  }

  function handleClick(r, c) {
    if (state.gameOver || state.movesLeft <= 0) return;
    if (state.selected === null) {
      state.selected = { r: r, c: c };
      renderGrid();
      return;
    }
    if (state.selected.r === r && state.selected.c === c) {
      state.selected = null; renderGrid(); return;
    }
    if (!isAdjacent(state.selected.r, state.selected.c, r, c)) {
      state.selected = { r: r, c: c }; renderGrid(); return;
    }

    swap(state.selected.r, state.selected.c, r, c);
    var removed = removeMatches();
    if (removed === 0) {
      swap(state.selected.r, state.selected.c, r, c); // 交换回来
    } else {
      state.movesLeft--;
      // 连锁消除
      while (true) {
        fillDown();
        var more = removeMatches();
        if (more === 0) break;
      }
    }
    state.selected = null;
    renderGrid();
    emitState();
    if (state.movesLeft <= 0) { state.gameOver = true; emitStatus('🏁 步数用完！得分:' + state.score); }
  }

  function renderGrid() {
    ctx.container.innerHTML = '';
    var board = document.createElement('div');
    board.style.cssText = 'display:grid;grid-template-columns:repeat(' + state.cols + ',1fr);grid-template-rows:repeat(' + state.rows + ',1fr);gap:2px;width:100%;aspect-ratio:' + state.cols + '/' + state.rows + ';max-width:400px;margin:0 auto;';

    for (var r = 0; r < state.rows; r++) {
      for (var c = 0; c < state.cols; c++) {
        var v = state.grid[r][c];
        var cell = document.createElement('div');
        cell.style.cssText = 'display:flex;align-items:center;justify-content:center;font-size:24px;background:var(--card);border-radius:4px;cursor:pointer;transition:transform 0.1s;';
        if (state.selected && state.selected.r === r && state.selected.c === c) {
          cell.style.border = '2px solid var(--gold)';
          cell.style.transform = 'scale(1.1)';
        }
        cell.textContent = COLORS[v] || '⬜';
        (function(rr, cc) { cell.onclick = function() { handleClick(rr, cc); }; })(r, c);
        board.appendChild(cell);
      }
    }
    ctx.container.appendChild(board);

    // 信息
    var info = document.createElement('div');
    info.style.cssText = 'text-align:center;margin-top:12px;font-size:13px;';
    info.innerHTML = '得分: <b>' + state.score + '</b> · 剩余步数: <b>' + state.movesLeft + '</b>';
    ctx.container.appendChild(info);
  }

  function getRuleVars(block) { var v = {}; if (block) (block.config.variables || []).forEach(function(x) { v[x.key] = x.value; }); return v; }
  function findBlock(type) { var b = ctx.config.blocks || []; for (var i = 0; i < b.length; i++) if (b[i].type === type) return b[i]; return null; }
  function emitState() { if (ctx && ctx.engine) ctx.engine.emit('game:state', { score: state.score, movesLeft: state.movesLeft, gameOver: state.gameOver }); }
  function emitStatus(msg) { if (ctx && ctx.engine) ctx.engine.emit('game:status', msg); }
  function getState() { return state; }
  return { start, getState };
})();
