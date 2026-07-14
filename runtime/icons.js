/**
 * GameHub 图标集 — 内联 SVG 替代 emoji 作为结构性 UI 图标
 * 游戏内容（格子、卡牌、棋子）仍可使用 emoji
 */
const GameIcons = {
  // Block 类型图标 (18x18 简单 SVG)
  grid: '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><rect x="1" y="1" width="6" height="6" rx="1" stroke="currentColor" stroke-width="1.5"/><rect x="11" y="1" width="6" height="6" rx="1" stroke="currentColor" stroke-width="1.5"/><rect x="1" y="11" width="6" height="6" rx="1" stroke="currentColor" stroke-width="1.5"/><rect x="11" y="11" width="6" height="6" rx="1" stroke="currentColor" stroke-width="1.5"/></svg>',
  collection: '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><rect x="2" y="3" width="14" height="12" rx="1.5" stroke="currentColor" stroke-width="1.5"/><path d="M2 7h14" stroke="currentColor" stroke-width="1"/><circle cx="9" cy="11" r="2.5" stroke="currentColor" stroke-width="1.5"/></svg>',
  rule: '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><line x1="3" y1="1" x2="3" y2="17" stroke="currentColor" stroke-width="1.5"/><line x1="7" y1="6" x2="15" y2="6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><line x1="7" y1="10" x2="13" y2="10" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>',
  piece: '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><circle cx="9" cy="6" r="4" stroke="currentColor" stroke-width="1.5"/><path d="M5 13l4-4 4 4" stroke="currentColor" stroke-width="1.5"/><rect x="6" y="10" width="6" height="5" rx="1" stroke="currentColor" stroke-width="1.5"/></svg>',
  building: '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><rect x="3" y="1" width="12" height="16" rx="1" stroke="currentColor" stroke-width="1.5"/><line x1="9" y1="5" x2="9" y2="11" stroke="currentColor" stroke-width="1.5"/><line x1="5" y1="11" x2="13" y2="11" stroke="currentColor" stroke-width="1.5"/></svg>',
  store: '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M2 7l2-5h10l2 5" stroke="currentColor" stroke-width="1.5"/><rect x="3" y="7" width="12" height="9" rx="1" stroke="currentColor" stroke-width="1.5"/><line x1="7" y1="10" x2="7" y2="16" stroke="currentColor" stroke-width="1.5"/></svg>',
  effect: '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><circle cx="9" cy="9" r="2" fill="currentColor"/><line x1="9" y1="1" x2="9" y2="6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><line x1="9" y1="12" x2="9" y2="17" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><line x1="1" y1="9" x2="6" y2="9" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><line x1="12" y1="9" x2="17" y2="9" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>',
  player: '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><circle cx="9" cy="5" r="3" stroke="currentColor" stroke-width="1.5"/><path d="M3 16c0-3.3 2.7-6 6-6s6 2.7 6 6" stroke="currentColor" stroke-width="1.5"/></svg>',
  theme: '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><circle cx="9" cy="9" r="7" stroke="currentColor" stroke-width="1.5"/><circle cx="9" cy="6" r="2.5" fill="currentColor"/><circle cx="7" cy="14" r="1" fill="currentColor"/><circle cx="11" cy="12" r="0.8" fill="currentColor"/><circle cx="14" cy="7" r="1.2" fill="currentColor"/></svg>',

  // 导航图标
  home: '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M2 6l6-4 6 4v8H2V6z" stroke="currentColor" stroke-width="1.5"/><rect x="5" y="10" width="6" height="4"stroke="currentColor" stroke-width="1.5"/></svg>',
  edit: '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M11 2l3 3-9 9H2v-3l9-9z" stroke="currentColor" stroke-width="1.5"/></svg>',
  play: '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><polygon points="4,2 13,8 4,14" fill="currentColor"/></svg>',
  leaderboard: '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><rect x="1" y="8" width="4" height="6" rx="0.5" stroke="currentColor" stroke-width="1.5"/><rect x="6" y="5" width="4" height="9" rx="0.5" stroke="currentColor" stroke-width="1.5"/><rect x="11" y="2" width="4" height="12" rx="0.5" stroke="currentColor" stroke-width="1.5"/></svg>',
  user: '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="5" r="3" stroke="currentColor" stroke-width="1.5"/><path d="M3 14c0-2.8 2.2-5 5-5s5 2.2 5 5" stroke="currentColor" stroke-width="1.5"/></svg>',
  plus: '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><line x1="8" y1="2" x2="8" y2="14" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><line x1="2" y1="8" x2="14" y2="8" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>',
  close: '<svg width="12" height="12" viewBox="0 0 12 12" fill="none"><line x1="2" y1="2" x2="10" y2="10" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><line x1="10" y1="2" x2="2" y2="10" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>',
  drag: '<svg width="12" height="16" viewBox="0 0 12 16" fill="currentColor"><circle cx="4" cy="3" r="1.5"/><circle cx="8" cy="3" r="1.5"/><circle cx="4" cy="8" r="1.5"/><circle cx="8" cy="8" r="1.5"/><circle cx="4" cy="13" r="1.5"/><circle cx="8" cy="13" r="1.5"/></svg>',
  save: '<svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M10 1H2v12h10V4l-2-3z" stroke="currentColor" stroke-width="1.5"/><rect x="1" y="12" width="12" height="2" fill="currentColor"/><rect x="5" y="1" width="4" height="6" stroke="currentColor" stroke-width="1.5"/></svg>',
  publish: '<svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M5 1L1 7l4 6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><line x1="1" y1="7" x2="13" y2="7" stroke="currentColor" stroke-width="1.5"/></svg>',
  ai: '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="6" stroke="currentColor" stroke-width="1.5"/><circle cx="6" cy="7" r="1.5" fill="currentColor"/><circle cx="10" cy="7" r="1.5" fill="currentColor"/><path d="M5 10c.8 1 1.8 1.5 3 1.5s2.2-.5 3-1.5" stroke="currentColor" stroke-width="1" stroke-linecap="round"/></svg>',
};

// 方便的函数：获取图标 HTML
function gi(name) { return GameIcons[name] || ''; }
