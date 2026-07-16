/**
 * BoardBuilder v2 — Canvas 2D 地图编辑器
 *
 * 借鉴 MineMonopoly (THREE.js) 的架构模式:
 * - 层级渲染: 网格 → 路径线 → 格子 → 选中高亮 → 悬停预览
 * - 轨道控制: 平移(中键/空格+拖拽) + 缩放(滚轮)
 * - 射线检测: Canvas hit-test 点击检测
 * - 框选: 拖拽矩形多选
 * - 高亮Pass: 选中格子发光边框 + 路径高亮
 *
 * 依赖：无
 */

var BoardBuilder = (function() {
  'use strict';

  var CELL_TYPES = {
    start:    { label:'起点', icon:'🚩', color:'#22C55E', bg:'rgba(34,197,94,0.15)' },
    property: { label:'地产', icon:'🏠', color:'#7C3AED', bg:'rgba(124,58,237,0.12)' },
    chance:   { label:'机会', icon:'❓', color:'#F5C842', bg:'rgba(245,200,66,0.12)' },
    destiny:  { label:'命运', icon:'🔮', color:'#EC4899', bg:'rgba(236,72,153,0.12)' },
    jail:     { label:'监禁', icon:'🚔', color:'#EF4444', bg:'rgba(239,68,68,0.12)' },
    event:    { label:'事件', icon:'⚡', color:'#22D3EE', bg:'rgba(34,211,238,0.12)' },
    shop:     { label:'商店', icon:'🏪', color:'#3B82F6', bg:'rgba(59,130,246,0.12)' },
    tax:      { label:'税务', icon:'💰', color:'#FB923C', bg:'rgba(251,146,60,0.12)' },
  };

  var CELL_W = 80, CELL_H = 56, GRID_SIZE = 20;

  // ─── 公开 API ───
  function create(container, config, callbacks) {
    var cb = callbacks || {};
    config = JSON.parse(JSON.stringify(config || { cells:[], pathOrder:[] }));
    if (!config.pathOrder || !config.pathOrder.length) {
      config.pathOrder = (config.cells||[]).map(function(c){return c.id;});
    }

    var ed = {
      _container: container,
      _config: config,
      _callbacks: cb,
      _canvas: null, _ctx: null,
      _camera: { x:0, y:0, zoom:1 },
      _hoveredId: null,
      _selectedIds: [],
      _dragging: null,
      _panning: false,
      _boxSelect: null,
      _history: [], _historyIdx: -1,
      _dirty: true,
      _animFrame: null,
      _editingCell: null, // 内联编辑状态
    };

    buildUI(ed);
    pushHistory(ed);
    fitView(ed);
    startLoop(ed);
    return buildAPI(ed);
  }

  // ─── UI 构建 ───
  function buildUI(ed) {
    var c = ed._container;
    c.innerHTML = '';
    c.style.position = 'relative';
    c.style.overflow = 'hidden';
    c.style.background = '#0A0A1A';
    c.style.cursor = 'grab';
    c.style.userSelect = 'none';
    c.style.webkitUserSelect = 'none';
    c.style.minHeight = '400px';

    // Canvas
    ed._canvas = document.createElement('canvas');
    ed._canvas.style.cssText = 'position:absolute;top:0;left:0;width:100%;height:100%;';
    c.appendChild(ed._canvas);
    ed._ctx = ed._canvas.getContext('2d');

    // 工具栏
    var bar = document.createElement('div');
    bar.style.cssText = 'position:absolute;bottom:10px;left:50%;transform:translateX(-50%);display:flex;gap:6px;z-index:10;background:rgba(0,0,0,0.7);border:1px solid rgba(255,255,255,0.1);border-radius:10px;padding:4px 8px;backdrop-filter:blur(8px);';
    bar.innerHTML =
      '<button data-action="undo" title="撤销 Ctrl+Z" style="width:30px;height:30px;border:none;background:rgba(255,255,255,0.05);color:#ccc;border-radius:6px;cursor:pointer;font-size:14px">↩</button>' +
      '<button data-action="redo" title="重做 Ctrl+Y" style="width:30px;height:30px;border:none;background:rgba(255,255,255,0.05);color:#ccc;border-radius:6px;cursor:pointer;font-size:14px">↪</button>' +
      '<span style="width:1px;background:rgba(255,255,255,0.1);margin:2px 4px"></span>' +
      '<button data-action="zoomIn" title="放大" style="width:30px;height:30px;border:none;background:rgba(255,255,255,0.05);color:#ccc;border-radius:6px;cursor:pointer">+</button>' +
      '<button data-action="zoomOut" title="缩小" style="width:30px;height:30px;border:none;background:rgba(255,255,255,0.05);color:#ccc;border-radius:6px;cursor:pointer">−</button>' +
      '<button data-action="fitView" title="适应窗口" style="width:30px;height:30px;border:none;background:rgba(255,255,255,0.05);color:#ccc;border-radius:6px;cursor:pointer;font-size:12px">⊡</button>' +
      '<span style="width:1px;background:rgba(255,255,255,0.1);margin:2px 4px"></span>' +
      '<span style="font-size:10px;color:rgba(255,255,255,0.4);padding:0 4px;display:flex;align-items:center" id="bb-info">' + (ed._config.cells||[]).length + '格</span>';
    c.appendChild(bar);

    // 右键菜单容器
    var ctxMenu = document.createElement('div');
    ctxMenu.id = 'bb-context-menu';
    ctxMenu.style.cssText = 'position:fixed;z-index:1000;display:none;background:#1E1E2E;border:1px solid rgba(255,255,255,0.12);border-radius:8px;padding:4px;min-width:140px;box-shadow:0 8px 24px rgba(0,0,0,0.5);';
    c.appendChild(ctxMenu);

    bindEvents(ed);
    resizeCanvas(ed);
    window.addEventListener('resize', function(){ resizeCanvas(ed); });
  }

  function resizeCanvas(ed) {
    var rect = ed._container.getBoundingClientRect();
    var dpr = window.devicePixelRatio || 1;
    ed._canvas.width = rect.width * dpr;
    ed._canvas.height = rect.height * dpr;
    ed._canvas.style.width = rect.width + 'px';
    ed._canvas.style.height = rect.height + 'px';
    ed._ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ed._dirty = true;
  }

  // ─── 事件处理 ───
  function bindEvents(ed) {
    var c = ed._canvas;

    c.addEventListener('mousedown', function(e){ onMouseDown(ed, e); });
    c.addEventListener('mousemove', function(e){ onMouseMove(ed, e); });
    c.addEventListener('mouseup', function(e){ onMouseUp(ed, e); });
    c.addEventListener('wheel', function(e){ onWheel(ed, e); e.preventDefault(); }, {passive:false});
    c.addEventListener('dblclick', function(e){ onDblClick(ed, e); });
    c.addEventListener('contextmenu', function(e){ e.preventDefault(); onContextMenu(ed, e); });

    // 键盘
    ed._container.tabIndex = 0;
    ed._container.addEventListener('keydown', function(e){ onKeyDown(ed, e); });

    // 工具栏按钮
    ed._container.addEventListener('click', function(e){
      var btn = e.target.closest('[data-action]');
      if (!btn) return;
      var act = btn.dataset.action;
      if (act === 'undo') undo(ed);
      else if (act === 'redo') redo(ed);
      else if (act === 'zoomIn') { ed._camera.zoom = Math.min(2, ed._camera.zoom + 0.15); ed._dirty = true; }
      else if (act === 'zoomOut') { ed._camera.zoom = Math.max(0.2, ed._camera.zoom - 0.15); ed._dirty = true; }
      else if (act === 'fitView') fitView(ed);
    });

    // 关闭右键菜单
    document.addEventListener('click', function(){ hideContextMenu(ed); });
  }

  function screenToWorld(ed, e) {
    var rect = ed._canvas.getBoundingClientRect();
    return {
      x: (e.clientX - rect.left - ed._camera.x) / ed._camera.zoom,
      y: (e.clientY - rect.top - ed._camera.y) / ed._camera.zoom
    };
  }

  function hitTest(ed, worldX, worldY) {
    var cells = ed._config.cells || [];
    // 倒序遍历(上层优先)
    for (var i = cells.length - 1; i >= 0; i--) {
      var c = cells[i];
      var hw = CELL_W/2, hh = CELL_H/2;
      if (worldX >= c.x - hw && worldX <= c.x + hw && worldY >= c.y - hh && worldY <= c.y + hh) {
        return c;
      }
    }
    return null;
  }

  function onMouseDown(ed, e) {
    var pos = screenToWorld(ed, e);
    var cell = hitTest(ed, pos.x, pos.y);

    // 空格键+拖拽 = 平移
    if (ed._spaceDown || e.button === 1) {
      ed._panning = { sx: e.clientX, sy: e.clientY, cx: ed._camera.x, cy: ed._camera.y };
      return;
    }

    if (cell) {
      if (e.shiftKey) {
        // Shift+点击 = 多选切换
        toggleSelect(ed, cell.id);
      } else if (!ed._selectedIds.includes(cell.id)) {
        selectCell(ed, cell.id, false);
      }
      // 开始拖拽
      ed._dragging = { id: cell.id, sx: pos.x, sy: pos.y, ox: cell.x, oy: cell.y };
    } else {
      // 框选
      selectCell(ed, null, false);
      ed._boxSelect = { sx: pos.x, sy: pos.y, ex: pos.x, ey: pos.y };
    }
  }

  function onMouseMove(ed, e) {
    var pos = screenToWorld(ed, e);

    if (ed._panning) {
      ed._camera.x = ed._panning.cx + (e.clientX - ed._panning.sx);
      ed._camera.y = ed._panning.cy + (e.clientY - ed._panning.sy);
      ed._dirty = true; return;
    }

    if (ed._dragging) {
      var dx = pos.x - ed._dragging.sx;
      var dy = pos.y - ed._dragging.sy;
      var cell = getCell(ed, ed._dragging.id);
      if (cell && (Math.abs(dx) > 1 || Math.abs(dy) > 1)) {
        cell.x = snapToGrid(ed._dragging.ox + dx / ed._camera.zoom);
        cell.y = snapToGrid(ed._dragging.oy + dy / ed._camera.zoom);
        ed._dirty = true;
        if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
      }
      return;
    }

    if (ed._boxSelect) {
      ed._boxSelect.ex = pos.x; ed._boxSelect.ey = pos.y;
      // 实时更新框选
      var rect = normalizeRect(ed._boxSelect);
      var newIds = [];
      var cells = ed._config.cells || [];
      for (var i = 0; i < cells.length; i++) {
        var c = cells[i];
        if (c.x >= rect.x && c.x <= rect.x+rect.w && c.y >= rect.y && c.y <= rect.y+rect.h) {
          newIds.push(c.id);
        }
      }
      ed._selectedIds = newIds;
      ed._dirty = true; return;
    }

    // 悬停检测
    var hovered = hitTest(ed, pos.x, pos.y);
    if (hovered && hovered.id !== ed._hoveredId) {
      ed._hoveredId = hovered.id;
      ed._dirty = true;
      ed._canvas.style.cursor = ed._selectedIds.includes(hovered.id) ? 'move' : 'pointer';
    } else if (!hovered && ed._hoveredId) {
      ed._hoveredId = null;
      ed._dirty = true;
      ed._canvas.style.cursor = ed._spaceDown ? 'grab' : 'default';
    }
  }

  function onMouseUp(ed, e) {
    if (ed._panning) { ed._panning = null; return; }
    if (ed._dragging) {
      var cell = getCell(ed, ed._dragging.id);
      if (cell && (cell.x !== ed._dragging.ox || cell.y !== ed._dragging.oy)) {
        pushHistory(ed);
      }
      ed._dragging = null;
      ed._dirty = true;
      return;
    }
    if (ed._boxSelect) {
      ed._boxSelect = null;
      ed._dirty = true;
      if (ed._callbacks.onSelect) {
        ed._callbacks.onSelect(ed._selectedIds.length === 1 ? ed._selectedIds[0] : null,
          ed._selectedIds.length === 1 ? getCell(ed, ed._selectedIds[0]) : null);
      }
      return;
    }
  }

  function onWheel(ed, e) {
    var oldZoom = ed._camera.zoom;
    ed._camera.zoom *= (e.deltaY > 0 ? 0.9 : 1.1);
    ed._camera.zoom = Math.max(0.15, Math.min(3, ed._camera.zoom));
    // 缩放中心 = 鼠标位置
    var rect = ed._canvas.getBoundingClientRect();
    var mx = e.clientX - rect.left, my = e.clientY - rect.top;
    ed._camera.x = mx - (mx - ed._camera.x) * ed._camera.zoom / oldZoom;
    ed._camera.y = my - (my - ed._camera.y) * ed._camera.zoom / oldZoom;
    ed._dirty = true;
  }

  function onDblClick(ed, e) {
    var pos = screenToWorld(ed, e);
    var cell = hitTest(ed, pos.x, pos.y);
    if (cell) {
      // 双击编辑
      startInlineEdit(ed, cell);
    } else {
      // 双击空白处添加格子
      showAddMenu(ed, snapToGrid(pos.x), snapToGrid(pos.y), e.clientX, e.clientY);
    }
  }

  function onContextMenu(ed, e) {
    var pos = screenToWorld(ed, e);
    var cell = hitTest(ed, pos.x, pos.y);
    showContextMenu(ed, cell, e.clientX, e.clientY);
  }

  function onKeyDown(ed, e) {
    if (e.key === ' ' || e.code === 'Space') { ed._spaceDown = true; ed._canvas.style.cursor = 'grab'; e.preventDefault(); }
    if (e.ctrlKey && e.key === 'z') { e.preventDefault(); undo(ed); }
    if (e.ctrlKey && e.key === 'y') { e.preventDefault(); redo(ed); }
    if ((e.ctrlKey && e.key === 'c') || (e.metaKey && e.key === 'c')) { copyCells(ed); }
    if ((e.ctrlKey && e.key === 'v') || (e.metaKey && e.key === 'v')) { pasteCells(ed); }
    if (e.key === 'Delete' || e.key === 'Backspace') {
      if (ed._selectedIds.length > 0 && document.activeElement === ed._container) {
        e.preventDefault();
        for (var i = ed._selectedIds.length-1; i >= 0; i--) deleteCell(ed, ed._selectedIds[i]);
        pushHistory(ed);
      }
    }
    if (e.key === 'ArrowUp' || e.key === 'ArrowDown' || e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
      nudgeCells(ed, e);
    }
  }

  function nudgeCells(ed, e) {
    if (ed._selectedIds.length === 0) return;
    e.preventDefault();
    var dx = 0, dy = 0;
    if (e.key === 'ArrowUp') dy = -GRID_SIZE;
    if (e.key === 'ArrowDown') dy = GRID_SIZE;
    if (e.key === 'ArrowLeft') dx = -GRID_SIZE;
    if (e.key === 'ArrowRight') dx = GRID_SIZE;
    for (var i = 0; i < ed._selectedIds.length; i++) {
      var cell = getCell(ed, ed._selectedIds[i]);
      if (cell) { cell.x += dx; cell.y += dy; }
    }
    ed._dirty = true;
    pushHistory(ed);
    if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
  }

  // ─── 内联编辑 ───
  function startInlineEdit(ed, cell) {
    var pos = worldToScreen(ed, cell.x, cell.y);
    var input = document.createElement('input');
    input.value = cell.name || '';
    input.style.cssText = 'position:absolute;z-index:20;left:'+pos.x+'px;top:'+pos.y+'px;width:70px;' +
      'background:rgba(0,0,0,0.9);border:1px solid var(--accent,#7C3AED);border-radius:4px;color:white;' +
      'font-size:11px;padding:2px 4px;text-align:center;font-family:inherit;';
    ed._container.appendChild(input);
    input.focus(); input.select();
    input.addEventListener('blur', function(){
      if (input.value.trim()) { cell.name = input.value.trim(); }
      input.remove();
      ed._dirty = true;
      pushHistory(ed);
      if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
    });
    input.addEventListener('keydown', function(ev){
      if (ev.key === 'Enter') input.blur();
      if (ev.key === 'Escape') { input.value = cell.name; input.blur(); }
    });
  }

  // ─── 右键菜单 ───
  function showContextMenu(ed, cell, cx, cy) {
    var menu = document.getElementById('bb-context-menu');
    if (!menu) return;
    if (!cell) {
      menu.innerHTML = '<div data-act="addHere" style="padding:8px 12px;cursor:pointer;border-radius:4px;font-size:12px;color:#ccc">➕ 在此添加格子</div>';
    } else {
      menu.innerHTML =
        '<div data-act="edit" style="padding:8px 12px;cursor:pointer;border-radius:4px;font-size:12px;color:#ccc">✏️ 编辑名称</div>' +
        '<div data-act="duplicate" style="padding:8px 12px;cursor:pointer;border-radius:4px;font-size:12px;color:#ccc">📋 复制格子</div>' +
        '<div data-act="moveUp" style="padding:8px 12px;cursor:pointer;border-radius:4px;font-size:12px;color:#ccc">⬆ 路径前移</div>' +
        '<div data-act="moveDown" style="padding:8px 12px;cursor:pointer;border-radius:4px;font-size:12px;color:#ccc">⬇ 路径后移</div>' +
        '<div style="height:1px;background:rgba(255,255,255,0.1);margin:2px 0"></div>' +
        '<div data-act="delete" style="padding:8px 12px;cursor:pointer;border-radius:4px;font-size:12px;color:#EF4444">🗑️ 删除</div>';
    }
    menu.style.display = 'block';
    menu.style.left = cx + 'px';
    menu.style.top = cy + 'px';

    menu.querySelectorAll('[data-act]').forEach(function(item){
      item.addEventListener('mouseenter', function(){ item.style.background = 'rgba(255,255,255,0.05)'; });
      item.addEventListener('mouseleave', function(){ item.style.background = ''; });
      item.addEventListener('click', function(){
        var act = item.dataset.act;
        if (act === 'edit' && cell) startInlineEdit(ed, cell);
        else if (act === 'duplicate' && cell) { var c = JSON.parse(JSON.stringify(cell)); c.id='c'+Date.now().toString(36); c.x+=60; c.y+=30; ed._config.cells.push(c); ed._config.pathOrder.push(c.id); pushHistory(ed); ed._dirty=true; if(ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed)); }
        else if (act === 'moveUp' && cell) movePathItem(ed, cell.id, -1);
        else if (act === 'moveDown' && cell) movePathItem(ed, cell.id, 1);
        else if (act === 'delete' && cell) { deleteCell(ed, cell.id); pushHistory(ed); }
        else if (act === 'addHere') showAddMenu(ed, snapToGrid(cx-200), snapToGrid(cy-50), cx, cy);
        hideContextMenu(ed);
      });
    });
  }

  function hideContextMenu(ed) {
    var menu = document.getElementById('bb-context-menu');
    if (menu) menu.style.display = 'none';
  }

  // ─── 添加格子菜单 ───
  function showAddMenu(ed, wx, wy, sx, sy) {
    hideContextMenu(ed);
    var menu = document.createElement('div');
    menu.className = 'bb-add-menu';
    menu.style.cssText = 'position:fixed;z-index:1000;background:#1E1E2E;border:1px solid rgba(255,255,255,0.15);border-radius:12px;padding:8px;box-shadow:0 8px 32px rgba(0,0,0,0.6);display:grid;grid-template-columns:repeat(4,1fr);gap:4px;min-width:220px;';
    var types = Object.keys(CELL_TYPES);
    for (var i = 0; i < types.length; i++) {
      (function(type){
        var info = CELL_TYPES[type];
        var d = document.createElement('div');
        d.style.cssText = 'padding:8px 6px;border-radius:8px;cursor:pointer;text-align:center;transition:all 0.15s;font-size:11px;color:#ccc;';
        d.innerHTML = '<div style="font-size:22px">'+info.icon+'</div><div>'+info.label+'</div>';
        d.addEventListener('mouseenter', function(){ d.style.background='rgba(255,255,255,0.06)'; d.style.transform='scale(1.05)'; });
        d.addEventListener('mouseleave', function(){ d.style.background=''; d.style.transform='scale(1)'; });
        d.addEventListener('click', function(){
          menu.remove();
          addCell(ed, wx, wy, type);
        });
        menu.appendChild(d);
      })(types[i]);
    }
    document.body.appendChild(menu);
    menu.style.left = Math.min(sx, window.innerWidth-240) + 'px';
    menu.style.top = Math.min(sy, window.innerHeight-220) + 'px';
    setTimeout(function(){
      document.addEventListener('click', function close(){ menu.remove(); document.removeEventListener('click', close); });
    }, 10);
  }

  // ─── Canvas 渲染 ───
  function render(ed) {
    if (!ed._dirty) return;
    ed._dirty = false;
    var ctx = ed._ctx;
    var w = ed._canvas.width / (window.devicePixelRatio||1);
    var h = ed._canvas.height / (window.devicePixelRatio||1);
    var cam = ed._camera;

    ctx.clearRect(0, 0, w, h);

    ctx.save();
    ctx.translate(cam.x, cam.y);
    ctx.scale(cam.zoom, cam.zoom);

    // 第1层: 网格背景
    drawGrid(ed, ctx, w, h);

    // 第2层: 路径线
    drawPaths(ed, ctx);

    // 第3层: 框选矩形
    if (ed._boxSelect) drawBoxSelect(ed, ctx);

    // 第4层: 格子
    drawCells(ed, ctx);

    // 第5层: 选中高亮
    drawSelectionHighlight(ed, ctx);

    // 第6层: 悬停高亮
    if (ed._hoveredId && !ed._dragging) drawHoverHighlight(ed, ctx);

    ctx.restore();
  }

  function drawGrid(ed, ctx, w, h) {
    var cam = ed._camera;
    var startX = Math.floor(-cam.x / cam.zoom / GRID_SIZE) * GRID_SIZE;
    var startY = Math.floor(-cam.y / cam.zoom / GRID_SIZE) * GRID_SIZE;
    var endX = startX + w / cam.zoom + GRID_SIZE * 2;
    var endY = startY + h / cam.zoom + GRID_SIZE * 2;

    ctx.strokeStyle = 'rgba(255,255,255,0.03)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (var x = startX; x <= endX; x += GRID_SIZE) { ctx.moveTo(x, startY); ctx.lineTo(x, endY); }
    for (var y = startY; y <= endY; y += GRID_SIZE) { ctx.moveTo(startX, y); ctx.lineTo(endX, y); }
    ctx.stroke();
  }

  function drawPaths(ed, ctx) {
    var cells = ed._config.cells || [];
    var po = ed._config.pathOrder || [];
    if (po.length < 2) return;

    ctx.strokeStyle = 'rgba(139,92,246,0.35)';
    ctx.lineWidth = 2.5;
    ctx.setLineDash([8, 4]);
    ctx.lineCap = 'round';
    ctx.beginPath();

    for (var i = 0; i < po.length; i++) {
      var from = getCell(ed, po[i]);
      var to = getCell(ed, po[(i+1) % po.length]);
      if (!from || !to) continue;
      ctx.moveTo(from.x, from.y + CELL_H/2);
      ctx.lineTo(to.x, to.y - CELL_H/2);
    }
    ctx.stroke();
    ctx.setLineDash([]);

    // 箭头
    for (var j = 0; j < po.length; j++) {
      var f = getCell(ed, po[j]);
      var t = getCell(ed, po[(j+1) % po.length]);
      if (!f || !t) continue;
      var midX = (f.x + t.x) / 2, midY = (f.y + CELL_H/2 + t.y - CELL_H/2) / 2;
      var angle = Math.atan2(t.y - CELL_H/2 - f.y - CELL_H/2, t.x - f.x);
      drawArrow(ctx, midX, midY, angle, 'rgba(139,92,246,0.5)', 6);
    }
  }

  function drawArrow(ctx, x, y, angle, color, size) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(angle);
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(size, 0);
    ctx.lineTo(-size/2, -size/2);
    ctx.lineTo(-size/2, size/2);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  function drawBoxSelect(ed, ctx) {
    var r = normalizeRect(ed._boxSelect);
    ctx.fillStyle = 'rgba(139,92,246,0.08)';
    ctx.strokeStyle = 'rgba(139,92,246,0.5)';
    ctx.lineWidth = 1.5;
    ctx.setLineDash([4, 2]);
    ctx.fillRect(r.x, r.y, r.w, r.h);
    ctx.strokeRect(r.x, r.y, r.w, r.h);
    ctx.setLineDash([]);
  }

  function drawCells(ed, ctx) {
    var cells = ed._config.cells || [];
    var po = ed._config.pathOrder || [];

    for (var i = 0; i < cells.length; i++) {
      var c = cells[i];
      var info = CELL_TYPES[c.type] || CELL_TYPES.property;
      var x = c.x - CELL_W/2, y = c.y - CELL_H/2;
      var isSelected = ed._selectedIds.includes(c.id);

      // 阴影
      if (isSelected) {
        ctx.shadowColor = info.color;
        ctx.shadowBlur = 12;
      }

      // 背景
      ctx.fillStyle = info.bg;
      roundRect(ctx, x, y, CELL_W, CELL_H, 10);
      ctx.fill();

      ctx.shadowColor = 'transparent';
      ctx.shadowBlur = 0;

      // 边框
      ctx.strokeStyle = isSelected ? info.color : 'rgba(255,255,255,0.08)';
      ctx.lineWidth = isSelected ? 2 : 1;
      roundRect(ctx, x, y, CELL_W, CELL_H, 10);
      ctx.stroke();

      // 序号标签
      var pathIdx = po.indexOf(c.id);
      if (pathIdx >= 0) {
        ctx.fillStyle = info.color;
        ctx.beginPath();
        ctx.arc(x - 2, y - 2, 10, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#fff';
        ctx.font = 'bold 9px -apple-system,sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(pathIdx, x - 2, y - 2);
      }

      // 图标
      ctx.font = '22px -apple-system,sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'top';
      ctx.fillText(c.icon || info.icon, c.x, y + 4);

      // 名称
      ctx.fillStyle = '#E8E0F0';
      ctx.font = 'bold 10px -apple-system,"PingFang SC","Microsoft YaHei",sans-serif';
      ctx.fillText(truncate(c.name || info.defaultName, 6), c.x, y + 28);

      // 价格
      if (c.price && c.type === 'property') {
        ctx.fillStyle = 'rgba(255,255,255,0.4)';
        ctx.font = '9px -apple-system,sans-serif';
        ctx.fillText('¥'+c.price, c.x, y + 40);
      }
    }
  }

  function drawSelectionHighlight(ed, ctx) {
    if (ed._selectedIds.length <= 1) return;
    // 多选时额外绘制数量角标
    for (var i = 0; i < ed._selectedIds.length; i++) {
      var c = getCell(ed, ed._selectedIds[i]);
      if (!c) continue;
      var info = CELL_TYPES[c.type] || CELL_TYPES.property;
      ctx.strokeStyle = info.color;
      ctx.lineWidth = 2;
      ctx.setLineDash([2, 2]);
      roundRect(ctx, c.x - CELL_W/2 - 3, c.y - CELL_H/2 - 3, CELL_W + 6, CELL_H + 6, 13);
      ctx.stroke();
      ctx.setLineDash([]);
    }
  }

  function drawHoverHighlight(ed, ctx) {
    var c = getCell(ed, ed._hoveredId);
    if (!c || ed._selectedIds.includes(c.id)) return;
    ctx.strokeStyle = 'rgba(255,255,255,0.3)';
    ctx.lineWidth = 1.5;
    roundRect(ctx, c.x - CELL_W/2, c.y - CELL_H/2, CELL_W, CELL_H, 10);
    ctx.stroke();
  }

  // ─── 辅助 ───
  function roundRect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x+r, y); ctx.lineTo(x+w-r, y);
    ctx.quadraticCurveTo(x+w, y, x+w, y+r);
    ctx.lineTo(x+w, y+h-r);
    ctx.quadraticCurveTo(x+w, y+h, x+w-r, y+h);
    ctx.lineTo(x+r, y+h);
    ctx.quadraticCurveTo(x, y+h, x, y+h-r);
    ctx.lineTo(x, y+r);
    ctx.quadraticCurveTo(x, y, x+r, y);
    ctx.closePath();
  }

  function snapToGrid(v) { return Math.round(v / GRID_SIZE) * GRID_SIZE; }
  function normalizeRect(r) {
    var x = Math.min(r.sx, r.ex), y = Math.min(r.sy, r.ey);
    return { x:x, y:y, w:Math.abs(r.ex-r.sx), h:Math.abs(r.ey-r.sy) };
  }
  function truncate(s, n) { return s && s.length > n ? s.substring(0, n-1)+'…' : (s||''); }
  function worldToScreen(ed, wx, wy) {
    return { x: wx * ed._camera.zoom + ed._camera.x, y: wy * ed._camera.zoom + ed._camera.y };
  }

  // ─── 数据操作 ───
  function getCell(ed, id) {
    for (var i = 0; i < ed._config.cells.length; i++) {
      if (ed._config.cells[i].id === id) return ed._config.cells[i];
    }
    return null;
  }

  function getConfig(ed) {
    return { cells: JSON.parse(JSON.stringify(ed._config.cells||[])), pathOrder: (ed._config.pathOrder||[]).slice() };
  }

  function setConfig(ed, cfg) {
    ed._config = JSON.parse(JSON.stringify(cfg||{cells:[],pathOrder:[]}));
    if (!ed._config.pathOrder || !ed._config.pathOrder.length) {
      ed._config.pathOrder = (ed._config.cells||[]).map(function(c){return c.id;});
    }
    ed._selectedIds = [];
    ed._dirty = true;
  }

  function addCell(ed, x, y, type) {
    var info = CELL_TYPES[type] || CELL_TYPES.property;
    var id = 'c'+Date.now().toString(36);
    var cell = { id:id, x:x, y:y, type:type, name:info.defaultName, icon:info.icon, price:type==='property'?200:0, rent:[], effects:{} };
    ed._config.cells.push(cell);
    ed._config.pathOrder.push(id);
    selectCell(ed, id, false);
    pushHistory(ed);
    ed._dirty = true;
    if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
    if (ed._callbacks.onSelect) ed._callbacks.onSelect(id, cell);
    return id;
  }

  function deleteCell(ed, id) {
    ed._config.cells = ed._config.cells.filter(function(c){return c.id!==id;});
    ed._config.pathOrder = ed._config.pathOrder.filter(function(cid){return cid!==id;});
    ed._selectedIds = ed._selectedIds.filter(function(sid){return sid!==id;});
    ed._dirty = true;
    if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
  }

  function updateCell(ed, id, updates) {
    var cell = getCell(ed, id);
    if (!cell) return;
    for (var k in updates) { if (updates.hasOwnProperty(k)) cell[k] = updates[k]; }
    ed._dirty = true;
    pushHistory(ed);
    if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
  }

  function selectCell(ed, id, additive) {
    if (id === null || id === undefined) {
      ed._selectedIds = [];
    } else if (additive) {
      if (!ed._selectedIds.includes(id)) ed._selectedIds.push(id);
      else ed._selectedIds = ed._selectedIds.filter(function(x){return x!==id;});
    } else {
      ed._selectedIds = [id];
    }
    ed._dirty = true;
    var cell = getCell(ed, id);
    if (ed._callbacks.onSelect) ed._callbacks.onSelect(id, cell);
  }

  function toggleSelect(ed, id) {
    var idx = ed._selectedIds.indexOf(id);
    if (idx >= 0) ed._selectedIds.splice(idx, 1);
    else ed._selectedIds.push(id);
    ed._dirty = true;
  }

  // ─── 复制粘贴 ───
  var _clipboard = [];
  function copyCells(ed) {
    _clipboard = [];
    for (var i = 0; i < ed._selectedIds.length; i++) {
      var c = getCell(ed, ed._selectedIds[i]);
      if (c) _clipboard.push(JSON.parse(JSON.stringify(c)));
    }
  }

  function pasteCells(ed) {
    if (_clipboard.length === 0) return;
    ed._selectedIds = [];
    for (var i = 0; i < _clipboard.length; i++) {
      var c = JSON.parse(JSON.stringify(_clipboard[i]));
      c.id = 'c'+Date.now().toString(36)+'_'+i;
      c.x += 60; c.y += 40;
      ed._config.cells.push(c);
      ed._config.pathOrder.push(c.id);
      ed._selectedIds.push(c.id);
    }
    pushHistory(ed);
    ed._dirty = true;
    if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
  }

  // ─── 路径编辑 ───
  function movePathItem(ed, cellId, dir) {
    var po = ed._config.pathOrder;
    var idx = po.indexOf(cellId);
    if (idx < 0) return;
    var newIdx = idx + dir;
    if (newIdx < 0 || newIdx >= po.length) return;
    var tmp = po[idx]; po[idx] = po[newIdx]; po[newIdx] = tmp;
    ed._dirty = true;
    pushHistory(ed);
    if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
  }

  // ─── 撤销/重做 ───
  function pushHistory(ed) {
    ed._history = ed._history.slice(0, ed._historyIdx + 1);
    ed._history.push(getConfig(ed));
    if (ed._history.length > 60) ed._history.shift();
    else ed._historyIdx = ed._history.length - 1;
  }

  function undo(ed) {
    if (ed._historyIdx <= 0) return;
    ed._historyIdx--;
    setConfig(ed, ed._history[ed._historyIdx]);
    if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
  }

  function redo(ed) {
    if (ed._historyIdx >= ed._history.length - 1) return;
    ed._historyIdx++;
    setConfig(ed, ed._history[ed._historyIdx]);
    if (ed._callbacks.onChange) ed._callbacks.onChange(getConfig(ed));
  }

  // ─── 视图 ───
  function fitView(ed) {
    var cells = ed._config.cells || [];
    if (cells.length === 0) { ed._camera = {x:0, y:0, zoom:1}; ed._dirty=true; return; }
    var rect = ed._container.getBoundingClientRect();
    var minX=Infinity, minY=Infinity, maxX=-Infinity, maxY=-Infinity;
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].x < minX) minX = cells[i].x;
      if (cells[i].y < minY) minY = cells[i].y;
      if (cells[i].x > maxX) maxX = cells[i].x;
      if (cells[i].y > maxY) maxY = cells[i].y;
    }
    var cw = (maxX - minX) + CELL_W * 2, ch = (maxY - minY) + CELL_H * 2;
    var zoom = Math.min(rect.width / cw, rect.height / ch, 1.2);
    ed._camera.zoom = Math.max(0.3, zoom);
    ed._camera.x = rect.width/2 - (minX + (maxX-minX)/2) * ed._camera.zoom;
    ed._camera.y = rect.height/2 - (minY + (maxY-minY)/2) * ed._camera.zoom;
    ed._dirty = true;
  }

  // ─── 渲染循环 ───
  function startLoop(ed) {
    var lastTime = 0;
    function loop(time) {
      // 节流：最多 30fps
      if (time - lastTime > 33) {
        render(ed);
        lastTime = time;
      }
      ed._animFrame = requestAnimationFrame(loop);
    }
    ed._animFrame = requestAnimationFrame(loop);
  }

  function destroy(ed) {
    if (ed._animFrame) cancelAnimationFrame(ed._animFrame);
    ed._container.innerHTML = '';
    ed._config = { cells:[], pathOrder:[] };
  }

  // ─── API ───
  function buildAPI(ed) {
    return {
      addCell: function(x,y,t){return addCell(ed,x,y,t);},
      deleteCell: function(id){deleteCell(ed,id);},
      updateCell: function(id,u){updateCell(ed,id,u);},
      selectCell: function(id){selectCell(ed,id,false);},
      getConfig: function(){return getConfig(ed);},
      setConfig: function(c){setConfig(ed,c); fitView(ed);},
      getCell: function(id){return getCell(ed,id);},
      movePathUp: function(id){movePathItem(ed,id,-1);},
      movePathDown: function(id){movePathItem(ed,id,1);},
      undo: function(){undo(ed);},
      redo: function(){redo(ed);},
      fitView: function(){fitView(ed);},
      destroy: function(){destroy(ed);},
    };
  }

  return { create: create, CELL_TYPES: CELL_TYPES };
})();
