/**
 * GameHub 全局排行榜引擎
 * 纯 localStorage 本地存储，无需后端
 * 用法：GameLeaderboard.submit({ game: '大转盘', score: 100, result: '一等奖' })
 */

// ─── 动态注入 Supabase SDK + supabase.js + auth-player.js + reporter.js ───
(function() {
  const base = (function() {
    const scripts = document.querySelectorAll('script[src]');
    for (const s of scripts) {
      if (s.src.includes('leaderboard.js')) {
        return s.src.replace('leaderboard.js', '');
      }
    }
    return '';
  })();

  function loadScript(src, onload) {
    if (document.querySelector('script[src="' + src + '"]')) { if (onload) onload(); return; }
    const s = document.createElement('script');
    s.src = src;
    if (onload) s.onload = onload;
    document.head.appendChild(s);
  }

  // 按顺序加载：SDK → supabase.js → auth-player.js → reporter.js
  loadScript('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js', function() {
    loadScript(base + 'supabase.js', function() {
      loadScript(base + 'auth-player.js');
      loadScript(base + 'reporter.js');
    });
  });
})();

const GameLeaderboard = (() => {
  const STORAGE_KEY = 'gh_leaderboard';
  const MAX_PER_GAME = 100;  // 每个游戏最多保存100条记录
  const MAX_GLOBAL   = 500;  // 全局最多500条

  // ─── 读写 ───
  function load() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}');
    } catch { return {}; }
  }

  function save(data) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
    } catch (e) { /* 存储满时静默 */ }
  }

  // ─── 获取当前用户信息 ───
  function getCurrentUser() {
    try {
      const u = JSON.parse(localStorage.getItem('gh_user') || '{}');
      return {
        nickname: u.nickname || '匿名玩家',
        avatar:   u.avatar   || '🎮',
        level:    u.level    || 1,
        uid:      u.uid      || 'local',
      };
    } catch {
      return { nickname: '匿名玩家', avatar: '🎮', level: 1, uid: 'local' };
    }
  }

  /**
   * 提交一条游戏得分记录
   * @param {object} opts
   * @param {string} opts.game    游戏名称（如 '大转盘'）
   * @param {number} opts.score   分数（越高越好）
   * @param {string} [opts.result] 结果文字（如 '一等奖'）
   * @param {string} [opts.extra]  附加说明
   * @returns {{ isPersonalBest: boolean, rank: number }}
   */
  function submit({ game, score, result = '', extra = '' }) {
    if (!game || score == null) return { isPersonalBest: false, rank: -1 };

    const data = load();
    if (!data[game]) data[game] = [];

    const user = getCurrentUser();
    const entry = {
      uid:       user.uid,
      nickname:  user.nickname,
      avatar:    user.avatar,
      level:     user.level,
      score:     Number(score),
      result,
      extra,
      ts:        Date.now(),
    };

    data[game].push(entry);

    // 按分数降序，截断到最大条数
    data[game].sort((a, b) => b.score - a.score);
    if (data[game].length > MAX_PER_GAME) data[game] = data[game].slice(0, MAX_PER_GAME);

    // 全局条数控制
    const total = Object.values(data).reduce((s, arr) => s + arr.length, 0);
    if (total > MAX_GLOBAL) {
      // 删除最老的条目
      const oldest = Object.entries(data)
        .flatMap(([g, arr]) => arr.map(e => ({ ...e, _g: g })))
        .sort((a, b) => a.ts - b.ts)[0];
      if (oldest) {
        data[oldest._g] = data[oldest._g].filter(e => e.ts !== oldest.ts);
      }
    }

    save(data);

    // 计算当前提交的排名
    const rank = data[game].findIndex(e => e.ts === entry.ts) + 1;

    // 判断是否个人最高
    const myRecords = data[game].filter(e => e.uid === user.uid);
    const myBest = myRecords.length > 1
      ? Math.max(...myRecords.slice(0, -1).map(e => e.score))
      : -Infinity;
    const isPersonalBest = score > myBest;

    return { isPersonalBest, rank };
  }

  /**
   * 获取某游戏排行榜 Top N
   * @param {string} game 游戏名，null 表示全局
   * @param {number} n    条数
   * @returns {Array}
   */
  function getTop(game, n = 10) {
    const data = load();
    let records;
    if (game) {
      records = (data[game] || []).slice();
    } else {
      // 全局：每个游戏取最高分
      records = Object.entries(data).flatMap(([g, arr]) => {
        if (!arr.length) return [];
        return [{ ...arr[0], game: g }];
      });
    }
    records.sort((a, b) => b.score - a.score);
    return records.slice(0, n);
  }

  /**
   * 获取某用户在某游戏的个人记录
   * @param {string} game
   * @param {string} uid  不传则取当前用户
   * @returns {Array}
   */
  function getPersonal(game, uid) {
    const data = load();
    const u = uid || getCurrentUser().uid;
    const arr = game ? (data[game] || []) : Object.values(data).flat();
    return arr.filter(e => e.uid === u).sort((a, b) => b.score - a.score);
  }

  /**
   * 获取当前用户个人最高分
   * @param {string} game
   * @returns {number}
   */
  function getPersonalBest(game) {
    const records = getPersonal(game);
    return records.length ? records[0].score : 0;
  }

  /**
   * 获取所有有记录的游戏列表
   * @returns {string[]}
   */
  function getGames() {
    const data = load();
    return Object.keys(data).filter(g => data[g].length > 0);
  }

  /**
   * 获取全局统计摘要
   */
  function getSummary() {
    const data = load();
    const games = getGames();
    const allRecords = Object.values(data).flat();
    const user = getCurrentUser();
    const myRecords = allRecords.filter(e => e.uid === user.uid);

    return {
      totalGames:    games.length,
      totalPlays:    allRecords.length,
      myPlays:       myRecords.length,
      myBestScore:   myRecords.length ? Math.max(...myRecords.map(e => e.score)) : 0,
      myFavoriteGame: (() => {
        if (!myRecords.length) return null;
        const cnt = {};
        myRecords.forEach(e => { cnt[e.game || ''] = (cnt[e.game || ''] || 0) + 1; });
        return Object.entries(cnt).sort((a, b) => b[1] - a[1])[0]?.[0] || null;
      })(),
    };
  }

  /**
   * 清空排行榜（谨慎使用）
   * @param {string} [game] 不传则清空全部
   */
  function clear(game) {
    if (game) {
      const data = load();
      delete data[game];
      save(data);
    } else {
      localStorage.removeItem(STORAGE_KEY);
    }
  }

  // ─── 提交成功 Toast ───
  function showSubmitToast({ rank, isPersonalBest, game }) {
    const msg = isPersonalBest
      ? `🏆 个人最高分！排名 #${rank}`
      : `📊 ${game} 排名 #${rank}`;

    let el = document.getElementById('lb-toast');
    if (!el) {
      el = document.createElement('div');
      el.id = 'lb-toast';
      el.style.cssText = `
        position:fixed;bottom:80px;left:50%;transform:translateX(-50%) translateY(20px);
        background:rgba(26,10,46,0.95);border:1px solid rgba(124,58,237,0.4);
        border-radius:24px;padding:10px 20px;font-size:13px;color:#F0EAF8;
        z-index:8888;opacity:0;transition:opacity 0.3s,transform 0.3s;
        font-family:-apple-system,'PingFang SC',sans-serif;white-space:nowrap;
        box-shadow:0 4px 20px rgba(0,0,0,0.5);
      `;
      document.body.appendChild(el);
    }
    el.textContent = msg;
    el.style.opacity = '1';
    el.style.transform = 'translateX(-50%) translateY(0)';
    clearTimeout(el._timer);
    el._timer = setTimeout(() => {
      el.style.opacity = '0';
      el.style.transform = 'translateX(-50%) translateY(20px)';
    }, 2500);
  }

  /**
   * 提交 + 显示 Toast 一步完成
   */
  function submitAndNotify(opts) {
    const result = submit(opts);
    if (result.rank > 0) {
      showSubmitToast({ rank: result.rank, isPersonalBest: result.isPersonalBest, game: opts.game });
    }
    return result;
  }

  return {
    submit,
    submitAndNotify,
    getTop,
    getPersonal,
    getPersonalBest,
    getGames,
    getSummary,
    clear,
  };
})();
