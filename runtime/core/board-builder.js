/**
 * BoardBuilder — 节点式地图编辑器
 *
 * 用户可以在画布上自由放置格子(cell)，自定义连接路径。
 * 不限于矩形边框，支持任意形状的地图布局。
 *
 * 依赖：无
 * 用法：
 *   var editor = BoardBuilder.create(container, config, callbacks);
 *   editor.addCell(x, y, type);
 *   editor.moveCell(id, x, y);
 *   editor.deleteCell(id);
 *   editor.getConfig(); // 导出配置
 */

var BoardBuilder = (function() {
  var CELL_TYPES = {
    start:    { label: '起点',   icon: '🚩', color: 'rgba(34,197,94,0.2)',  defaultName: '起点' },
    property: { label: '地产',   icon: '🏠', color: 'rgba(124,58,237,0.15)', defaultName: '新地产' },
    chance:   { label: '机会',   icon: '❓', color: 'rgba(245,200,66,0.15)', defaultName: '机会' },
    destiny:  { label: '命运',   icon: '🔮', color: 'rgba(236,72,153,0.15)', defaultName: '命运' },
    jail:     { label: '监禁',   icon: '🚔', color: 'rgba(239,68,68,0.15)',  defaultName: '监禁' },
    event:    { label: '事件',   icon: '⚡', color: 'rgba(34,211,238,0.15)', defaultName: '事件' },
    shop:     { label: '商店',   icon: '🏪', color: 'rgba(59,130,246,0.15)', defaultName: '商店' },
    tax:      { label: '税务',   icon: '💰', color: 'rgba(251,146,60,0.15)', defaultName: '税务' },
  };

  /**
   * 创建编辑器实例
   * @param {HTMLElement} container — 容器元素
   * @param {object} config — 初始配置 { cells: [...], pathOrder: [...] }
   * @param {object} callbacks — { onSelect(id, cell), onChange(), onDblClick(id, cell) }
   */
  function create(container, config, callbacks) {
    var cb = callbacks || {};
    config = config || { cells: [], pathOrder: [] };

    var editor = {
      _container: container,
      _config: JSON.parse(JSON.stringify(config)),
      _callbacks: cb,
      _selectedId: null,
      _svgLayer: null,
      _cellLayer: null,
      _cellEls: {},
      _dragging: null,
      _panning: false,
      _panStart: { x: 0, y: 0 },
      _zoom: 1,
      _history: [],
      _historyIdx: -1,
      _maxHistory: 50,
    };

    // 确保 pathOrder 与 cells 同步
    if (!editor._config.pathOrder || editor._config.pathOrder.length === 0) {
      editor._config.pathOrder = (editor._config.cells || []).map(function(c) { return c.id; });
    }

    // 初始化历史
    pushHistory(editor);

    buildDOM(editor);
    renderAll(editor);
    bindEvents(editor);
    bindKeyboard(editor);
    // 自动适配视图，让所有格子可见
    setTimeout(function() { fitView(editor); }, 100);

    return {
      addCell: function(x, y, type) { return addCell(editor, x, y, type); },
      moveCell: function(id, x, y) { moveCell(editor, id, x, y); },
      deleteCell: function(id) { deleteCell(editor, id); },
      updateCell: function(id, updates) { updateCell(editor, id, updates); },
      selectCell: function(id) { selectCell(editor, id); },
      getConfig: function() { return getConfig(editor); },
      setConfig: function(cfg) { setConfig(editor, cfg); },
      getCell: function(id) { return getCell(editor, id); },
      zoomIn: function() { zoomIn(editor); },
      zoomOut: function() { zoomOut(editor); },
      resetView: function() { resetView(editor); },
      destroy: function() { destroy(editor); },
      undo: function() { undo(editor); },
      redo: function() { redo(editor); },
      movePathUp: function(id) { movePathItem(editor, id, -1); },
      movePathDown: function(id) { movePathItem(editor, id, 1); },
    };
  }

  // ─── DOM 构建 ───
  function buildDOM(ed) {
    ed._container.innerHTML = '';
    ed._container.style.cssText = 'position:relative;overflow:auto;background:#0D0720;border-radius:12px;min-height:400px;height:100%;cursor:grab;user-select:none;';

    // 网格背景
    var bg = document.createElement('div');
    bg.className = 'bb-grid-bg';
    bg.style.cssText = 'position:absolute;top:0;left:0;right:0;bottom:0;pointer-events:none;' +
      'background-image:radial-gradient(circle,rgba(255,255,255,0.06) 1px,transparent 1px);' +
      'background-size:20px 20px;z-index:0;';
    ed._container.appendChild(bg);

    // SVG 路径层
    ed._svgLayer = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    ed._svgLayer.setAttribute('class', 'bb-svg-layer');
    ed._svgLayer.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;pointer-events:none;z-index:1;';
    ed._container.appendChild(ed._svgLayer);

    // 细胞层
    ed._cellLayer = document.createElement('div');
    ed._cellLayer.className = 'bb-cell-layer';
    ed._cellLayer.style.cssText = 'position:absolute;inset:0;z-index:2;';
    ed._container.appendChild(ed._cellLayer);

    // 控制栏
    var ctrl = document.createElement('div');
    ctrl.className = 'bb-controls';
    ctrl.style.cssText = 'position:absolute;bottom:8px;right:8px;z-index:10;display:flex;gap:4px;';
    ctrl.innerHTML =
      '<button class="bb-ctrl-btn" title="放大" data-action="zoomIn" style="width:32px;height:32px;border-radius:8px;border:1px solid rgba(255,255,255,0.1);background:rgba(0,0,0,0.6);color:var(--text,#F0EAF8);font-size:18px;cursor:pointer;display:flex;align-items:center;justify-content:center">+</button>' +
      '<button class="bb-ctrl-btn" title="缩小" data-action="zoomOut" style="width:32px;height:32px;border-radius:8px;border:1px solid rgba(255,255,255,0.1);background:rgba(0,0,0,0.6);color:var(--text,#F0EAF8);font-size:18px;cursor:pointer;display:flex;align-items:center;justify-content:center">−</button>' +
      '<button class="bb-ctrl-btn" title="重置视图" data-action="resetView" style="width:32px;height:32px;border-radius:8px;border:1px solid rgba(255,255,255,0.1);background:rgba(0,0,0,0.6);color:var(--text,#F0EAF8);font-size:14px;cursor:pointer;display:flex;align-items:center;justify-content:center">⌂</button>';
    ed._container.appendChild(ctrl);

    // 工具栏提示
    var tip = document.createElement('div');
    tip.style.cssText = 'position:absolute;top:8px;left:8px;z-index:10;font-size:11px;color:rgba(255,255,255,0.3);pointer-events:none;';
    tip.textContent = '双击空白处添加格子 | 拖拽格子移动 | 点击格子编辑';
    ed._container.appendChild(tip);
  }

  // ─── 事件绑定 ───
  function bindEvents(ed) {
    var container = ed._container;

    // 双击空白处添加格子
    container.addEventListener('dblclick', function(e) {
      var rect = container.getBoundingClientRect();
      var x = (e.clientX - rect.left) / ed._zoom;
      var y = (e.clientY - rect.top) / ed._zoom;
      // 判断是否点击了格子
      if (e.target.closest('.bb-cell')) return;
      // 弹出类型选择
      showAddCellMenu(ed, x, y, e.clientX, e.clientY);
    });

    // 鼠标按下
    container.addEventListener('mousedown', function(e) {
      if (e.button !== 0) return;
      var cellEl = e.target.closest('.bb-cell');
      if (cellEl) {
        // 拖拽格子
        var id = cellEl.dataset.cellId;
        selectCell(ed, id);
        startDragCell(ed, id, e);
      } else if (e.target.closest('.bb-ctrl-btn')) {
        // 控制按钮由 click 处理
        return;
      } else {
        // 平移画布
        startPan(ed, e);
      }
    });

    // 控制按钮点击
    container.addEventListener('click', function(e) {
      var btn = e.target.closest('.bb-ctrl-btn');
      if (!btn) return;
      var action = btn.dataset.action;
      if (action === 'zoomIn') zoomIn(ed);
      else if (action === 'zoomOut') zoomOut(ed);
      else if (action === 'resetView') resetView(ed);
    });

    // 全局鼠标移动和松开
    document.addEventListener('mousemove', function(e) {
      if (ed._dragging) {
        moveDragCell(ed, e);
      } else if (ed._panning) {
        movePan(ed, e);
      }
    });

    document.addEventListener('mouseup', function() {
      if (ed._dragging) endDragCell(ed);
      if (ed._panning) endPan(ed);
    });

    // 触控支持
    container.addEventListener('touchstart', function(e) {
      if (e.touches.length === 1) {
        var cellEl = e.target.closest('.bb-cell');
        if (cellEl) {
          var id = cellEl.dataset.cellId;
          selectCell(ed, id);
          startDragCell(ed, id, e.touches[0]);
        } else if (!e.target.closest('.bb-ctrl-btn')) {
          startPan(ed, e.touches[0]);
        }
      }
    }, { passive: false });

    container.addEventListener('touchmove', function(e) {
      if (ed._dragging) {
        e.preventDefault();
        moveDragCell(ed, e.touches[0]);
      } else if (ed._panning) {
        movePan(ed, e.touches[0]);
      }
    }, { passive: false });

    container.addEventListener('touchend', function() {
      if (ed._dragging) endDragCell(ed);
      if (ed._panning) endPan(ed);
    });
  }

  // ─── 拖拽格子 ───
  function startDragCell(ed, id, e) {
    var cell = getCell(ed, id);
    if (!cell) return;
    ed._dragging = {
      id: id,
      startX: e.clientX,
      startY: e.clientY,
      origX: cell.x,
      origY: cell.y,
    };
    ed._container.style.cursor = 'grabbing';
  }

  function moveDragCell(ed, e) {
    var d = ed._dragging;
    var dx = (e.clientX - d.startX) / ed._zoom;
    var dy = (e.clientY - d.startY) / ed._zoom;
    var newX = Math.round((d.origX + dx) / 10) * 10; // 吸附到 10px 网格
    var newY = Math.round((d.origY + dy) / 10) * 10;

    // 更新 cell 位置
    var cell = getCell(ed, d.id);
    if (cell) {
      cell.x = Math.max(0, newX);
      cell.y = Math.max(0, newY);
      updateCellEl(ed, d.id, cell);
      renderPaths(ed);
    }
  }

  function endDragCell(ed) {
    ed._dragging = null;
    ed._container.style.cursor = 'grab';
    pushHistory(ed);
    if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
  }

  // ─── 平移画布 ───
  function startPan(ed, e) {
    ed._panning = true;
    ed._panStart = { x: e.clientX, y: e.clientY };
    ed._container.style.cursor = 'grabbing';
  }

  function movePan(ed, e) {
    var dx = e.clientX - ed._panStart.x;
    var dy = e.clientY - ed._panStart.y;
    ed._panStart = { x: e.clientX, y: e.clientY };
    var currentTransform = ed._cellLayer.style.transform || '';
    var match = currentTransform.match(/translate\(([^)]+)\)/) || ['', '0px,0px'];
    var parts = match[1].split(',');
    var cx = parseFloat(parts[0]) || 0;
    var cy = parseFloat(parts[1]) || 0;
    var newTransform = 'translate(' + (cx + dx) + 'px, ' + (cy + dy) + 'px)';
    ed._cellLayer.style.transform = newTransform;
    ed._svgLayer.style.transform = newTransform;
    ed._container.querySelector('.bb-grid-bg').style.transform = newTransform;
  }

  function endPan(ed) {
    ed._panning = false;
    ed._container.style.cursor = 'grab';
  }

  // ─── 缩放 ───
  function zoomIn(ed) {
    ed._zoom = Math.min(2, ed._zoom + 0.1);
    applyZoom(ed);
  }

  function zoomOut(ed) {
    ed._zoom = Math.max(0.3, ed._zoom - 0.1);
    applyZoom(ed);
  }

  function resetView(ed) {
    ed._zoom = 1;
    ed._cellLayer.style.transform = 'translate(0px, 0px)';
    ed._svgLayer.style.transform = 'translate(0px, 0px)';
    var bg = ed._container.querySelector('.bb-grid-bg');
    if (bg) bg.style.transform = 'translate(0px, 0px)';
    applyZoom(ed);
  }

  function applyZoom(ed) {
    ed._cellLayer.style.transformOrigin = '0 0';
    ed._svgLayer.style.transformOrigin = '0 0';
    var bg = ed._container.querySelector('.bb-grid-bg');
    if (bg) bg.style.transformOrigin = '0 0';
    // 保持现有平移，叠加缩放
    var currentTransform = ed._cellLayer.style.transform || '';
    var match = currentTransform.match(/translate\(([^)]+)\)/) || ['', '0px,0px'];
    var parts = match[1].split(',');
    var tx = parseFloat(parts[0]) || 0;
    var ty = parseFloat(parts[1]) || 0;
    var newTransform = 'translate(' + tx + 'px, ' + ty + 'px) scale(' + ed._zoom + ')';
    ed._cellLayer.style.transform = newTransform;
    ed._svgLayer.style.transform = newTransform;
    if (bg) bg.style.transform = newTransform;
  }

  // ─── 添加格子 ───
  function showAddCellMenu(ed, x, y, clientX, clientY) {
    // 移除旧菜单
    var old = document.querySelector('.bb-add-menu');
    if (old) old.remove();

    var menu = document.createElement('div');
    menu.className = 'bb-add-menu';
    menu.style.cssText = 'position:fixed;z-index:1000;background:#1A0A2E;border:1px solid rgba(255,255,255,0.15);border-radius:12px;padding:8px;box-shadow:0 8px 32px rgba(0,0,0,0.5);display:grid;grid-template-columns:1fr 1fr;gap:4px;min-width:180px;';

    var types = Object.keys(CELL_TYPES);
    for (var i = 0; i < types.length; i++) {
      (function(type) {
        var info = CELL_TYPES[type];
        var item = document.createElement('div');
        item.style.cssText = 'padding:8px 12px;border-radius:8px;cursor:pointer;display:flex;align-items:center;gap:8px;font-size:13px;color:var(--text,#F0EAF8);transition:background 0.15s;';
        item.innerHTML = '<span style="font-size:16px">' + info.icon + '</span><span>' + info.label + '</span>';
        item.addEventListener('mouseenter', function() { item.style.background = 'rgba(255,255,255,0.06)'; });
        item.addEventListener('mouseleave', function() { item.style.background = ''; });
        item.addEventListener('click', function() {
          menu.remove();
          addCell(ed, x, y, type);
        });
        menu.appendChild(item);
      })(types[i]);
    }

    document.body.appendChild(menu);
    menu.style.left = Math.min(clientX, window.innerWidth - 200) + 'px';
    menu.style.top = Math.min(clientY, window.innerHeight - 260) + 'px';

    // 点击外部关闭
    setTimeout(function() {
      document.addEventListener('click', function closeMenu(e) {
        if (!menu.contains(e.target)) {
          menu.remove();
          document.removeEventListener('click', closeMenu);
        }
      });
    }, 10);
  }

  function addCell(ed, x, y, type) {
    var info = CELL_TYPES[type] || CELL_TYPES['property'];
    var id = 'c' + Date.now().toString(36);
    var cell = {
      id: id,
      x: x,
      y: y,
      type: type,
      name: info.defaultName,
      icon: info.icon,
      price: type === 'property' ? 200 : 0,
      rent: type === 'property' ? [50, 100, 200] : [],
      effects: {},
    };

    ed._config.cells.push(cell);
    ed._config.pathOrder.push(id);
    createCellEl(ed, cell);
    renderPaths(ed);
    pushHistory(ed);

    if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
    if (ed._callbacks.onSelect) ed._callbacks.onSelect(id, cell);

    return id;
  }

  // ─── 移动格子 ───
  function moveCell(ed, id, x, y) {
    var cell = getCell(ed, id);
    if (!cell) return;
    cell.x = Math.round(x / 10) * 10;
    cell.y = Math.round(y / 10) * 10;
    updateCellEl(ed, id, cell);
    renderPaths(ed);
    if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
  }

  // ─── 删除格子 ───
  function deleteCell(ed, id) {
    ed._config.cells = ed._config.cells.filter(function(c) { return c.id !== id; });
    ed._config.pathOrder = ed._config.pathOrder.filter(function(cid) { return cid !== id; });
    if (ed._selectedId === id) ed._selectedId = null;

    var el = ed._cellEls[id];
    if (el) { el.remove(); delete ed._cellEls[id]; }
    renderPaths(ed);
    pushHistory(ed);
    if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
  }

  // ─── 更新格子属性 ───
  function updateCell(ed, id, updates) {
    var cell = getCell(ed, id);
    if (!cell) return;
    for (var k in updates) {
      if (updates.hasOwnProperty(k)) cell[k] = updates[k];
    }
    updateCellEl(ed, id, cell);
    renderPaths(ed);
    pushHistory(ed);
    if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
  }

  // ─── 选中格子 ───
  function selectCell(ed, id) {
    ed._selectedId = id;
    // 高亮选中
    for (var cid in ed._cellEls) {
      var el = ed._cellEls[cid];
      if (el) {
        el.style.boxShadow = cid === id ? '0 0 0 2px var(--gold,#F5C842), 0 0 12px rgba(245,200,66,0.3)' : '';
        el.style.zIndex = cid === id ? '10' : '1';
      }
    }
    var cell = getCell(ed, id);
    if (ed._callbacks.onSelect) ed._callbacks.onSelect(id, cell);
  }

  // ─── 渲染 ───
  function renderAll(ed) {
    // 清空
    ed._cellLayer.innerHTML = '';
    ed._cellEls = {};

    // 渲染格子
    var cells = ed._config.cells || [];
    for (var i = 0; i < cells.length; i++) {
      createCellEl(ed, cells[i]);
    }
    renderPaths(ed);
  }

  function createCellEl(ed, cell) {
    var info = CELL_TYPES[cell.type] || CELL_TYPES['property'];
    var el = document.createElement('div');
    el.className = 'bb-cell';
    el.dataset.cellId = cell.id;
    el.style.cssText =
      'position:absolute;left:' + cell.x + 'px;top:' + cell.y + 'px;' +
      'min-width:72px;padding:6px 8px;border-radius:10px;' +
      'background:' + (info.color) + ';' +
      'border:1px solid rgba(255,255,255,0.12);' +
      'cursor:pointer;font-size:11px;text-align:center;' +
      'transition:box-shadow 0.15s;z-index:1;' +
      'display:flex;flex-direction:column;align-items:center;gap:2px;' +
      'backdrop-filter:blur(4px);';

    var pathIdx = (ed._config.pathOrder || []).indexOf(cell.id);
    var badgeHtml = pathIdx >= 0 ? '<span style="position:absolute;top:-6px;left:-6px;width:18px;height:18px;border-radius:50%;background:var(--accent,#7C3AED);color:white;font-size:10px;font-weight:700;display:flex;align-items:center;justify-content:center;z-index:5">' + pathIdx + '</span>' : '';

    el.innerHTML = badgeHtml +
      '<span style="font-size:20px;line-height:1">' + (cell.icon || info.icon) + '</span>' +
      '<span style="font-size:10px;color:var(--text,#F0EAF8);font-weight:600;line-height:1.1;max-width:80px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + (cell.name || info.defaultName) + '</span>' +
      (cell.price ? '<span style="font-size:9px;color:var(--muted,rgba(255,255,255,0.4))">¥' + cell.price + '</span>' : '');

    el.addEventListener('click', function(e) {
      e.stopPropagation();
      selectCell(ed, cell.id);
    });

    ed._cellLayer.appendChild(el);
    ed._cellEls[cell.id] = el;
  }

  function updateCellEl(ed, id, cell) {
    var el = ed._cellEls[id];
    if (!el) return;
    el.style.left = cell.x + 'px';
    el.style.top = cell.y + 'px';

    var info = CELL_TYPES[cell.type] || CELL_TYPES['property'];
    el.style.background = info.color;
    var pathIdx = (ed._config.pathOrder || []).indexOf(id);
    var badgeHtml = pathIdx >= 0 ? '<span style="position:absolute;top:-6px;left:-6px;width:18px;height:18px;border-radius:50%;background:var(--accent,#7C3AED);color:white;font-size:10px;font-weight:700;display:flex;align-items:center;justify-content:center;z-index:5">' + pathIdx + '</span>' : '';
    el.innerHTML = badgeHtml +
      '<span style="font-size:20px;line-height:1">' + (cell.icon || info.icon) + '</span>' +
      '<span style="font-size:10px;color:var(--text,#F0EAF8);font-weight:600;line-height:1.1;max-width:80px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + (cell.name || info.defaultName) + '</span>' +
      (cell.price ? '<span style="font-size:9px;color:var(--muted,rgba(255,255,255,0.4))">¥' + cell.price + '</span>' : '');
  }

  // ─── SVG 路径渲染 ───
  function renderPaths(ed) {
    // 清空 SVG
    while (ed._svgLayer.firstChild) {
      ed._svgLayer.removeChild(ed._svgLayer.firstChild);
    }

    var cells = ed._config.cells || [];
    var pathOrder = ed._config.pathOrder || [];
    if (cells.length < 2) return;

    // 创建 defs 用于箭头
    var defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs');
    var marker = document.createElementNS('http://www.w3.org/2000/svg', 'marker');
    marker.setAttribute('id', 'bb-arrow');
    marker.setAttribute('markerWidth', '8');
    marker.setAttribute('markerHeight', '8');
    marker.setAttribute('refX', '4');
    marker.setAttribute('refY', '4');
    marker.setAttribute('orient', 'auto');
    var arrowPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    arrowPath.setAttribute('d', 'M0,0 L8,4 L0,8 Z');
    arrowPath.setAttribute('fill', 'rgba(124,58,237,0.4)');
    marker.appendChild(arrowPath);
    defs.appendChild(marker);
    ed._svgLayer.appendChild(defs);

    // 画连接线（按 pathOrder 顺序）
    for (var i = 0; i < pathOrder.length; i++) {
      var fromId = pathOrder[i];
      var toId = pathOrder[(i + 1) % pathOrder.length]; // 循环回到起点
      var fromCell = getCell(ed, fromId);
      var toCell = getCell(ed, toId);
      if (!fromCell || !toCell) continue;

      // 计算连接点（格子底部中心 → 下一格子顶部中心）
      var fx = fromCell.x + 36; // 格子中心
      var fy = fromCell.y + 30; // 格子底部
      var tx = toCell.x + 36;
      var ty = toCell.y;         // 格子顶部

      var line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
      line.setAttribute('x1', fx);
      line.setAttribute('y1', fy);
      line.setAttribute('x2', tx);
      line.setAttribute('y2', ty);
      line.setAttribute('stroke', 'rgba(124,58,237,0.25)');
      line.setAttribute('stroke-width', '2');
      line.setAttribute('stroke-dasharray', '6,3');
      line.setAttribute('marker-end', 'url(#bb-arrow)');
      ed._svgLayer.appendChild(line);
    }

    // 自动扩展 SVG viewBox
    var maxX = 0, maxY = 0;
    for (var j = 0; j < cells.length; j++) {
      if (cells[j].x + 100 > maxX) maxX = cells[j].x + 100;
      if (cells[j].y + 60 > maxY) maxY = cells[j].y + 60;
    }
    ed._svgLayer.setAttribute('viewBox', '0 0 ' + Math.max(maxX, 600) + ' ' + Math.max(maxY, 400));
    ed._svgLayer.style.width = Math.max(maxX, 600) + 'px';
    ed._svgLayer.style.height = Math.max(maxY, 400) + 'px';
  }

  // ─── 数据操作 ───
  function getCell(ed, id) {
    var cells = ed._config.cells || [];
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].id === id) return cells[i];
    }
    return null;
  }

  function getConfig(ed) {
    return {
      cells: JSON.parse(JSON.stringify(ed._config.cells || [])),
      pathOrder: (ed._config.pathOrder || []).slice(),
    };
  }

  function setConfig(ed, cfg) {
    ed._config = JSON.parse(JSON.stringify(cfg || { cells: [], pathOrder: [] }));
    if (!ed._config.pathOrder || ed._config.pathOrder.length === 0) {
      ed._config.pathOrder = (ed._config.cells || []).map(function(c) { return c.id; });
    }
    ed._selectedId = null;
    renderAll(ed);
  }

  function destroy(ed) {
    ed._container.innerHTML = '';
    ed._cellEls = {};
    ed._config = { cells: [], pathOrder: [] };
  }

  // ─── 自动适配视图 ───
  function fitView(ed) {
    var cells = ed._config.cells || [];
    if (cells.length === 0) return;
    var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].x < minX) minX = cells[i].x;
      if (cells[i].y < minY) minY = cells[i].y;
      if (cells[i].x + 100 > maxX) maxX = cells[i].x + 100;
      if (cells[i].y + 70 > maxY) maxY = cells[i].y + 70;
    }
    var containerWidth = ed._container.clientWidth;
    var containerHeight = ed._container.clientHeight;
    var contentWidth = maxX - minX + 40;
    var contentHeight = maxY - minY + 40;
    var zoomX = containerWidth / contentWidth;
    var zoomY = containerHeight / contentHeight;
    ed._zoom = Math.min(zoomX, zoomY, 1); // 不超过100%
    ed._zoom = Math.max(0.3, Math.min(ed._zoom, 1.5));
    // 居中平移
    var offsetX = (containerWidth - contentWidth * ed._zoom) / 2 - minX * ed._zoom + 20;
    var offsetY = (containerHeight - contentHeight * ed._zoom) / 2 - minY * ed._zoom + 20;
    ed._cellLayer.style.transform = 'translate(' + offsetX + 'px, ' + offsetY + 'px) scale(' + ed._zoom + ')';
    ed._svgLayer.style.transform = 'translate(' + offsetX + 'px, ' + offsetY + 'px) scale(' + ed._zoom + ')';
    var bg = ed._container.querySelector('.bb-grid-bg');
    if (bg) bg.style.transform = 'translate(' + offsetX + 'px, ' + offsetY + 'px) scale(' + ed._zoom + ')';
  }

  // ─── 撤销/重做 ───
  function pushHistory(ed) {
    // 清除当前位置之后的历史
    ed._history = ed._history.slice(0, ed._historyIdx + 1);
    var snap = getConfig(ed);
    ed._history.push(snap);
    if (ed._history.length > ed._maxHistory) ed._history.shift();
    ed._historyIdx = ed._history.length - 1;
  }

  function undo(ed) {
    if (ed._historyIdx <= 0) return;
    ed._historyIdx--;
    var snap = JSON.parse(JSON.stringify(ed._history[ed._historyIdx]));
    ed._config = snap;
    ed._selectedId = null;
    renderAll(ed);
    if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
  }

  function redo(ed) {
    if (ed._historyIdx >= ed._history.length - 1) return;
    ed._historyIdx++;
    var snap = JSON.parse(JSON.stringify(ed._history[ed._historyIdx]));
    ed._config = snap;
    ed._selectedId = null;
    renderAll(ed);
    if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
  }

  // ─── 路径顺序编辑 ───
  function movePathItem(ed, cellId, direction) {
    var po = ed._config.pathOrder || [];
    var idx = po.indexOf(cellId);
    if (idx === -1) return;
    var newIdx = idx + direction;
    if (newIdx < 0 || newIdx >= po.length) return;
    // 交换
    var tmp = po[idx];
    po[idx] = po[newIdx];
    po[newIdx] = tmp;
    ed._config.pathOrder = po;
    pushHistory(ed);
    renderAll(ed);
    if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
  }

  // ─── 键盘快捷键 ───
  function bindKeyboard(ed) {
    ed._container.tabIndex = 0; // 使容器可聚焦
    ed._container.addEventListener('keydown', function(e) {
      // Ctrl+Z
      if (e.ctrlKey && e.key === 'z' && !e.shiftKey) {
        e.preventDefault();
        undo(ed);
        return;
      }
      // Ctrl+Y or Ctrl+Shift+Z
      if ((e.ctrlKey && e.key === 'y') || (e.ctrlKey && e.shiftKey && e.key === 'z')) {
        e.preventDefault();
        redo(ed);
        return;
      }
      // Delete 键删除选中格子
      if (e.key === 'Delete' || e.key === 'Backspace') {
        if (ed._selectedId && document.activeElement === ed._container) {
          e.preventDefault();
          deleteCell(ed, ed._selectedId);
        }
      }
    });
  }

  // ─── 公开静态方法 ───
  return {
    create: create,
    CELL_TYPES: CELL_TYPES,
  };
})();
