/**
 * 棋盘渲染器 — 根据 Grid Block 配置渲染棋盘 DOM
 * 依赖：无
 */
const GridRenderer = (() => {
  /**
   * 渲染棋盘到指定容器
   * @param {HTMLElement} container
   * @param {object} config — { rows, cols, cells }
   * @param {object} callbacks — { onCellClick(index, cellData) }
   * @returns {HTMLElement} 棋盘元素
   */
  function render(container, config, callbacks) {
    callbacks = callbacks || {};
    var rows = config.rows || 7;
    var cols = config.cols || 7;
    var cells = config.cells || [];

    var board = document.createElement('div');
    board.className = 'gh-grid-board';
    board.style.cssText = [
      'display:grid;',
      'grid-template-columns:repeat(' + cols + ', 1fr);',
      'grid-template-rows:repeat(' + rows + ', 1fr);',
      'gap:2px;width:100%;aspect-ratio:' + cols + '/' + rows + ';',
      'position:relative;',
    ].join('');

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        var isBorder = (r === 0 || r === rows - 1 || c === 0 || c === cols - 1);
        if (isBorder) {
          var index = borderCellIndex(r, c, rows, cols);
          var cellData = findCell(cells, index);
          var cell = createCell(cellData, index, callbacks.onCellClick);
          board.appendChild(cell);
        } else {
          // 中间区域为空
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

  /**
   * 计算边框格子的线性索引（顺时针从左上角开始）
   */
  function borderCellIndex(r, c, rows, cols) {
    if (r === 0)           return c;                             // 上边
    if (c === cols - 1)    return (cols - 1) + r;                // 右边
    if (r === rows - 1)    return (cols - 1) + (rows - 1) + (cols - 1 - c); // 下边
    return (cols - 1) + (rows - 1) + (cols - 1) + (rows - 1 - r); // 左边
  }

  function findCell(cells, index) {
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].index === index) return cells[i];
    }
    return { name: '', icon: '', type: 'empty' };
  }

  function createCell(cellData, index, onClick) {
    var cell = document.createElement('div');
    cell.className = 'gh-cell gh-cell-' + (cellData.type || 'empty');
    cell.dataset.index = index;
    cell.style.cssText = [
      'display:flex;flex-direction:column;align-items:center;justify-content:center;',
      'font-size:10px;text-align:center;padding:2px;border-radius:4px;cursor:pointer;',
      'border:1px solid var(--border, rgba(255,255,255,0.1));',
      'transition:background 0.2s,box-shadow 0.2s;min-height:0;overflow:hidden;',
    ].join('');

    // 不同类型底色
    var typeColors = {
      start:    'rgba(34,197,94,0.2)',
      property: 'rgba(124,58,237,0.15)',
      chance:   'rgba(245,200,66,0.15)',
      destiny:  'rgba(236,72,153,0.15)',
      jail:     'rgba(239,68,68,0.15)',
      shop:     'rgba(59,130,246,0.15)',
      event:    'rgba(34,211,238,0.15)',
      tax:      'rgba(251,146,60,0.15)',
    };
    cell.style.background = typeColors[cellData.type] || 'var(--card, rgba(255,255,255,0.05))';

    cell.innerHTML = [
      '<span style="font-size:16px;line-height:1">' + (cellData.icon || '') + '</span>',
      '<span style="font-size:9px;margin-top:1px;line-height:1.1;color:var(--text,#F0EAF8)">' + (cellData.name || '') + '</span>',
    ].join('');

    if (onClick) {
      cell.addEventListener('click', function() { onClick(index, cellData); });
    }

    return cell;
  }

  /**
   * 获取某个格子在棋盘上的像素坐标
   */
  function getCellPosition(boardEl, index) {
    var cell = boardEl.querySelector('[data-index="' + index + '"]');
    if (!cell) return { x: 0, y: 0, width: 0, height: 0 };
    var boardRect = boardEl.getBoundingClientRect();
    var cellRect = cell.getBoundingClientRect();
    return {
      x: cellRect.left - boardRect.left + cellRect.width / 2,
      y: cellRect.top - boardRect.top + cellRect.height / 2,
      width:  cellRect.width,
      height: cellRect.height,
    };
  }

  function updateCell(boardEl, index, updates) {
    var cell = boardEl.querySelector('[data-index="' + index + '"]');
    if (!cell) return;
    if (updates.highlight) {
      cell.style.boxShadow = '0 0 10px var(--gold, #F5C842)';
      cell.style.borderColor = 'var(--gold, #F5C842)';
      cell.style.zIndex = '5';
    } else {
      cell.style.boxShadow = '';
      cell.style.borderColor = 'var(--border, rgba(255,255,255,0.1))';
      cell.style.zIndex = '';
    }
  }

  function clearHighlights(boardEl) {
    var cells = boardEl.querySelectorAll('.gh-cell');
    for (var i = 0; i < cells.length; i++) {
      cells[i].style.boxShadow = '';
      cells[i].style.borderColor = 'var(--border, rgba(255,255,255,0.1))';
      cells[i].style.zIndex = '';
    }
  }

  return { render, getCellPosition, updateCell, clearHighlights };
})();
