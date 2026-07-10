/**
 * GameHub 邀请裂变模块
 * 依赖：supabase.js
 * 功能：邀请链接追踪 + 双方奖励
 */
const GameInvite = (() => {
  var STORAGE_KEY = 'gh_invited_by';

  /** 从 URL 读取邀请码 (?invite=xxx) 并记录 */
  function trackInvite() {
    var params = new URLSearchParams(location.search);
    var inviter = params.get('invite');
    if (!inviter) return;

    // 去重：同一邀请码只记录一次
    var recorded = localStorage.getItem(STORAGE_KEY);
    if (recorded === inviter) return;

    localStorage.setItem(STORAGE_KEY, inviter);

    // 异步上报
    try {
      GHSupabase.from('invites').insert({
        inviter_id: inviter,
        invited_player: GameSupabase.getCurrentPlayer() ? GameSupabase.getCurrentPlayer().email : null,
        page_url: location.href,
        game_type: params.get('config') ? 'custom' : (location.pathname.split('/').pop() || 'unknown'),
      }).then(function() {}).catch(function() {});
    } catch(e) {}

    // 双方奖励通知
    showInviteToast(inviter);
  }

  function showInviteToast(inviter) {
    var el = document.createElement('div');
    el.style.cssText = [
      'position:fixed;bottom:100px;left:50%;transform:translateX(-50%);z-index:9999;',
      'background:rgba(26,10,46,0.95);border:1px solid rgba(245,200,66,0.4);',
      'border-radius:16px;padding:12px 20px;font-size:13px;color:#F0EAF8;',
      'font-family:-apple-system,"PingFang SC",sans-serif;',
      'box-shadow:0 4px 20px rgba(0,0,0,0.5);text-align:center;',
    ].join('');
    el.textContent = '🎁 通过好友邀请链接进入，双方各得 50 金币！';
    document.body.appendChild(el);
    setTimeout(function() { el.style.opacity = '0'; el.style.transition = 'opacity 0.5s'; }, 3000);
    setTimeout(function() { el.remove(); }, 3500);
  }

  /** 生成带邀请码的链接 */
  function buildInviteUrl(baseUrl) {
    var player = GameSupabase.getCurrentPlayer();
    if (!player) return baseUrl;
    var sep = baseUrl.indexOf('?') === -1 ? '?' : '&';
    return baseUrl + sep + 'invite=' + player.id;
  }

  /** 获取当前用户的邀请统计 */
  async function getStats() {
    var player = GameSupabase.getCurrentPlayer();
    if (!player) return { total: 0, rewarded: 0 };
    try {
      var r = await GHSupabase.from('invites').select('id', { count: 'exact', head: true }).eq('inviter_id', player.id);
      return { total: r.count || 0, rewarded: Math.floor((r.count || 0) / 1) * 50 };
    } catch(e) { return { total: 0, rewarded: 0 }; }
  }

  // 自动追踪
  if (document.readyState !== 'loading') {
    trackInvite();
  } else {
    document.addEventListener('DOMContentLoaded', trackInvite);
  }

  return { trackInvite, buildInviteUrl, getStats };
})();
