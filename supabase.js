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
  const PLAYER_TOKEN_KEY  = 'gh_player_token';
  const PLAYER_ID_KEY     = 'gh_player_id';
  const PLAYER_EMAIL_KEY  = 'gh_player_email';
  const PLAYER_LEGACY_KEY = 'gh_player_phone'; // 旧版兼容

  /** 获取当前登录玩家信息，未登录返回 null */
  function getCurrentPlayer() {
    // 优先读 email key，再读旧 phone key
    let email = localStorage.getItem(PLAYER_EMAIL_KEY);
    if (!email) email = localStorage.getItem(PLAYER_LEGACY_KEY);
    const id = localStorage.getItem(PLAYER_ID_KEY);
    if (!email || !id) return null;
    return { id, phone: email };
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
  function setPlayerSession({ token, id, email }) {
    localStorage.setItem(PLAYER_TOKEN_KEY, token);
    localStorage.setItem(PLAYER_ID_KEY, id);
    localStorage.setItem(PLAYER_EMAIL_KEY, email);
    // 同时写旧 key 以保证已有的 reporter.js 能读到
    localStorage.setItem(PLAYER_LEGACY_KEY, email);
  }

  /** 登出 */
  function logout() {
    localStorage.removeItem(PLAYER_TOKEN_KEY);
    localStorage.removeItem(PLAYER_ID_KEY);
    localStorage.removeItem(PLAYER_EMAIL_KEY);
    localStorage.removeItem(PLAYER_LEGACY_KEY);
  }

  /** 从 URL 参数读取 campaign_id（?cid=xxx） */
  function getCampaignId() {
    return new URLSearchParams(location.search).get('cid') || null;
  }

  return { getCurrentPlayer, isLoggedIn, getPlayerToken, setPlayerSession, logout, getCampaignId };
})();
