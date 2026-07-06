/**
 * themes.js — 全局主题切换引擎
 * GameHub 小游戏中台
 *
 * 用法：
 *   GameTheme.apply('dark-gold')   // 应用指定主题
 *   GameTheme.getCurrent()         // 获取当前主题 id
 *   GameTheme.toggle()             // 循环切换到下一个主题
 *   GameTheme.getAll()             // 获取全部主题定义
 *   GameTheme.openPicker()         // 手动打开主题选择器面板
 */

(function (global) {
  'use strict';

  // ─── 主题定义 ────────────────────────────────────────────────────────────────

  /** @type {Array<{id: string, name: string, vars: Object}>} */
  var THEMES = [
    {
      id: 'dark-purple',
      name: '暗紫',
      vars: {
        '--accent':  '#7C3AED',
        '--accent2': '#EC4899',
        '--gold':    '#F5C842',
        '--bg':      '#0D0720',
        '--card':    'rgba(124,58,237,0.07)',
        '--border':  'rgba(124,58,237,0.15)',
        '--deep':    '#1A0A2E',
        '--text':    '#F0EAF8',
        '--muted':   'rgba(240,234,248,0.5)',
      }
    },
    {
      id: 'dark-gold',
      name: '暗金',
      vars: {
        '--accent':  '#D97706',
        '--accent2': '#F59E0B',
        '--gold':    '#FDE68A',
        '--bg':      '#0C0A00',
        '--card':    'rgba(251,191,36,0.07)',
        '--border':  'rgba(251,191,36,0.15)',
        '--deep':    '#1A1200',
        '--text':    '#FEF9EC',
        '--muted':   'rgba(254,249,236,0.5)',
      }
    },
    {
      id: 'dark-green',
      name: '暗绿',
      vars: {
        '--accent':  '#059669',
        '--accent2': '#10B981',
        '--gold':    '#6EE7B7',
        '--bg':      '#020F0A',
        '--card':    'rgba(16,185,129,0.07)',
        '--border':  'rgba(16,185,129,0.15)',
        '--deep':    '#041A10',
        '--text':    '#ECFDF5',
        '--muted':   'rgba(236,253,245,0.5)',
      }
    },
    {
      id: 'dark-red',
      name: '暗红',
      vars: {
        '--accent':  '#DC2626',
        '--accent2': '#F97316',
        '--gold':    '#FCA5A5',
        '--bg':      '#0F0000',
        '--card':    'rgba(220,38,38,0.07)',
        '--border':  'rgba(220,38,38,0.15)',
        '--deep':    '#1F0000',
        '--text':    '#FFF1F1',
        '--muted':   'rgba(255,241,241,0.5)',
      }
    }
  ];

  // localStorage 存储 key
  var STORAGE_KEY = 'gh_theme';

  // 当前主题 id
  var _currentId = 'dark-purple';

  // 面板是否已注入到 DOM
  var _pickerInjected = false;

  // ─── 核心：应用主题 ──────────────────────────────────────────────────────────

  /**
   * 将指定主题的 CSS 变量写入 :root，并更新 meta theme-color
   * @param {string} themeId
   */
  function apply(themeId) {
    var theme = _findTheme(themeId);
    if (!theme) {
      console.warn('[GameTheme] 未知主题 id：' + themeId);
      return;
    }

    var root = document.documentElement;

    // 写入所有 CSS 变量
    Object.keys(theme.vars).forEach(function (key) {
      root.style.setProperty(key, theme.vars[key]);
    });

    // 更新移动端顶栏颜色
    _updateMetaThemeColor(theme.vars['--bg']);

    // 记忆到 localStorage
    try {
      localStorage.setItem(STORAGE_KEY, themeId);
    } catch (e) { /* 隐私模式下忽略 */ }

    _currentId = themeId;

    // 更新切换按钮的背景色（如果已注入）
    _syncButtonColor();

    // 更新面板中选中状态（如果面板已打开）
    _syncPickerSelection();

    // 触发自定义事件，方便其他模块监听
    _dispatchChangeEvent(themeId);
  }

  // ─── API ─────────────────────────────────────────────────────────────────────

  /** 获取当前主题 id */
  function getCurrent() {
    return _currentId;
  }

  /** 循环切换到下一个主题 */
  function toggle() {
    var idx = _findIndex(_currentId);
    var nextIdx = (idx + 1) % THEMES.length;
    apply(THEMES[nextIdx].id);
  }

  /** 获取全部主题定义（浅拷贝，防止外部污染） */
  function getAll() {
    return THEMES.map(function (t) {
      return { id: t.id, name: t.name, vars: Object.assign({}, t.vars) };
    });
  }

  /** 手动打开主题选择器面板 */
  function openPicker() {
    _ensurePickerInjected();
    _showPicker();
  }

  // ─── UI：主题按钮注入 ────────────────────────────────────────────────────────

  /**
   * 在页面 .nav-right 或 .nav 中注入主题切换按钮
   * 只注入一次，重复调用无副作用
   */
  function _injectNavButton() {
    // 防止重复注入
    if (document.getElementById('gh-theme-btn')) return;

    var container = document.querySelector('.nav-right') || document.querySelector('.nav');
    if (!container) return;

    // 创建按钮
    var btn = document.createElement('button');
    btn.id = 'gh-theme-btn';
    btn.setAttribute('aria-label', '切换主题');
    btn.setAttribute('title', '切换主题');
    btn.textContent = '🎨';

    // 按钮基础样式
    _setStyles(btn, {
      width:          '40px',
      height:         '40px',
      borderRadius:   '50%',
      border:         'none',
      cursor:         'pointer',
      fontSize:       '18px',
      display:        'inline-flex',
      alignItems:     'center',
      justifyContent: 'center',
      background:     _getThemeAccent(_currentId),
      boxShadow:      '0 2px 8px rgba(0,0,0,0.4)',
      transition:     'transform 0.2s, box-shadow 0.2s',
      flexShrink:     '0',
      marginLeft:     '8px',
    });

    // hover 效果
    btn.addEventListener('mouseenter', function () {
      btn.style.transform = 'scale(1.1)';
      btn.style.boxShadow = '0 4px 16px rgba(0,0,0,0.5)';
    });
    btn.addEventListener('mouseleave', function () {
      btn.style.transform = 'scale(1)';
      btn.style.boxShadow = '0 2px 8px rgba(0,0,0,0.4)';
    });

    // 点击打开面板
    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      _ensurePickerInjected();
      _togglePicker();
    });

    container.appendChild(btn);
  }

  // ─── UI：主题选择面板 ────────────────────────────────────────────────────────

  /** 确保选择器面板已注入到 body */
  function _ensurePickerInjected() {
    if (_pickerInjected) return;
    _injectPicker();
    _pickerInjected = true;
  }

  /** 创建并注入选择器面板（含遮罩） */
  function _injectPicker() {
    // 遮罩层
    var overlay = document.createElement('div');
    overlay.id = 'gh-theme-overlay';
    _setStyles(overlay, {
      position:   'fixed',
      inset:      '0',
      zIndex:     '9998',
      background: 'transparent',
      display:    'none',
    });
    overlay.addEventListener('click', _hidePicker);

    // 面板主体
    var panel = document.createElement('div');
    panel.id = 'gh-theme-panel';
    _setStyles(panel, {
      position:     'fixed',
      top:          '70px',
      right:        '16px',
      zIndex:       '9999',
      background:   'rgba(15,10,30,0.95)',
      backdropFilter: 'blur(16px)',
      WebkitBackdropFilter: 'blur(16px)',
      border:       '1px solid rgba(255,255,255,0.12)',
      borderRadius: '16px',
      padding:      '20px 24px',
      boxShadow:    '0 8px 40px rgba(0,0,0,0.6)',
      display:      'none',
      minWidth:     '220px',
    });

    // 标题行
    var title = document.createElement('p');
    title.textContent = '选择主题';
    _setStyles(title, {
      color:        'rgba(255,255,255,0.5)',
      fontSize:     '12px',
      letterSpacing:'1px',
      textTransform:'uppercase',
      marginBottom: '16px',
    });
    panel.appendChild(title);

    // 色块网格
    var grid = document.createElement('div');
    grid.id = 'gh-theme-grid';
    _setStyles(grid, {
      display:             'grid',
      gridTemplateColumns: 'repeat(2, 1fr)',
      gap:                 '12px',
    });

    THEMES.forEach(function (theme) {
      var item = _createThemeItem(theme);
      grid.appendChild(item);
    });

    panel.appendChild(grid);

    // 阻止面板内点击冒泡到遮罩
    panel.addEventListener('click', function (e) { e.stopPropagation(); });

    document.body.appendChild(overlay);
    document.body.appendChild(panel);
  }

  /**
   * 创建单个主题色块 item
   * @param {{id: string, name: string, vars: Object}} theme
   * @returns {HTMLElement}
   */
  function _createThemeItem(theme) {
    var wrap = document.createElement('div');
    wrap.setAttribute('data-theme-item', theme.id);
    _setStyles(wrap, {
      display:        'flex',
      flexDirection:  'column',
      alignItems:     'center',
      gap:            '6px',
      cursor:         'pointer',
    });

    // 色圆
    var circle = document.createElement('div');
    _setStyles(circle, {
      width:          '44px',
      height:         '44px',
      borderRadius:   '50%',
      background:     theme.vars['--accent'],
      position:       'relative',
      transition:     'transform 0.15s, box-shadow 0.15s',
      boxShadow:      '0 2px 8px rgba(0,0,0,0.4)',
      border:         '2px solid transparent',
    });

    // 选中时的金色对勾
    var check = document.createElement('span');
    check.setAttribute('data-check', theme.id);
    check.textContent = '✓';
    _setStyles(check, {
      position:   'absolute',
      inset:      '0',
      display:    'flex',
      alignItems: 'center',
      justifyContent: 'center',
      color:      '#F5C842',
      fontSize:   '18px',
      fontWeight: '700',
      opacity:    theme.id === _currentId ? '1' : '0',
      transition: 'opacity 0.2s',
    });
    circle.appendChild(check);

    // 主题名称
    var label = document.createElement('span');
    label.textContent = theme.name;
    _setStyles(label, {
      color:    'rgba(255,255,255,0.7)',
      fontSize: '12px',
    });

    wrap.appendChild(circle);
    wrap.appendChild(label);

    // hover 效果
    wrap.addEventListener('mouseenter', function () {
      circle.style.transform = 'scale(1.1)';
      circle.style.boxShadow = '0 4px 16px rgba(0,0,0,0.5)';
    });
    wrap.addEventListener('mouseleave', function () {
      circle.style.transform = 'scale(1)';
      circle.style.boxShadow = '0 2px 8px rgba(0,0,0,0.4)';
    });

    // 点击应用主题
    wrap.addEventListener('click', function () {
      apply(theme.id);
      // 延迟关闭面板，让用户看到效果
      setTimeout(_hidePicker, 300);
    });

    return wrap;
  }

  // ─── 面板显示控制 ────────────────────────────────────────────────────────────

  function _showPicker() {
    var overlay = document.getElementById('gh-theme-overlay');
    var panel   = document.getElementById('gh-theme-panel');
    if (overlay) overlay.style.display = 'block';
    if (panel) {
      panel.style.display = 'block';
      // 入场动画
      panel.style.opacity  = '0';
      panel.style.transform = 'translateY(-8px) scale(0.97)';
      panel.style.transition = 'opacity 0.2s, transform 0.2s';
      // 下一帧触发动画
      requestAnimationFrame(function () {
        requestAnimationFrame(function () {
          panel.style.opacity  = '1';
          panel.style.transform = 'translateY(0) scale(1)';
        });
      });
    }
    _syncPickerSelection();
  }

  function _hidePicker() {
    var overlay = document.getElementById('gh-theme-overlay');
    var panel   = document.getElementById('gh-theme-panel');
    if (panel) {
      panel.style.opacity  = '0';
      panel.style.transform = 'translateY(-8px) scale(0.97)';
      setTimeout(function () {
        if (panel) panel.style.display = 'none';
      }, 200);
    }
    if (overlay) overlay.style.display = 'none';
  }

  function _togglePicker() {
    var panel = document.getElementById('gh-theme-panel');
    if (panel && panel.style.display !== 'none') {
      _hidePicker();
    } else {
      _showPicker();
    }
  }

  // ─── 同步 UI 状态 ────────────────────────────────────────────────────────────

  /** 同步导航按钮背景色为当前主题 accent */
  function _syncButtonColor() {
    var btn = document.getElementById('gh-theme-btn');
    if (btn) {
      btn.style.background = _getThemeAccent(_currentId);
    }
  }

  /** 同步面板内选中状态（对勾显示/隐藏） */
  function _syncPickerSelection() {
    THEMES.forEach(function (theme) {
      var check = document.querySelector('[data-check="' + theme.id + '"]');
      if (check) {
        check.style.opacity = theme.id === _currentId ? '1' : '0';
      }
      var item = document.querySelector('[data-theme-item="' + theme.id + '"]');
      if (item) {
        var circle = item.querySelector('div');
        if (circle) {
          circle.style.border = theme.id === _currentId
            ? '2px solid #F5C842'
            : '2px solid transparent';
        }
      }
    });
  }

  // ─── 辅助函数 ────────────────────────────────────────────────────────────────

  /**
   * 批量设置元素 style
   * @param {HTMLElement} el
   * @param {Object} styles
   */
  function _setStyles(el, styles) {
    Object.keys(styles).forEach(function (key) {
      el.style[key] = styles[key];
    });
  }

  /**
   * 通过 id 找到主题对象
   * @param {string} id
   * @returns {Object|null}
   */
  function _findTheme(id) {
    for (var i = 0; i < THEMES.length; i++) {
      if (THEMES[i].id === id) return THEMES[i];
    }
    return null;
  }

  /**
   * 通过 id 找到主题在数组中的索引
   * @param {string} id
   * @returns {number}
   */
  function _findIndex(id) {
    for (var i = 0; i < THEMES.length; i++) {
      if (THEMES[i].id === id) return i;
    }
    return 0;
  }

  /**
   * 获取指定主题的 accent 颜色
   * @param {string} id
   * @returns {string}
   */
  function _getThemeAccent(id) {
    var theme = _findTheme(id);
    return theme ? theme.vars['--accent'] : '#7C3AED';
  }

  /**
   * 更新 meta[name="theme-color"]，控制移动端顶栏颜色
   * @param {string} color
   */
  function _updateMetaThemeColor(color) {
    var meta = document.querySelector('meta[name="theme-color"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.setAttribute('name', 'theme-color');
      document.head.appendChild(meta);
    }
    meta.setAttribute('content', color);
  }

  /**
   * 触发 gh:themechange 自定义事件
   * @param {string} themeId
   */
  function _dispatchChangeEvent(themeId) {
    try {
      var event = new CustomEvent('gh:themechange', {
        detail:  { themeId: themeId },
        bubbles: true,
      });
      document.dispatchEvent(event);
    } catch (e) { /* 旧浏览器忽略 */ }
  }

  // ─── 平滑过渡：给 body 和 :root 加 transition ────────────────────────────────

  function _enableTransition() {
    // 给 body 加过渡，让背景色变化平滑
    var style = document.createElement('style');
    style.textContent = [
      'body {',
      '  transition: background 0.4s, color 0.4s;',
      '}',
      ':root {',
      '  transition: --accent 0.4s;',
      '}',
      // 让所有依赖 CSS 变量的颜色属性平滑过渡
      '*, *::before, *::after {',
      '  transition-property: background-color, border-color, color, box-shadow;',
      '  transition-duration: 0.4s;',
      '  transition-timing-function: ease;',
      '}',
    ].join('\n');
    document.head.appendChild(style);
  }

  // ─── 初始化 ──────────────────────────────────────────────────────────────────

  /**
   * 读取 localStorage，应用上次主题；注入导航按钮
   * 在 DOMContentLoaded 之后执行
   */
  function _init() {
    // 1. 读取上次主题，默认 dark-purple
    var saved = null;
    try {
      saved = localStorage.getItem(STORAGE_KEY);
    } catch (e) { /* 隐私模式 */ }

    var initialId = _findTheme(saved) ? saved : 'dark-purple';

    // 2. 开启过渡动画（初始化后才开启，避免首屏闪烁）
    _enableTransition();

    // 3. 应用主题
    apply(initialId);

    // 4. 注入导航按钮（等待 DOM 就绪）
    _injectNavButton();
  }

  // ─── 挂载全局 API ────────────────────────────────────────────────────────────

  /** 对外暴露的 GameTheme 对象 */
  var GameTheme = {
    apply:      apply,
    getCurrent: getCurrent,
    toggle:     toggle,
    getAll:     getAll,
    openPicker: openPicker,
  };

  global.GameTheme = GameTheme;

  // ─── 自动初始化 ──────────────────────────────────────────────────────────────

  if (document.readyState === 'loading') {
    // DOM 尚未就绪，等待
    document.addEventListener('DOMContentLoaded', _init);
  } else {
    // DOM 已就绪（script 在底部或 defer 加载）
    _init();
  }

})(window);
