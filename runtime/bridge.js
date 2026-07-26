/**
 * GameHubBridge — Godot ↔ JavaScript 双向通信层
 * 依赖：无（独立模块，可选择性桥接到 GameEngine 事件总线）
 *
 * 通信协议：window.postMessage，通过 iframe 与 Godot 通信
 * 使用方式：页面中 <iframe id="godot-frame" src="wheelcut/index.html"></iframe>
 *          Bridge 会自动检测 iframe 的 contentWindow 建立通道
 *
 * API：
 *   GameHubBridge.send(type, payload)    — 发送消息到 Godot
 *   GameHubBridge.on(type, callback)     — 监听 Godot 消息，返回 unsubscribe 函数
 *   GameHubBridge.off(type, callback)    — 取消监听
 *   GameHubBridge.isReady()              — 检查 Godot 是否就绪
 *   GameHubBridge.connect(iframeEl)      — 手动连接到指定 iframe
 */
const GameHubBridge = (() => {
  var _ready = false;
  var _target = null;        // Godot iframe 的 contentWindow
  var _listeners = {};       // 事件监听器 { type: [callback, ...] }
  var _pendingQueue = [];    // 未就绪时的消息队列
  var _pendingTimers = {};   // 待确认消息的超时计时器
  var _msgId = 0;            // 消息自增 ID
  var TIMEOUT_MS = 5000;     // 超时时间

  // ─── 消息发送 ───
  /**
   * 发送消息到 Godot
   * @param {string} type — 消息类型，如 'spin:start'、'config:sync'
   * @param {object} payload — 消息数据
   */
  function send(type, payload) {
    var msg = {
      id: ++_msgId,
      type: type,
      payload: payload || {},
      timestamp: Date.now(),
    };

    if (_ready && _target) {
      _post(msg);
    } else {
      _pendingQueue.push(msg);
      console.log('[Bridge] Godot 未就绪，消息已加入队列 (' + _pendingQueue.length + '):', type);
    }
  }

  /** 实际发送 postMessage */
  function _post(msg) {
    if (!_target) return;
    try {
      _target.postMessage(msg, '*');
    } catch (e) {
      console.warn('[Bridge] 发送消息失败:', msg.type, e);
    }
  }

  /** 清空待发送队列 */
  function _flushQueue() {
    if (!_ready || !_target) return;
    var queue = _pendingQueue.slice();
    _pendingQueue = [];
    for (var i = 0; i < queue.length; i++) {
      _post(queue[i]);
    }
    if (queue.length > 0) {
      console.log('[Bridge] 已发送 ' + queue.length + ' 条缓存消息');
    }
  }

  // ─── 消息接收 ───
  /**
   * 监听 Godot 消息
   * @param {string} type — 消息类型
   * @param {function} callback — 回调函数 (payload, msg) => {}
   * @returns {function} unsubscribe — 调用以取消监听
   */
  function on(type, callback) {
    if (!_listeners[type]) _listeners[type] = [];
    _listeners[type].push(callback);
    return function unsubscribe() {
      off(type, callback);
    };
  }

  /** 取消监听 */
  function off(type, callback) {
    if (!_listeners[type]) return;
    _listeners[type] = _listeners[type].filter(function(fn) { return fn !== callback; });
  }

  /** 触发本地监听器 */
  function _emit(type, payload, msg) {
    var fns = _listeners[type] || [];
    for (var i = 0; i < fns.length; i++) {
      try { fns[i](payload, msg); } catch (e) {
        console.warn('[Bridge] 事件处理错误:', type, e);
      }
    }

    // ─── 自动桥接到 GameEngine 事件总线（如果存在） ───
    if (typeof GameEngine !== 'undefined' && GameEngine.emit) {
      GameEngine.emit('bridge:' + type, payload);
    }
  }

  // ─── 状态查询 ───
  function isReady() {
    return _ready;
  }

  // ─── 连接管理 ───
  /**
   * 手动连接到 Godot iframe
   * @param {HTMLIFrameElement} iframeEl
   */
  function connect(iframeEl) {
    if (!iframeEl || !iframeEl.contentWindow) {
      console.warn('[Bridge] 无效的 iframe 元素');
      return;
    }
    _target = iframeEl.contentWindow;
    console.log('[Bridge] 已连接到 iframe:', iframeEl.id || iframeEl.src);
  }

  /** 自动发现页面中的 Godot iframe */
  function _autoDiscover() {
    // 优先级：id=godot-frame > class 含 godot > 首个 iframe
    var frame = document.getElementById('godot-frame');
    if (!frame) {
      var iframes = document.querySelectorAll('iframe.godot, iframe[src*="wheelcut"]');
      frame = iframes[0];
    }
    if (!frame) {
      var allFrames = document.getElementsByTagName('iframe');
      frame = allFrames[0];
    }
    if (frame) {
      connect(frame);
    }
  }

  // ─── 消息处理（核心） ───
  function _handleMessage(event) {
    var msg = event.data;

    // 过滤非 Bridge 协议消息
    if (!msg || typeof msg !== 'object' || !msg.type) return;

    // ┌─ 系统消息 ───────────────────────────────
    if (msg.type === 'game:ready') {
      _ready = true;
      console.log('[Bridge] Godot 已就绪 v' + (msg.payload && msg.payload.version || '?'));
      _flushQueue();
      _emit('game:ready', msg.payload, msg);
      return;
    }

    // ┌─ 响应确认（ACK） ─────────────────────────
    if (msg.type === '_ack' && msg.payload && msg.payload.id) {
      var timer = _pendingTimers[msg.payload.id];
      if (timer) {
        clearTimeout(timer);
        delete _pendingTimers[msg.payload.id];
      }
      return;
    }

    // ┌─ 通用业务消息 ────────────────────────────
    _emit(msg.type, msg.payload, msg);
  }

  // ─── 初始化 ───
  window.addEventListener('message', _handleMessage, false);

  // DOM 加载完成后自动发现 iframe
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', _autoDiscover);
  } else {
    _autoDiscover();
  }

  // ─── 公开 API ───
  return {
    send: send,
    on: on,
    off: off,
    isReady: isReady,
    connect: connect,
  };
})();
