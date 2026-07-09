/**
 * GameHub 玩家邮箱登录组件
 * 依赖：supabase.js（先引入）
 * 效果：检测到未登录时自动弹出邮箱验证弹窗，登录后继续游戏
 */

const GameAuth = (() => {
  let loginCallbacks = [];
  let modalEl = null;
  let cooldownTimer = null;
  let cooldownSec = 0;
  let floatingBtnEl = null;

  // ─── 注册登录成功回调 ───
  function onLoginSuccess(fn) {
    loginCallbacks.push(fn);
  }

  // ─── 确保登录后执行 callback ───
  function requireLogin(callback) {
    if (GameSupabase.isLoggedIn()) {
      callback();
      return;
    }
    onLoginSuccess(callback);
    showModal();
  }

  // ─── 注入弹窗样式 + 浮动按钮样式 ───
  function injectStyles() {
    if (document.getElementById('gh-auth-style')) return;
    const style = document.createElement('style');
    style.id = 'gh-auth-style';
    style.textContent = `
      #gh-auth-backdrop {
        position: fixed; inset: 0; z-index: 99999;
        background: rgba(13,7,32,0.92); backdrop-filter: blur(8px);
        display: flex; align-items: center; justify-content: center;
      }
      #gh-auth-box {
        background: #1A0A2E; border: 1px solid rgba(124,58,237,0.4);
        border-radius: 20px; padding: 32px 28px; width: min(360px, 92vw);
        text-align: center; font-family: -apple-system,'PingFang SC',sans-serif;
      }
      #gh-auth-box h2 { font-size: 20px; font-weight: 800; color: #F0EAF8; margin-bottom: 6px; }
      #gh-auth-box p  { font-size: 13px; color: rgba(240,234,248,0.55); margin-bottom: 24px; }
      .gh-auth-input {
        width: 100%; padding: 12px 16px; border-radius: 10px;
        background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.15);
        color: #F0EAF8; font-size: 15px; outline: none; box-sizing: border-box;
        margin-bottom: 12px; font-family: inherit; transition: border-color 0.2s;
      }
      .gh-auth-input:focus { border-color: #7C3AED; }
      .gh-auth-btn {
        width: 100%; padding: 13px; border-radius: 10px; border: none;
        background: linear-gradient(135deg, #7C3AED, #EC4899);
        color: white; font-size: 15px; font-weight: 700; cursor: pointer;
        font-family: inherit; margin-bottom: 10px; transition: opacity 0.2s;
      }
      .gh-auth-btn:hover { opacity: 0.88; }
      .gh-auth-btn:disabled { opacity: 0.45; cursor: not-allowed; }
      .gh-auth-link {
        font-size: 12px; color: rgba(240,234,248,0.4); cursor: pointer;
        background: none; border: none; font-family: inherit;
      }
      .gh-auth-link:hover { color: rgba(240,234,248,0.7); }
      .gh-auth-err { font-size: 12px; color: #F87171; margin-bottom: 10px; min-height: 18px; }
      .gh-auth-ok  { font-size: 12px; color: #34D399; margin-bottom: 10px; }
      /* 浮动登录按钮 */
      #gh-login-float {
        position: fixed; bottom: 24px; right: 24px; z-index: 9999;
        width: 48px; height: 48px; border-radius: 50%;
        background: linear-gradient(135deg, #7C3AED, #EC4899);
        border: none; color: white; font-size: 20px; cursor: pointer;
        box-shadow: 0 4px 16px rgba(124,58,237,0.4);
        display: flex; align-items: center; justify-content: center;
        transition: transform 0.2s, opacity 0.3s;
      }
      #gh-login-float:hover { transform: scale(1.1); }
      /* 游戏结束后登录提示 */
      #gh-prompt {
        position: fixed; bottom: 80px; left: 50%; transform: translateX(-50%);
        background: rgba(26,10,46,0.95); border: 1px solid rgba(245,200,66,0.4);
        border-radius: 16px; padding: 16px 20px; z-index: 9998;
        text-align: center; font-family: -apple-system,'PingFang SC',sans-serif;
        box-shadow: 0 4px 20px rgba(0,0,0,0.5);
      }
      #gh-prompt p { font-size: 13px; color: #F0EAF8; margin-bottom: 8px; }
      #gh-prompt button {
        padding: 8px 20px; border-radius: 8px; border: none;
        background: linear-gradient(135deg, #7C3AED, #EC4899);
        color: white; font-size: 13px; font-weight: 600; cursor: pointer;
        font-family: inherit; margin: 0 4px;
      }
      #gh-prompt .gh-prompt-skip {
        background: transparent; border: 1px solid rgba(255,255,255,0.15);
        color: rgba(240,234,248,0.5);
      }
    `;
    document.head.appendChild(style);
  }

  // ─── 浮动登录按钮 ───
  function showFloatingBtn() {
    if (GameSupabase.isLoggedIn() || document.getElementById('gh-login-float')) return;
    floatingBtnEl = document.createElement('button');
    floatingBtnEl.id = 'gh-login-float';
    floatingBtnEl.textContent = '🔑';
    floatingBtnEl.title = '登录以记录游戏数据';
    floatingBtnEl.onclick = () => { showModal(); hideFloatingBtn(); };
    document.body.appendChild(floatingBtnEl);
  }

  function hideFloatingBtn() {
    if (floatingBtnEl) { floatingBtnEl.remove(); floatingBtnEl = null; }
  }

  // ─── 游戏结束后提示登录 ───
  function promptAfterGame() {
    if (GameSupabase.isLoggedIn()) return;
    // 移除旧提示
    document.getElementById('gh-prompt')?.remove();
    const el = document.createElement('div');
    el.id = 'gh-prompt';
    el.innerHTML = `
      <p>登录后可记录您的游戏成绩</p>
      <button onclick="this.closest('#gh-prompt').remove();GameAuth._showLogin()">立即登录</button>
      <button class="gh-prompt-skip" onclick="this.closest('#gh-prompt').remove()">暂不登录</button>
    `;
    document.body.appendChild(el);
    // 5秒后自动消失
    setTimeout(() => el?.remove(), 5000);
  }

  // ─── 渲染第一步：输入邮箱 ───
  function renderEmailStep() {
    modalEl.innerHTML = `
      <div id="gh-auth-box">
        <h2>🎮 验证邮箱</h2>
        <p>参与活动需要验证邮箱，用于记录您的游戏数据</p>
        <input id="gh-email" class="gh-auth-input" type="email" placeholder="请输入邮箱" autocomplete="email">
        <div id="gh-auth-msg" class="gh-auth-err"></div>
        <button id="gh-send-btn" class="gh-auth-btn">获取验证码</button>
        <button class="gh-auth-link" onclick="document.getElementById('gh-auth-backdrop').remove();GameAuth._onSkip();">暂时跳过</button>
      </div>
    `;

    document.getElementById('gh-send-btn').addEventListener('click', async () => {
      const email = document.getElementById('gh-email').value.trim();
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        showMsg('请输入正确的邮箱地址', 'err'); return;
      }
      await sendCode(email);
    });

    document.getElementById('gh-email').addEventListener('keydown', e => {
      if (e.key === 'Enter') document.getElementById('gh-send-btn').click();
    });
  }

  // ─── 发送验证码（Supabase OTP）───
  async function sendCode(email) {
    const btn = document.getElementById('gh-send-btn');
    btn.disabled = true;
    showMsg('发送中…', 'ok');

    const { error } = await GHSupabase.auth.signInWithOtp({
      email,
      options: { shouldCreateUser: true }
    });

    if (error) {
      showMsg(error.message || '发送失败，请重试', 'err');
      btn.disabled = false;
      return;
    }

    showMsg('验证码已发送，请查收邮件 ✓', 'ok');
    renderCodeStep(email);
    startCooldown();
  }

  // ─── 渲染第二步：输入验证码 ───
  function renderCodeStep(email) {
    modalEl.innerHTML = `
      <div id="gh-auth-box">
        <h2>🔐 输入验证码</h2>
        <p>验证码已发送至 ${email}</p>
        <input id="gh-code" class="gh-auth-input" type="text" placeholder="6位验证码" maxlength="6" inputmode="numeric">
        <div id="gh-auth-msg" class="gh-auth-err"></div>
        <button id="gh-verify-btn" class="gh-auth-btn">验证</button>
        <button class="gh-auth-link" id="gh-resend">重新发送 (60s)</button>
      </div>
    `;

    document.getElementById('gh-verify-btn').addEventListener('click', () => {
      verifyCode(email, document.getElementById('gh-code').value.trim());
    });

    document.getElementById('gh-code').addEventListener('keydown', e => {
      if (e.key === 'Enter') document.getElementById('gh-verify-btn').click();
    });

    document.getElementById('gh-resend').addEventListener('click', () => {
      if (cooldownSec > 0) return;
      renderEmailStep();
      setTimeout(() => { document.getElementById('gh-email').value = email; }, 50);
    });

    setTimeout(() => document.getElementById('gh-code')?.focus(), 100);
  }

  // ─── 验证验证码 ───
  async function verifyCode(email, token) {
    if (token.length !== 6) { showMsg('请输入6位验证码', 'err'); return; }

    const btn = document.getElementById('gh-verify-btn');
    btn.disabled = true;
    showMsg('验证中…', 'ok');

    const { data, error } = await GHSupabase.auth.verifyOtp({
      email,
      token,
      type: 'email'
    });

    if (error) {
      showMsg(error.message || '验证码错误', 'err');
      btn.disabled = false;
      return;
    }

    const userId = data.user?.id;
    if (userId) {
      await GHSupabase.from('players').upsert({ email }, { onConflict: 'email' });
      const { data: player } = await GHSupabase.from('players').select('id').eq('email', email).single();
      GameSupabase.setPlayerSession({ token: data.session?.access_token || userId, id: player?.id || userId, email });
    }

    modalEl.remove();
    hideFloatingBtn();
    loginCallbacks.forEach(fn => { try { fn(); } catch(e) {} });
    loginCallbacks = [];
  }

  // ─── 工具 ───
  function showMsg(text, type) {
    const el = document.getElementById('gh-auth-msg');
    if (!el) return;
    el.className = type === 'err' ? 'gh-auth-err' : 'gh-auth-ok';
    el.textContent = text;
  }

  function startCooldown() {
    cooldownSec = 60;
    clearInterval(cooldownTimer);
    cooldownTimer = setInterval(() => {
      cooldownSec--;
      const btn = document.getElementById('gh-resend');
      if (btn) btn.textContent = cooldownSec > 0 ? `重新发送 (${cooldownSec}s)` : '重新发送';
      if (cooldownSec <= 0) clearInterval(cooldownTimer);
    }, 1000);
  }

  function showModal() {
    injectStyles();
    if (document.getElementById('gh-auth-backdrop')) return;
    modalEl = document.createElement('div');
    modalEl.id = 'gh-auth-backdrop';
    document.body.appendChild(modalEl);
    renderEmailStep();
    setTimeout(() => document.getElementById('gh-email')?.focus(), 200);
  }

  // ─── 暴露给 HTML onclick 的方法 ───
  function _onSkip() {
    hideFloatingBtn();
    showFloatingBtn();
  }

  function _showLogin() {
    showModal();
    hideFloatingBtn();
  }

  // ─── 自动检测：如果 URL 有 ?cid= 且未登录，自动弹窗 ───
  document.addEventListener('DOMContentLoaded', () => {
    if (GameSupabase.getCampaignId() && !GameSupabase.isLoggedIn()) {
      showModal();
    }
  });

  return { requireLogin, onLoginSuccess, promptAfterGame, _showLogin, _onSkip };
})();
