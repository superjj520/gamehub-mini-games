/**
 * GameHub Supabase 客户端
 * 依赖：CDN 引入 @supabase/supabase-js v2
 * 用法：在 supabase.js 后引入 auth-player.js / reporter.js
 */

const SUPABASE_URL  = 'https://ybyputkhtrejnqyblvdc.supabase.co';
const SUPABASE_ANON = 'sb_publishable_I1GxlnNrDMAzn-ip2F0GcQ_Dji4Fsi4';

// 初始化客户端
const GHSupabase = supabase.createClient(SUPABASE_URL, SUPABASE_ANON);

const GameSupabase = (() => {
  const PLAYER_TOKEN_KEY = 'gh_player_token';
  const PLAYER_ID_KEY    = 'gh_player_id';
  const PLAYER_PHONE_KEY = 'gh_player_phone';

  /** 获取当前登录玩家信息，未登录返回 null */
  function getCurrentPlayer() {
    const phone = localStorage.getItem(PLAYER_PHONE_KEY);
    const id    = localStorage.getItem(PLAYER_ID_KEY);
    if (!phone || !id) return null;
    return { id, phone };
  }

  /** 是否已登录 */
  function isLoggedIn() {
    return !!localStorage.getItem(PLAYER_TOKEN_KEY);
  }

  /** 获取 player token */
  function getPlayerToken() {
    return localStorage.getItem(PLAYER_TOKEN_KEY);
  }

  /** 保存登录信息到 localStorage */
  function setPlayerSession({ token, id, phone }) {
    localStorage.setItem(PLAYER_TOKEN_KEY, token);
    localStorage.setItem(PLAYER_ID_KEY, id);
    localStorage.setItem(PLAYER_PHONE_KEY, phone);
  }

  /** 登出 */
  function logout() {
    localStorage.removeItem(PLAYER_TOKEN_KEY);
    localStorage.removeItem(PLAYER_ID_KEY);
    localStorage.removeItem(PLAYER_PHONE_KEY);
  }

  /** 从 URL 参数读取 campaign_id（?cid=xxx） */
  function getCampaignId() {
    return new URLSearchParams(location.search).get('cid') || null;
  }

  return { getCurrentPlayer, isLoggedIn, getPlayerToken, setPlayerSession, logout, getCampaignId };
})();
