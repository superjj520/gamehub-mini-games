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

      if (existing) {
        // 更新
        await GHSupabase
          .from('campaign_stats')
          .update({
            plays:   existing.plays + 1,
            winners: existing.winners + (isWin ? 1 : 0),
          })
          .eq('campaign_id', campaignId)
          .eq('date', today);
      } else {
        // 新建
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
// 在 leaderboard.js 加载完成后执行（本文件放在 leaderboard.js 之后引入）
document.addEventListener('DOMContentLoaded', () => {
  if (typeof GameLeaderboard === 'undefined') return;

  const original = GameLeaderboard.submitAndNotify.bind(GameLeaderboard);
  GameLeaderboard.submitAndNotify = function(opts) {
    const result = original(opts);
    // 异步上报，不阻塞游戏
    GameReporter.report({
      game:   opts.game   || '',
      score:  opts.score  || 0,
      result: opts.result || '',
    }).catch(() => {});
    return result;
  };
});
