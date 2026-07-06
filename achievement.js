/**
 * GameHub 全局成就引擎
 * 功能：50个跨游戏成就，localStorage 持久化，右下角 Toast 动画提示
 * 用法：
 *   GameAchievement.unlock('jackpot')          // 直接解锁
 *   GameAchievement.trigger('spin', 1)          // 事件触发
 *   GameAchievement.isUnlocked('day1')          // 查询状态
 *   GameAchievement.getAll()                    // 获取所有成就
 *   GameAchievement.getStats()                  // 统计信息
 */

const GameAchievement = (() => {

  // ─── 存储键 ───
  const STORAGE_KEY = 'gh_achievements';

  // ─── 成就定义（50个） ───
  const DEFINITIONS = {

    // ══════════════ 抽奖类（10个） ══════════════
    first_spin: {
      name: '初次体验',
      desc: '第一次抽转盘',
      icon: '🎡',
      category: 'lottery'
    },
    lucky_streak: {
      name: '连续好运',
      desc: '连续3次中奖',
      icon: '🍀',
      category: 'lottery'
    },
    big_winner: {
      name: '大赢家',
      desc: '累计中奖10次',
      icon: '🏆',
      category: 'lottery'
    },
    hundred_spins: {
      name: '百转不厌',
      desc: '累计抽奖100次',
      icon: '💫',
      category: 'lottery'
    },
    jackpot: {
      name: '头彩',
      desc: '抽到一等奖',
      icon: '🎰',
      category: 'lottery'
    },
    scratch_master: {
      name: '刮刮达人',
      desc: '刮刮乐累计10次',
      icon: '🎟️',
      category: 'lottery'
    },
    gacha_collector: {
      name: '扭蛋狂人',
      desc: '扭蛋累计50次',
      icon: '🥚',
      category: 'lottery'
    },
    blind_box_god: {
      name: '盲盒欧皇',
      desc: '抽到SSR',
      icon: '✨',
      category: 'lottery'
    },
    full_wheel: {
      name: '全转一圈',
      desc: '转盘停在每个扇区至少一次',
      icon: '🎯',
      category: 'lottery'
    },
    no_miss: {
      name: '零遗漏',
      desc: '连续10次不谢谢参与',
      icon: '🔥',
      category: 'lottery'
    },

    // ══════════════ 益智类（10个） ══════════════
    sudoku_beginner: {
      name: '数独入门',
      desc: '完成第一个数独',
      icon: '🔢',
      category: 'puzzle'
    },
    sudoku_master: {
      name: '数独大师',
      desc: '困难难度无错完成',
      icon: '🧠',
      category: 'puzzle'
    },
    tetris_100: {
      name: '方块玩家',
      desc: '俄罗斯方块消除100行',
      icon: '🟦',
      category: 'puzzle'
    },
    match3_combo: {
      name: '连消王',
      desc: '消消乐连消5次以上',
      icon: '💎',
      category: 'puzzle'
    },
    puzzle_complete: {
      name: '拼图达人',
      desc: '完成5×5拼图',
      icon: '🧩',
      category: 'puzzle'
    },
    maze_speedrun: {
      name: '迷宫速通',
      desc: '迷宫60秒内完成',
      icon: '🏃',
      category: 'puzzle'
    },
    minesweeper_pro: {
      name: '扫雷专家',
      desc: '困难模式完成扫雷',
      icon: '💣',
      category: 'puzzle'
    },
    sokoban_perfect: {
      name: '推箱精英',
      desc: '100步内通关第5关',
      icon: '📦',
      category: 'puzzle'
    },
    game2048_1024: {
      name: '千里之行',
      desc: '2048游戏达到1024',
      icon: '🔢',
      category: 'puzzle'
    },
    game2048_2048: {
      name: '登峰造极',
      desc: '2048游戏达到2048',
      icon: '👑',
      category: 'puzzle'
    },

    // ══════════════ 技巧类（10个） ══════════════
    whack_100: {
      name: '地鼠猎手',
      desc: '打地鼠命中100只',
      icon: '🔨',
      category: 'skill'
    },
    fruit_ninja: {
      name: '切果无双',
      desc: '切水果连斩10次',
      icon: '🍉',
      category: 'skill'
    },
    archery_bullseye: {
      name: '百步穿杨',
      desc: '射箭连续3次10环',
      icon: '🎯',
      category: 'skill'
    },
    fishing_legend: {
      name: '钓鱼传说',
      desc: '钓到鲨鱼',
      icon: '🦈',
      category: 'skill'
    },
    slingshot_ace: {
      name: '弹弓高手',
      desc: '弹弓射击5发全中',
      icon: '🪃',
      category: 'skill'
    },
    snake_long: {
      name: '长蛇阵',
      desc: '贪吃蛇长度达到30',
      icon: '🐍',
      category: 'skill'
    },
    jump_perfect: {
      name: '跳跃大师',
      desc: '跳一跳连续完美着陆10次',
      icon: '🦘',
      category: 'skill'
    },
    pinball_500: {
      name: '弹珠高手',
      desc: '弹珠机单局500分',
      icon: '⚪',
      category: 'skill'
    },
    ring_ace: {
      name: '套圈达人',
      desc: '套圈连中5个',
      icon: '⭕',
      category: 'skill'
    },
    catch_100: {
      name: '接物达人',
      desc: '接金币单局接到100个',
      icon: '🪙',
      category: 'skill'
    },

    // ══════════════ 留存类（10个） ══════════════
    day1: {
      name: '初来乍到',
      desc: '第一次登录',
      icon: '👋',
      category: 'retention'
    },
    day3: {
      name: '三日之约',
      desc: '连续签到3天',
      icon: '📅',
      category: 'retention'
    },
    day7: {
      name: '一周坚持',
      desc: '连续签到7天',
      icon: '🗓️',
      category: 'retention'
    },
    day30: {
      name: '月度常客',
      desc: '累计登录30天',
      icon: '🎖️',
      category: 'retention'
    },
    checkin_streak: {
      name: '连签达人',
      desc: '7日连续签到',
      icon: '✅',
      category: 'retention'
    },
    energy_full: {
      name: '能量爆满',
      desc: '能量收集满100',
      icon: '⚡',
      category: 'retention'
    },
    tree_harvest: {
      name: '丰收时刻',
      desc: '成长树第一次结果',
      icon: '🌳',
      category: 'retention'
    },
    stamp_complete: {
      name: '集章完成',
      desc: '集卡集章集满一套',
      icon: '📮',
      category: 'retention'
    },
    progress_milestone: {
      name: '里程碑',
      desc: '进度解锁达到第5个节点',
      icon: '🏁',
      category: 'retention'
    },
    collector: {
      name: '收藏家',
      desc: '盲盒图鉴收集超过10张',
      icon: '🗂️',
      category: 'retention'
    },

    // ══════════════ 社交类（10个） ══════════════
    vote_first: {
      name: '第一票',
      desc: '投票PK第一次投票',
      icon: '🗳️',
      category: 'social'
    },
    test_all: {
      name: '全科测试',
      desc: '性格测试完成全部4套',
      icon: '📝',
      category: 'social'
    },
    bomb_survivor: {
      name: '炸弹幸存者',
      desc: '数字炸弹不被炸中3局',
      icon: '💥',
      category: 'social'
    },
    cup_streak: {
      name: '三杯连胜',
      desc: '三杯游戏连胜5次',
      icon: '🥤',
      category: 'social'
    },
    quiz_perfect: {
      name: '满分学霸',
      desc: '问答闯关10题全对',
      icon: '🎓',
      category: 'social'
    },
    team_mvp: {
      name: '团队MVP',
      desc: '组队挑战个人贡献第一',
      icon: '🌟',
      category: 'social'
    },
    rank_top3: {
      name: '登上领奖台',
      desc: '好友排行榜进前3',
      icon: '🥇',
      category: 'social'
    },
    name_gen: {
      name: '起名大师',
      desc: '名字生成器生成10个',
      icon: '✍️',
      category: 'social'
    },
    share_first: {
      name: '分享达人',
      desc: '第一次分享游戏结果',
      icon: '📤',
      category: 'social'
    },
    all_games: {
      name: '全能玩家',
      desc: '玩过10种不同游戏',
      icon: '🎮',
      category: 'social'
    }
  };

  // ─── 读取存储 ───
  function loadState() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      return raw ? JSON.parse(raw) : {};
    } catch (e) {
      return {};
    }
  }

  // ─── 写入存储 ───
  function saveState(state) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch (e) {
      // 存储写入失败时静默处理
    }
  }

  // ─── Toast 队列 ───
  const toastQueue = [];
  let toastRunning = false;

  // ─── 注入 Toast 样式（只注入一次） ───
  function ensureStyles() {
    if (document.getElementById('ga-styles')) return;
    const style = document.createElement('style');
    style.id = 'ga-styles';
    style.textContent = `
      /* 成就 Toast 容器 */
      #ga-container {
        position: fixed;
        bottom: 24px;
        right: 24px;
        z-index: 10000;
        display: flex;
        flex-direction: column-reverse;
        gap: 10px;
        pointer-events: none;
      }

      /* 单条 Toast 卡片 */
      .ga-toast {
        position: relative;
        width: 280px;
        background: rgba(18, 10, 36, 0.96);
        border: 1px solid rgba(255, 215, 0, 0.25);
        border-radius: 14px;
        padding: 14px 16px 14px 14px;
        display: flex;
        align-items: flex-start;
        gap: 12px;
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.5), 0 0 0 1px rgba(255,215,0,0.08);
        overflow: hidden;
        opacity: 0;
        transform: translateX(120px);
        transition: opacity 0.35s ease, transform 0.35s cubic-bezier(0.34, 1.56, 0.64, 1);
        pointer-events: all;
      }

      /* 金色顶部光条 */
      .ga-toast::before {
        content: '';
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        height: 3px;
        background: linear-gradient(90deg, #FFD700, #FFA500, #FFD700);
        border-radius: 14px 14px 0 0;
      }

      /* 进入动画 */
      .ga-toast.ga-show {
        opacity: 1;
        transform: translateX(0);
      }

      /* 退出动画 */
      .ga-toast.ga-hide {
        opacity: 0;
        transform: translateX(120px);
        transition: opacity 0.3s ease, transform 0.3s ease;
      }

      /* 成就图标容器 */
      .ga-icon {
        font-size: 28px;
        line-height: 1;
        flex-shrink: 0;
        margin-top: 1px;
        filter: drop-shadow(0 0 6px rgba(255,215,0,0.6));
      }

      /* 文字区 */
      .ga-text {
        flex: 1;
        min-width: 0;
      }

      /* 解锁标签 */
      .ga-label {
        font-size: 10px;
        color: #FFD700;
        font-weight: 600;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        margin-bottom: 2px;
        font-family: system-ui, -apple-system, sans-serif;
      }

      /* 成就名称 */
      .ga-name {
        font-size: 15px;
        font-weight: 700;
        color: #FFFFFF;
        margin-bottom: 2px;
        font-family: system-ui, -apple-system, sans-serif;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }

      /* 成就描述 */
      .ga-desc {
        font-size: 12px;
        color: rgba(255,255,255,0.55);
        font-family: system-ui, -apple-system, sans-serif;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }

      /* 粒子点 */
      .ga-particle {
        position: absolute;
        width: 5px;
        height: 5px;
        border-radius: 50%;
        background: #FFD700;
        pointer-events: none;
        animation: ga-particle-burst 0.7s ease-out forwards;
      }

      @keyframes ga-particle-burst {
        0%   { opacity: 1; transform: translate(0, 0) scale(1); }
        100% { opacity: 0; transform: translate(var(--dx), var(--dy)) scale(0.2); }
      }
    `;
    document.head.appendChild(style);

    // 创建容器
    if (!document.getElementById('ga-container')) {
      const container = document.createElement('div');
      container.id = 'ga-container';
      document.body.appendChild(container);
    }
  }

  // ─── 生成粒子特效 ───
  function spawnParticles(toast) {
    const count = 4 + Math.floor(Math.random() * 2); // 4~5颗
    for (let i = 0; i < count; i++) {
      const p = document.createElement('div');
      p.className = 'ga-particle';

      // 随机位置（在 icon 附近）
      const startX = 20 + Math.random() * 30;
      const startY = 20 + Math.random() * 20;
      p.style.left = startX + 'px';
      p.style.top = startY + 'px';

      // 随机飞出方向
      const angle = Math.random() * Math.PI * 2;
      const dist = 25 + Math.random() * 30;
      p.style.setProperty('--dx', Math.cos(angle) * dist + 'px');
      p.style.setProperty('--dy', Math.sin(angle) * dist + 'px');

      // 随机金/橙色
      const colors = ['#FFD700', '#FFA500', '#FFEC8B', '#FFB347'];
      p.style.background = colors[Math.floor(Math.random() * colors.length)];

      // 随机延迟
      p.style.animationDelay = (Math.random() * 0.15) + 's';

      toast.appendChild(p);

      // 动画结束后清除
      setTimeout(() => p.remove(), 1000);
    }
  }

  // ─── 显示一条 Toast（内部） ───
  function showToast(definition) {
    ensureStyles();

    const container = document.getElementById('ga-container');
    if (!container) return;

    // 创建 Toast DOM
    const toast = document.createElement('div');
    toast.className = 'ga-toast';
    toast.innerHTML = `
      <div class="ga-icon">${definition.icon}</div>
      <div class="ga-text">
        <div class="ga-label">成就解锁</div>
        <div class="ga-name">${definition.name}</div>
        <div class="ga-desc">${definition.desc}</div>
      </div>
    `;

    container.appendChild(toast);

    // 触发入场动画（异步，等 DOM 渲染）
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        toast.classList.add('ga-show');
        spawnParticles(toast);
      });
    });

    // 3秒后退出
    const DURATION = 3000;
    setTimeout(() => {
      toast.classList.remove('ga-show');
      toast.classList.add('ga-hide');

      // 退出动画结束后移除 DOM，处理下一条队列
      setTimeout(() => {
        toast.remove();
        toastRunning = false;
        processQueue();
      }, 350);
    }, DURATION);
  }

  // ─── 队列处理 ───
  function processQueue() {
    if (toastRunning || toastQueue.length === 0) return;
    toastRunning = true;
    const next = toastQueue.shift();
    showToast(next);
  }

  // ─── 加入队列 ───
  function enqueueToast(definition) {
    toastQueue.push(definition);
    processQueue();
  }

  // ─── 核心：解锁成就 ───
  function unlock(id) {
    const def = DEFINITIONS[id];
    if (!def) return false; // 未知成就 ID

    const state = loadState();

    // 已解锁则跳过
    if (state[id] && state[id].unlocked) return false;

    // 标记解锁
    state[id] = {
      unlocked: true,
      unlockedAt: Date.now()
    };
    saveState(state);

    // 弹出 Toast
    enqueueToast(def);

    return true;
  }

  // ─── 累计计数器（内部状态，存在同一 localStorage 下） ───
  function getCounters() {
    const state = loadState();
    return state.__counters__ || {};
  }

  function saveCounters(counters) {
    const state = loadState();
    state.__counters__ = counters;
    saveState(state);
  }

  function incCounter(key, value) {
    const counters = getCounters();
    counters[key] = (counters[key] || 0) + value;
    saveCounters(counters);
    return counters[key];
  }

  function getCounter(key) {
    return getCounters()[key] || 0;
  }

  // ─── 事件触发逻辑 ───
  function trigger(event, value) {
    value = value || 1;

    switch (event) {

      // ── 抽奖类 ──
      case 'spin': {
        // 第一次抽转盘
        unlock('first_spin');

        // 累计抽奖
        const total = incCounter('spin_total', value);
        if (total >= 100) unlock('hundred_spins');
        break;
      }

      case 'win': {
        // 累计中奖
        const winTotal = incCounter('win_total', value);
        if (winTotal >= 10) unlock('big_winner');

        // 连续中奖计数
        const streak = incCounter('win_streak', value);
        if (streak >= 3) unlock('lucky_streak');
        break;
      }

      case 'no_win': {
        // 未中奖，重置连胜计数
        const counters = getCounters();
        counters['win_streak'] = 0;
        saveCounters(counters);
        break;
      }

      case 'no_miss_streak': {
        // 连续非"谢谢参与"
        const nmStreak = incCounter('no_miss_streak', value);
        if (nmStreak >= 10) unlock('no_miss');
        break;
      }

      case 'miss': {
        // 谢谢参与，重置不谢谢连续计数
        const counters = getCounters();
        counters['no_miss_streak'] = 0;
        saveCounters(counters);
        break;
      }

      case 'scratch': {
        // 刮刮乐
        const scratchTotal = incCounter('scratch_total', value);
        if (scratchTotal >= 10) unlock('scratch_master');
        break;
      }

      case 'gacha': {
        // 扭蛋
        const gachaTotal = incCounter('gacha_total', value);
        if (gachaTotal >= 50) unlock('gacha_collector');
        break;
      }

      case 'ssr': {
        // 抽到 SSR
        unlock('blind_box_god');
        break;
      }

      case 'jackpot': {
        // 一等奖
        unlock('jackpot');
        break;
      }

      case 'wheel_sector': {
        // 记录转盘扇区命中
        // value 应为扇区标识字符串或数字
        const counters = getCounters();
        if (!counters['wheel_sectors']) counters['wheel_sectors'] = {};
        counters['wheel_sectors'][String(value)] = true;
        saveCounters(counters);
        // 检查是否集齐所有扇区（需外部传入 total 参数，默认8个）
        break;
      }

      case 'wheel_sectors_complete': {
        // 转盘已集齐所有扇区（由游戏侧判断后调用）
        unlock('full_wheel');
        break;
      }

      // ── 益智类 ──
      case 'sudoku_complete': {
        unlock('sudoku_beginner');
        break;
      }

      case 'sudoku_hard_perfect': {
        unlock('sudoku_master');
        break;
      }

      case 'tetris_lines': {
        const lines = incCounter('tetris_lines', value);
        if (lines >= 100) unlock('tetris_100');
        break;
      }

      case 'match3_combo': {
        // value 为本次连消次数
        if (value >= 5) unlock('match3_combo');
        break;
      }

      case 'puzzle_complete': {
        unlock('puzzle_complete');
        break;
      }

      case 'maze_complete': {
        // value 为用时秒数
        if (value <= 60) unlock('maze_speedrun');
        break;
      }

      case 'minesweeper_hard': {
        unlock('minesweeper_pro');
        break;
      }

      case 'sokoban_level5': {
        // value 为步数
        if (value <= 100) unlock('sokoban_perfect');
        break;
      }

      case '2048_tile': {
        // value 为当前最大方块值
        if (value >= 1024) unlock('game2048_1024');
        if (value >= 2048) unlock('game2048_2048');
        break;
      }

      // ── 技巧类 ──
      case 'whack': {
        const whackTotal = incCounter('whack_total', value);
        if (whackTotal >= 100) unlock('whack_100');
        break;
      }

      case 'fruit_slash': {
        // value 为本次连斩数
        if (value >= 10) unlock('fruit_ninja');
        break;
      }

      case 'archery_10': {
        // 连续10环计数
        const bullsStreak = incCounter('archery_10_streak', value);
        if (bullsStreak >= 3) unlock('archery_bullseye');
        break;
      }

      case 'archery_miss': {
        // 未射中10环，重置连续
        const counters = getCounters();
        counters['archery_10_streak'] = 0;
        saveCounters(counters);
        break;
      }

      case 'fishing_shark': {
        unlock('fishing_legend');
        break;
      }

      case 'slingshot_hit': {
        // 累计连续命中（value=1 命中，0 未中）
        if (value === 1) {
          const slStreak = incCounter('slingshot_streak', 1);
          if (slStreak >= 5) unlock('slingshot_ace');
        } else {
          const counters = getCounters();
          counters['slingshot_streak'] = 0;
          saveCounters(counters);
        }
        break;
      }

      case 'snake_length': {
        // value 为当前蛇长
        if (value >= 30) unlock('snake_long');
        break;
      }

      case 'jump_perfect': {
        // 连续完美着陆计数
        const jumpStreak = incCounter('jump_perfect_streak', value);
        if (jumpStreak >= 10) unlock('jump_perfect');
        break;
      }

      case 'jump_miss': {
        const counters = getCounters();
        counters['jump_perfect_streak'] = 0;
        saveCounters(counters);
        break;
      }

      case 'pinball_score': {
        // value 为本局分数
        if (value >= 500) unlock('pinball_500');
        break;
      }

      case 'ring_hit': {
        // 连续套中计数
        if (value === 1) {
          const ringStreak = incCounter('ring_streak', 1);
          if (ringStreak >= 5) unlock('ring_ace');
        } else {
          const counters = getCounters();
          counters['ring_streak'] = 0;
          saveCounters(counters);
        }
        break;
      }

      case 'catch_score': {
        // value 为本局接到的金币数
        if (value >= 100) unlock('catch_100');
        break;
      }

      // ── 留存类 ──
      case 'checkin': {
        // value 为当前连续签到天数
        if (value >= 3)  unlock('day3');
        if (value >= 7)  { unlock('day7'); unlock('checkin_streak'); }

        // 累计登录天数
        const loginDays = incCounter('login_days_total', 1);
        if (loginDays >= 30) unlock('day30');
        break;
      }

      case 'energy_full': {
        unlock('energy_full');
        break;
      }

      case 'tree_harvest': {
        unlock('tree_harvest');
        break;
      }

      case 'stamp_complete': {
        unlock('stamp_complete');
        break;
      }

      case 'progress_node': {
        // value 为当前节点编号
        if (value >= 5) unlock('progress_milestone');
        break;
      }

      case 'blind_box_collect': {
        // value 为当前图鉴数量
        if (value >= 10) unlock('collector');
        break;
      }

      // ── 社交类 ──
      case 'vote': {
        unlock('vote_first');
        break;
      }

      case 'personality_test': {
        // value 为已完成套数
        if (value >= 4) unlock('test_all');
        break;
      }

      case 'bomb_survive': {
        // 累计不被炸中局数
        const bombSurv = incCounter('bomb_survive', value);
        if (bombSurv >= 3) unlock('bomb_survivor');
        break;
      }

      case 'cup_win': {
        // 连胜计数
        const cupStreak = incCounter('cup_streak', value);
        if (cupStreak >= 5) unlock('cup_streak');
        break;
      }

      case 'cup_lose': {
        const counters = getCounters();
        counters['cup_streak'] = 0;
        saveCounters(counters);
        break;
      }

      case 'quiz_perfect': {
        // value 为本局答对题数
        if (value >= 10) unlock('quiz_perfect');
        break;
      }

      case 'team_mvp': {
        unlock('team_mvp');
        break;
      }

      case 'rank_top3': {
        unlock('rank_top3');
        break;
      }

      case 'name_gen': {
        // 累计生成名字数
        const nameCount = incCounter('name_gen', value);
        if (nameCount >= 10) unlock('name_gen');
        break;
      }

      case 'share': {
        unlock('share_first');
        break;
      }

      case 'first_game': {
        // value 为游戏名称字符串
        const counters = getCounters();
        if (!counters['played_games']) counters['played_games'] = {};
        counters['played_games'][String(value)] = true;
        const gameCount = Object.keys(counters['played_games']).length;
        saveCounters(counters);
        if (gameCount >= 10) unlock('all_games');
        break;
      }

      default:
        // 未知事件，静默忽略
        break;
    }
  }

  // ─── 查询是否已解锁 ───
  function isUnlocked(id) {
    const state = loadState();
    return !!(state[id] && state[id].unlocked);
  }

  // ─── 获取所有成就（含状态） ───
  function getAll() {
    const state = loadState();
    return Object.keys(DEFINITIONS).map(id => {
      const def = DEFINITIONS[id];
      const record = state[id];
      return {
        id,
        name: def.name,
        desc: def.desc,
        icon: def.icon,
        category: def.category,
        unlocked: !!(record && record.unlocked),
        unlockedAt: record ? record.unlockedAt : null
      };
    });
  }

  // ─── 统计信息 ───
  function getStats() {
    const all = getAll();
    const total = all.length;
    const unlocked = all.filter(a => a.unlocked).length;
    return {
      unlocked,
      total,
      percent: total > 0 ? Math.round((unlocked / total) * 100) : 0,
      byCategory: {
        lottery:   all.filter(a => a.category === 'lottery'),
        puzzle:    all.filter(a => a.category === 'puzzle'),
        skill:     all.filter(a => a.category === 'skill'),
        retention: all.filter(a => a.category === 'retention'),
        social:    all.filter(a => a.category === 'social')
      }
    };
  }

  // ─── 自动初始化：首次加载 ───
  (function init() {
    // 等待 DOM 就绪后执行（兼容脚本放在 <head> 的情况）
    function onReady() {
      const state = loadState();

      // 记录今日访问日期
      const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
      const counters = getCounters();

      // 首次访问 → 触发 day1
      if (!state['day1'] || !state['day1'].unlocked) {
        // 稍作延迟，确保页面渲染完成后再弹 Toast
        setTimeout(() => unlock('day1'), 800);
      }

      // 记录访问日期集合（用于计算累计登录天数，不重复计当天）
      if (!counters['visit_dates']) counters['visit_dates'] = {};
      if (!counters['visit_dates'][today]) {
        counters['visit_dates'][today] = true;
        // 累计登录天数
        counters['login_days_total'] = Object.keys(counters['visit_dates']).length;
        saveCounters(counters);

        // 达到30天
        if (counters['login_days_total'] >= 30) {
          setTimeout(() => unlock('day30'), 1200);
        }
      }
    }

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', onReady);
    } else {
      onReady();
    }
  })();

  // ─── 对外暴露 API ───
  return {
    unlock,
    trigger,
    isUnlocked,
    getAll,
    getStats
  };

})();

// 挂载到全局，方便各游戏页面直接调用
window.GameAchievement = GameAchievement;
