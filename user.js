/**
 * GameHub 全局用户模块
 * 功能：本地用户身份管理（localStorage），导航栏注入，经验/等级系统
 * 用法：引入后自动初始化，通过 GameUser.xxx() 调用 API
 * localStorage key: 'gh_user'
 */

const GameUser = (() => {

  // ─── 常量配置 ───────────────────────────────────────────────────────────────

  const STORAGE_KEY = 'gh_user';

  // 等级配置：[等级, 称号, 所需经验值]
  const LEVELS = [
    { lv: 1,  title: '新手玩家',  exp: 0    },
    { lv: 2,  title: '初级玩家',  exp: 100  },
    { lv: 3,  title: '进阶玩家',  exp: 300  },
    { lv: 4,  title: '熟练玩家',  exp: 600  },
    { lv: 5,  title: '资深玩家',  exp: 1000 },
    { lv: 6,  title: '游戏达人',  exp: 1500 },
    { lv: 7,  title: '游戏专家',  exp: 2100 },
    { lv: 8,  title: '游戏大师',  exp: 3000 },
    { lv: 9,  title: '游戏传说',  exp: 4000 },
    { lv: 10, title: '游戏之神',  exp: 5000 },
  ];

  // 可选头像 emoji 列表（30个）
  const AVATAR_LIST = [
    '🎮','🕹️','🎯','🎲','🏆','⚡','🌟','🔥','💎','🦁',
    '🐉','🦊','🐺','🦄','🐧','🦋','🌈','🍀','🎪','🎭',
    '🚀','🛸','⚔️','🛡️','🧙','🧜','🎩','🎸','🎺','🥁'
  ];

  // ─── 工具函数 ────────────────────────────────────────────────────────────────

  /** 生成随机昵称，如"玩家3721" */
  function randomNickname() {
    return '玩家' + Math.floor(1000 + Math.random() * 9000);
  }

  /** 生成随机头像 */
  function randomAvatar() {
    return AVATAR_LIST[Math.floor(Math.random() * AVATAR_LIST.length)];
  }

  /** 格式化日期为 YYYY-MM-DD */
  function formatDate(d) {
    const date = d ? new Date(d) : new Date();
    return date.toISOString().slice(0, 10);
  }

  /** 格式化时间为易读字符串 */
  function formatTime(isoStr) {
    if (!isoStr) return '';
    const d = new Date(isoStr);
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const dd = String(d.getDate()).padStart(2, '0');
    const hh = String(d.getHours()).padStart(2, '0');
    const min = String(d.getMinutes()).padStart(2, '0');
    return `${mm}-${dd} ${hh}:${min}`;
  }

  /** 根据经验值计算当前等级信息 */
  function calcLevel(exp) {
    let current = LEVELS[0];
    let next = LEVELS[1];
    for (let i = LEVELS.length - 1; i >= 0; i--) {
      if (exp >= LEVELS[i].exp) {
        current = LEVELS[i];
        next = LEVELS[i + 1] || null;
        break;
      }
    }
    return { current, next };
  }

  // ─── 数据读写 ────────────────────────────────────────────────────────────────

  /** 读取用户数据，首次访问自动创建默认用户 */
  function load() {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      try { return JSON.parse(raw); } catch (e) {}
    }
    // 首次访问，创建默认用户
    const defaultUser = {
      nickname: randomNickname(),
      avatar: randomAvatar(),
      level: 1,
      exp: 0,
      coins: 100,
      coinLog: [],
      totalGames: 0,
      totalPlays: 0,
      joinDate: formatDate(),
      lastLogin: new Date().toISOString(),
      gameHistory: [],
      settings: { sound: true, theme: 'dark-purple' }
    };
    save(defaultUser);
    return defaultUser;
  }

  /** 保存用户数据到 localStorage */
  function save(user) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(user));
  }

  // ─── Toast 升级提示 ──────────────────────────────────────────────────────────

  /** 注入 Toast 样式（只注入一次） */
  function ensureToastStyle() {
    if (document.getElementById('gu-toast-style')) return;
    const style = document.createElement('style');
    style.id = 'gu-toast-style';
    style.textContent = `
      #gu-toast {
        position: fixed;
        bottom: 32px;
        right: 32px;
        z-index: 99999;
        background: linear-gradient(135deg, #F5C842 0%, #F97316 50%, #EF4444 100%);
        color: #1A0A2E;
        padding: 14px 22px;
        border-radius: 16px;
        font-family: -apple-system,'PingFang SC','Microsoft YaHei',sans-serif;
        font-size: 15px;
        font-weight: 700;
        box-shadow: 0 8px 32px rgba(245,200,66,0.45), 0 2px 8px rgba(0,0,0,0.3);
        display: flex;
        align-items: center;
        gap: 10px;
        transform: translateY(20px);
        opacity: 0;
        transition: all 0.35s cubic-bezier(0.34,1.56,0.64,1);
        pointer-events: none;
        max-width: 280px;
      }
      #gu-toast.show {
        transform: translateY(0);
        opacity: 1;
      }
      #gu-toast .gu-toast-icon {
        font-size: 22px;
        flex-shrink: 0;
      }
      #gu-toast .gu-toast-text {
        line-height: 1.4;
      }
      #gu-toast .gu-toast-sub {
        font-size: 12px;
        font-weight: 500;
        opacity: 0.75;
        margin-top: 2px;
      }
    `;
    document.head.appendChild(style);
  }

  /** 显示升级 Toast */
  function showLevelUpToast(newLevel) {
    ensureToastStyle();
    // 移除旧 toast
    const old = document.getElementById('gu-toast');
    if (old) old.remove();

    const levelInfo = LEVELS.find(l => l.lv === newLevel);
    const toast = document.createElement('div');
    toast.id = 'gu-toast';
    toast.innerHTML = `
      <div class="gu-toast-icon">⬆️</div>
      <div class="gu-toast-text">
        恭喜升至 Lv${newLevel}！
        <div class="gu-toast-sub">${levelInfo ? levelInfo.title : ''}</div>
      </div>
    `;
    document.body.appendChild(toast);

    // 触发动画
    requestAnimationFrame(() => {
      requestAnimationFrame(() => toast.classList.add('show'));
    });

    // 3秒后消失
    setTimeout(() => {
      toast.classList.remove('show');
      setTimeout(() => toast.remove(), 400);
    }, 3000);
  }

  // ─── 导航栏注入 ──────────────────────────────────────────────────────────────

  /** 注入导航栏用户组件样式 */
  function ensureNavStyle() {
    if (document.getElementById('gu-nav-style')) return;
    const style = document.createElement('style');
    style.id = 'gu-nav-style';
    style.textContent = `
      #gu-nav-widget {
        display: flex;
        align-items: center;
        gap: 8px;
        cursor: pointer;
        padding: 6px 12px;
        border-radius: 12px;
        background: rgba(255,255,255,0.05);
        border: 1px solid rgba(255,255,255,0.1);
        transition: background 0.2s, border-color 0.2s;
        text-decoration: none;
        color: inherit;
        flex-shrink: 0;
      }
      #gu-nav-widget:hover {
        background: rgba(124,58,237,0.15);
        border-color: rgba(124,58,237,0.4);
      }
      #gu-nav-avatar {
        font-size: 20px;
        line-height: 1;
      }
      #gu-nav-info {
        display: flex;
        flex-direction: column;
        gap: 1px;
      }
      #gu-nav-nickname {
        font-size: 13px;
        font-weight: 600;
        color: #F0EAF8;
        max-width: 80px;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }
      #gu-nav-level {
        font-size: 10px;
        font-weight: 700;
        padding: 1px 6px;
        border-radius: 6px;
        background: linear-gradient(135deg, #F5C842, #F97316);
        color: #1A0A2E;
        display: inline-block;
        letter-spacing: 0.3px;
      }
    `;
    document.head.appendChild(style);
  }

  /** 在导航栏注入用户头像/昵称组件 */
  function injectNavWidget() {
    ensureNavStyle();
    const user = load();

    // 检查是否已注入
    if (document.getElementById('gu-nav-widget')) return;

    const widget = document.createElement('a');
    widget.id = 'gu-nav-widget';
    widget.href = 'profile.html';
    widget.title = '我的个人中心';
    widget.innerHTML = `
      <span id="gu-nav-avatar">${user.avatar}</span>
      <div id="gu-nav-info">
        <span id="gu-nav-nickname">${user.nickname}</span>
        <span id="gu-nav-level">Lv${user.level} · 🪙${user.coins || 0}</span>
      </div>
    `;

    // 优先插入 .nav-right，否则追加到 .nav
    const navRight = document.querySelector('.nav-right');
    const nav = document.querySelector('.nav');
    if (navRight) {
      navRight.insertBefore(widget, navRight.firstChild);
    } else if (nav) {
      nav.appendChild(widget);
    }
  }

  /** 刷新导航栏用户信息 */
  function refreshNavWidget() {
    const user = load();
    const avatar = document.getElementById('gu-nav-avatar');
    const nickname = document.getElementById('gu-nav-nickname');
    const level = document.getElementById('gu-nav-level');
    if (avatar) avatar.textContent = user.avatar;
    if (nickname) nickname.textContent = user.nickname;
    if (level) level.textContent = 'Lv' + user.level + ' · 🪙' + (user.coins || 0);
  }

  // ─── 更新登录时间 ─────────────────────────────────────────────────────────────

  function updateLastLogin() {
    const user = load();
    user.lastLogin = new Date().toISOString();
    save(user);
  }

  // ─── 自动初始化 ───────────────────────────────────────────────────────────────

  function init() {
    // 确保用户数据存在
    load();
    // 更新最后登录时间
    updateLastLogin();
    // DOM 就绪后注入导航栏
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', injectNavWidget);
    } else {
      // 稍微延迟，确保导航栏已渲染
      setTimeout(injectNavWidget, 50);
    }
  }

  // 立即执行初始化
  init();

  // ─── 公开 API ─────────────────────────────────────────────────────────────────

  return {

    /** 获取用户对象（深拷贝） */
    getUser() {
      return JSON.parse(JSON.stringify(load()));
    },

    /** 修改昵称 */
    setNickname(nickname) {
      if (!nickname || typeof nickname !== 'string') return;
      const user = load();
      user.nickname = nickname.trim().slice(0, 20);
      save(user);
      refreshNavWidget();
    },

    /** 修改头像 */
    setAvatar(avatar) {
      if (!avatar) return;
      const user = load();
      user.avatar = avatar;
      save(user);
      refreshNavWidget();
    },

    /** 获取当前金币数量 */
    getCoins() {
      return load().coins || 0;
    },

    /**
     * 增加金币
     * @param {number} amount 金币数
     * @param {string} [source] 来源说明（用于记录）
     */
    addCoins(amount, source = '') {
      if (!amount || amount <= 0) return;
      const user = load();
      user.coins = (user.coins || 0) + amount;
      user.coinLog = user.coinLog || [];
      user.coinLog.unshift({ type: 'earn', amount, source, ts: Date.now() });
      if (user.coinLog.length > 50) user.coinLog = user.coinLog.slice(0, 50);
      save(user);
      refreshNavWidget();
      return user.coins;
    },

    /**
     * 消费金币（失败返回 false）
     * @param {number} amount 消费数量
     * @param {string} [desc] 消费说明
     * @returns {boolean}
     */
    spendCoins(amount, desc = '') {
      if (!amount || amount <= 0) return false;
      const user = load();
      const cur = user.coins || 0;
      if (cur < amount) return false;
      user.coins = cur - amount;
      user.coinLog = user.coinLog || [];
      user.coinLog.unshift({ type: 'spend', amount: -amount, source: desc, ts: Date.now() });
      if (user.coinLog.length > 50) user.coinLog = user.coinLog.slice(0, 50);
      save(user);
      refreshNavWidget();
      return true;
    },

    /** 添加经验值，自动检测升级并弹出 Toast */
    addExp(amount) {
      if (!amount || amount <= 0) return;
      const user = load();
      const oldLevel = user.level;
      user.exp += amount;

      // 计算新等级
      let newLevel = 1;
      for (const lvInfo of LEVELS) {
        if (user.exp >= lvInfo.exp) newLevel = lvInfo.lv;
      }
      user.level = newLevel;
      save(user);

      // 升级了就弹 Toast
      if (newLevel > oldLevel) {
        showLevelUpToast(newLevel);
      }

      refreshNavWidget();
      return { exp: user.exp, level: user.level, leveledUp: newLevel > oldLevel };
    },

    /**
     * 记录一次游戏
     * @param {string} game   - 游戏名称
     * @param {string} result - 游戏结果（如"胜利"/"失败"/"完成"）
     * @param {number} score  - 分数
     */
    recordGame(game, result, score = 0) {
      const user = load();

      // 判断是否是新游戏种类
      const playedGames = new Set(user.gameHistory.map(h => h.game));
      const isNewGame = !playedGames.has(game);

      // 追加记录，最多保留20条
      user.gameHistory.unshift({
        game,
        result,
        score,
        time: new Date().toISOString()
      });
      if (user.gameHistory.length > 20) {
        user.gameHistory = user.gameHistory.slice(0, 20);
      }

      user.totalPlays += 1;
      if (isNewGame) user.totalGames += 1;

      save(user);
    },

    /** 跳转个人中心页 */
    openProfile() {
      window.location.href = 'profile.html';
    },

    /** 获取等级配置列表 */
    getLevels() {
      return [...LEVELS];
    },

    /** 获取头像列表 */
    getAvatarList() {
      return [...AVATAR_LIST];
    },

    /** 获取等级详情（传入exp或不传则读当前用户） */
    getLevelInfo(exp) {
      const e = exp !== undefined ? exp : load().exp;
      return calcLevel(e);
    },

    /** 格式化时间（供外部使用） */
    formatTime,

    /** 直接保存用户数据（供 profile.html 使用） */
    saveUser(user) {
      save(user);
      refreshNavWidget();
    },

    /** 重置用户数据（清空） */
    resetUser() {
      localStorage.removeItem(STORAGE_KEY);
      // 重新创建默认用户
      load();
      refreshNavWidget();
    }
  };

})();
