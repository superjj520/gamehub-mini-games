/**
 * 棋盘渲染器 — 支持两种模式：
 *   1. 节点模式: { cells: [{id,x,y,...}], pathOrder: [id,...] } — 自由布局地图
 *   2. 网格模式: { rows, cols, cells: [{index,...}] } — 旧版矩形棋盘
 * 依赖：无
 */

var GridRenderer = (function() {

  function render(container, config, callbacks) {
    var cb = callbacks || {};
    // 检测：有 pathOrder 就是节点模式
    if (config.pathOrder && config.pathOrder.length > 0) {
      return renderBoardMode(container, config, cb);
    }
    return renderGridMode(container, config, cb);
  }

  // ─── 节点模式：自由布局地图 ───
  function renderBoardMode(container, config, cb) {
    var cells = config.cells || [];
    var pathOrder = config.pathOrder || [];

    var board = document.createElement('div');
    board.className = 'gh-grid-board';
    board.style.cssText = 'position:relative;width:100%;min-height:400px;overflow:auto;';

    var maxX = 0, maxY = 0;
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].x + 100 > maxX) maxX = cells[i].x + 100;
      if (cells[i].y + 60 > maxY) maxY = cells[i].y + 60;
    }
    board.style.height = Math.max(maxY + 30, 400) + 'px';
    board.style.minWidth = Math.max(maxX + 30, 300) + 'px';

    // SVG 路径层
    if (cells.length >= 2) {
      var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      svg.style.cssText = 'position:absolute;inset:0;pointer-events:none;z-index:0;';
      svg.setAttribute('viewBox', '0 0 ' + (maxX + 100) + ' ' + (maxY + 60));
      svg.setAttribute('width', (maxX + 100));
      svg.setAttribute('height', (maxY + 60));

      var defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs');
      var marker = document.createElementNS('http://www.w3.org/2000/svg', 'marker');
      marker.setAttribute('id', 'gh-arrow-' + Date.now().toString(36));
      marker.setAttribute('markerWidth', '8'); marker.setAttribute('markerHeight', '8');
      marker.setAttribute('refX', '4'); marker.setAttribute('refY', '4'); marker.setAttribute('orient', 'auto');
      var ap = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      ap.setAttribute('d', 'M0,0 L8,4 L0,8 Z'); ap.setAttribute('fill', 'rgba(124,58,237,0.3)');
      marker.appendChild(ap); defs.appendChild(marker); svg.appendChild(defs);

      for (var j = 0; j < pathOrder.length; j++) {
        var fromId = pathOrder[j];
        var toId = pathOrder[(j + 1) % pathOrder.length];
        var fromCell = findCellById(cells, fromId);
        var toCell = findCellById(cells, toId);
        if (!fromCell || !toCell) continue;
        var fx = fromCell.x + 36, fy = fromCell.y + 30;
        var tx = toCell.x + 36, ty = toCell.y;
        var line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        line.setAttribute('x1', fx); line.setAttribute('y1', fy);
        line.setAttribute('x2', tx); line.setAttribute('y2', ty);
        line.setAttribute('stroke', 'rgba(124,58,237,0.2)');
        line.setAttribute('stroke-width', '2'); line.setAttribute('stroke-dasharray', '6,3');
        line.setAttribute('marker-end', 'url(#' + marker.getAttribute('id') + ')');
        svg.appendChild(line);
      }
      board.appendChild(svg);
    }

    // 渲染格子
    for (var k = 0; k < cells.length; k++) {
      var cell = cells[k];
      var el = document.createElement('div');
      el.className = 'gh-cell gh-cell-' + (cell.type || 'empty');
      el.dataset.index = pathOrder.indexOf(cell.id);
      el.style.cssText =
        'position:absolute;left:' + cell.x + 'px;top:' + cell.y + 'px;' +
        'min-width:72px;padding:6px 8px;border-radius:10px;z-index:1;' +
        'display:flex;flex-direction:column;align-items:center;gap:2px;' +
        'font-size:11px;text-align:center;cursor:pointer;' +
        'background:' + getTypeColor(cell.type) + ';' +
        'border:1px solid rgba(255,255,255,0.12);';
      el.innerHTML =
        '<span style="font-size:20px;line-height:1">' + (cell.icon || '') + '</span>' +
        '<span style="font-size:11px;font-weight:600;line-height:1.1;color:var(--text,#F0EAF8)">' + (cell.name || '') + '</span>' +
        (cell.price ? '<span style="font-size:10px;color:var(--muted)">v' + cell.price + '</span>' : '');
      if (cb.onCellClick) {
        (function(idx, cd) {
          el.addEventListener('click', function() { cb.onCellClick(idx, cd); });
        })(pathOrder.indexOf(cell.id), cell);
      }
      board.appendChild(el);
    }
    container.innerHTML = '';
    container.appendChild(board);
    return board;
  }

  // ─── 网格模式（旧版兼容） ───
  function renderGridMode(container, config, cb) {
    var rows = config.rows || 7;
    var cols = config.cols || 7;
    var cells = config.cells || [];

    var board = document.createElement('div');
    board.className = 'gh-grid-board';
    board.style.cssText =
      'display:grid;grid-template-columns:repeat(' + cols + ',1fr);' +
      'grid-template-rows:repeat(' + rows + ',1fr);gap:2px;width:100%;' +
      'aspect-ratio:' + cols + '/' + rows + ';';

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        var isBorder = (r === 0 || r === rows - 1 || c === 0 || c === cols - 1);
        if (isBorder) {
          var index = borderCellIndex(r, c, rows, cols);
          var cellData = findCell(cells, index);
          var cell = createCellEl(cellData, index, cb.onCellClick);
          board.appendChild(cell);
        } else {
          var empty = document.createElement('div');
          empty.style.cssText = 'background:transparent;';
          board.appendChild(empty);
        }
      }
    }
    container.innerHTML = '';
    container.appendChild(board);
    return board;
  }

  function findCellById(cells, id) {
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].id === id) return cells[i];
    }
    return null;
  }

  function findCell(cells, index) {
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].index === index) return cells[i];
    }
    return { name: '', icon: '', type: 'empty' };
  }

  function borderCellIndex(r, c, rows, cols) {
    if (r === 0) return c;
    if (c === cols - 1) return (cols - 1) + r;
    if (r === rows - 1) return (cols - 1) + (rows - 1) + (cols - 1 - c);
    return (cols - 1) + (rows - 1) + (cols - 1) + (rows - 1 - r);
  }

  function getTypeColor(type) {
    var colors = {
      start:    'rgba(34,197,94,0.2)',
      property: 'rgba(124,58,237,0.15)',
      chance:   'rgba(245,200,66,0.15)',
      destiny:  'rgba(236,72,153,0.15)',
      jail:     'rgba(239,68,68,0.15)',
      shop:     'rgba(59,130,246,0.15)',
      event:    'rgba(34,211,238,0.15)',
      tax:      'rgba(251,146,60,0.15)',
    };
    return colors[type] || 'rgba(255,255,255,0.05)';
  }

  function createCellEl(cellData, index, onClick) {
    var cell = document.createElement('div');
    cell.className = 'gh-cell gh-cell-' + (cellData.type || 'empty');
    cell.dataset.index = index;
    cell.style.cssText =
      'display:flex;flex-direction:column;align-items:center;justify-content:center;' +
      'font-size:11px;text-align:center;padding:2px;border-radius:4px;cursor:pointer;' +
      'background:var(--card,rgba(255,255,255,0.05));border:1px solid var(--border,rgba(255,255,255,0.1));' +
      'transition:background 0.2s;min-height:0;overflow:hidden;';

    var typeColors = {
      start: 'rgba(34,197,94,0.15)', property: 'rgba(124,58,237,0.1)',
      chance: 'rgba(245,200,66,0.1)', destiny: 'rgba(236,72,153,0.1)',
      jail: 'rgba(239,68,68,0.1)', shop: 'rgba(59,130,246,0.1)',
      event: 'rgba(34,211,238,0.1)',
    };
    cell.style.background = typeColors[cellData.type] || 'var(--card)';

    cell.innerHTML =
      '<span style="font-size:16px;line-height:1">' + (cellData.icon || '') + '</span>' +
      '<span style="font-size:11px;margin-top:1px;line-height:1.1;color:var(--text,#F0EAF8)">' + (cellData.name || '') + '</span>';

    if (onClick) {
      cell.addEventListener('click', function() { onClick(index, cellData); });
    }
    return cell;
  }

  function getCellPosition(boardEl, index) {
    var cell = boardEl.querySelector('[data-index="' + index + '"]');
    if (!cell) return { x: 0, y: 0 };
    var boardRect = boardEl.getBoundingClientRect();
    var cellRect = cell.getBoundingClientRect();
    return {
      x: cellRect.left - boardRect.left + cellRect.width / 2,
      y: cellRect.top - boardRect.top + cellRect.height / 2,
      width: cellRect.width, height: cellRect.height,
    };
  }

  function updateCell(boardEl, index, updates) {
    var cell = boardEl.querySelector('[data-index="' + index + '"]');
    if (!cell) return;
    if (updates.highlight) {
      cell.style.boxShadow = '0 0 8px var(--gold)';
      cell.style.borderColor = 'var(--gold)';
    } else {
      cell.style.boxShadow = '';
      cell.style.borderColor = 'var(--border)';
    }
  }

  function clearHighlights(boardEl) {
    var cells = boardEl.querySelectorAll('.gh-cell');
    for (var i = 0; i < cells.length; i++) {
      cells[i].style.boxShadow = '';
      cells[i].style.borderColor = 'var(--border)';
    }
  }

  return { render: render, getCellPosition: getCellPosition, updateCell: updateCell, clearHighlights: clearHighlights };
})();
