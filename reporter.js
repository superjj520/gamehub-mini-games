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

  return { report };
})();

// ─── 拦截 GameLeaderboard.submitAndNotify ───
// reporter.js 是动态注入的，DOMContentLoaded 可能已触发，直接执行
(function patchLeaderboard() {
  if (typeof GameLeaderboard !== 'undefined') {
    const original = GameLeaderboard.submitAndNotify.bind(GameLeaderboard);
    GameLeaderboard.submitAndNotify = function(opts) {
      const result = original(opts);
      GameReporter.report({
        game:   opts.game   || '',
        score:  opts.score  || 0,
        result: opts.result || '',
      }).catch(() => {});
      return result;
    };
  }
})();
