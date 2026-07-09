/**
 * GameHub 游戏数据上报模块
 * 依赖：supabase.js（先引入）
 * 自动拦截 GameLeaderboard.submitAndNotify() 钩子，离线时降级为 localStorage
 */

const GameReporter = (() => {

  /**
   * 上报一局游戏结果到 Supabase
   * @param {object} opts
   * @param {string} opts.game    游戏名称
   * @param {number} opts.score   得分
   * @param {string} opts.result  结果文字（中奖奖品名 / 未中）
   */
  async function report({ game, score, result = '' }) {
    // 未登录或无活动ID时静默跳过，不影响游戏
    const player     = GameSupabase.getCurrentPlayer();
    const campaignId = GameSupabase.getCampaignId();
    if (!player || !campaignId) return;

    try {
      // 1. 插入 play_sessions
      const { error: sessionError } = await GHSupabase
        .from('play_sessions')
        .insert({
          campaign_id: campaignId,
          player_id:   player.id,
          score:       Number(score) || 0,
          result:      result || game,
        });

      if (sessionError) {
        console.warn('[Reporter] play_sessions 写入失败:', sessionError.message);
        return;
      }

      // 2. upsert campaign_stats（当天汇总）
      const today = new Date().toISOString().slice(0, 10);
      const isWin = result && result !== '谢谢参与' && result !== '未中' && result !== '';

      // 先读当天记录
      const { data: existing } = await GHSupabase
        .from('campaign_stats')
        .select('plays, winners, unique_players')
        .eq('campaign_id', campaignId)
        .eq('date', today)
        .single();

      // 检查今天该玩家是否已经玩过（用于 unique_players 去重）
      const { count: todayCount } = await GHSupabase
        .from('play_sessions')
        .select('id', { count: 'exact', head: true })
        .eq('campaign_id', campaignId)
        .eq('player_id', player.id)
        .gte('played_at', today + 'T00:00:00Z')
        .lt('played_at', today + 'T23:59:59Z');
      const isNewPlayerToday = todayCount === 1; // 刚插入的那条，所以等于1表示今天首次

      if (existing) {
        await GHSupabase
          .from('campaign_stats')
          .update({
            plays:          existing.plays + 1,
            winners:        existing.winners + (isWin ? 1 : 0),
            unique_players: existing.unique_players + (isNewPlayerToday ? 1 : 0),
          })
          .eq('campaign_id', campaignId)
          .eq('date', today);
      } else {
        await GHSupabase
          .from('campaign_stats')
          .insert({
            campaign_id:    campaignId,
            date:           today,
            plays:          1,
            winners:        isWin ? 1 : 0,
            unique_players: 1,
          });
      }
    } catch (e) {
      // 网络错误时静默，不影响游戏体验
      console.warn('[Reporter] 上报失败:', e.message);
    }
  }

  // ─── 中奖反馈弹窗 ───
  function showWinModal(result) {
    // 避免重复创建
    let overlay = document.getElementById('gh-win-overlay');
    if (!overlay) {
      overlay = document.createElement('div');
      overlay.id = 'gh-win-overlay';
      overlay.style.cssText = `
        position:fixed;inset:0;z-index:99999;
        display:flex;align-items:center;justify-content:center;
        background:rgba(0,0,0,0.65);backdrop-filter:blur(4px);
        font-family:-apple-system,'PingFang SC',sans-serif;
      `;
      overlay.innerHTML = `
        <div style="background:linear-gradient(135deg,#1a0a2e,#2d1054);border:1px solid rgba(245,200,66,0.4);
          border-radius:20px;padding:32px 28px;width:min(320px,88vw);text-align:center;
          box-shadow:0 8px 40px rgba(0,0,0,0.6);">
          <div style="font-size:48px;margin-bottom:12px">🎉</div>
          <div style="font-size:20px;font-weight:800;color:#F5C842;margin-bottom:8px">恭喜中奖！</div>
          <div id="gh-win-prize" style="font-size:16px;color:#F0EAF8;margin-bottom:20px;font-weight:600"></div>
          <div style="font-size:12px;color:rgba(240,234,248,0.6);margin-bottom:20px;line-height:1.6">
            请截图保存此页面，<br>联系活动方核对身份后领取奖品
          </div>
          <button id="gh-win-close" style="width:100%;padding:12px;border-radius:10px;border:none;
            background:linear-gradient(135deg,#7C3AED,#EC4899);color:white;font-size:15px;
            font-weight:700;cursor:pointer;font-family:inherit">
            好的，我知道了
          </button>
        </div>
      `;
      document.body.appendChild(overlay);
      document.getElementById('gh-win-close').onclick = () => { overlay.style.display = 'none'; };
    }
    document.getElementById('gh-win-prize').textContent = result;
    overlay.style.display = 'flex';
  }

  return { report, showWinModal };
})();

// ─── 拦截 GameLeaderboard.submitAndNotify ───
// reporter.js 是动态注入的，DOMContentLoaded 可能已触发，直接执行
(function patchLeaderboard() {
  if (typeof GameLeaderboard !== 'undefined') {
    const original = GameLeaderboard.submitAndNotify.bind(GameLeaderboard);
    GameLeaderboard.submitAndNotify = function(opts) {
      const result = original(opts);
      const res = opts.result || '';
      const isWin = res && res !== '谢谢参与' && res !== '未中' && res !== '';
      GameReporter.report({
        game:   opts.game  || '',
        score:  opts.score || 0,
        result: res,
      }).catch(() => {});
      // 有活动 ID 且中奖时，显示领奖引导弹窗
      if (isWin && GameSupabase && GameSupabase.getCampaignId()) {
        setTimeout(() => GameReporter.showWinModal(res), 800);
      }
      // 未登录时，游戏结束后提示登录
      if (GameSupabase && GameSupabase.getCampaignId() && !GameSupabase.isLoggedIn()) {
        setTimeout(() => { if (typeof GameAuth !== 'undefined') GameAuth.promptAfterGame(); }, 1200);
      }
      return result;
    };
  }
})();
