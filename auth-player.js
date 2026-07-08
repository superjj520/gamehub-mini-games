/**
 * GameHub 玩家手机号登录组件
 * 依赖：supabase.js（先引入）
 * 效果：检测到未登录时自动弹出手机号验证弹窗，登录后继续游戏
 */

const GameAuth = (() => {
  // Workers 短信接口地址
  const SMS_API = 'https://api.jydigtal.com';
  // 本地开发时改为：const SMS_API = 'http://localhost:8787';

  let loginCallbacks = [];
  let modalEl = null;
  let cooldownTimer = null;
  let cooldownSec = 0;

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

  // ─── 注入弹窗样式 ───
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
        margin-bottom: 12px; font-family: inherit;
        transition: border-color 0.2s;
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
    `;
    document.head.appendChild(style);
  }

  // ─── 渲染第一步：输入手机号 ───
  function renderPhoneStep() {
    modalEl.innerHTML = `
      <div id="gh-auth-box">
        <h2>🎮 验证手机号</h2>
        <p>参与活动需要验证手机号，用于记录您的游戏数据</p>
        <input id="gh-phone" class="gh-auth-input" type="tel" placeholder="请输入手机号" maxlength="11" inputmode="numeric">
        <div id="gh-auth-msg" class="gh-auth-err"></div>
        <button id="gh-send-btn" class="gh-auth-btn">获取验证码</button>
        <button class="gh-auth-link" onclick="document.getElementById('gh-auth-backdrop').remove()">暂时跳过</button>
      </div>
    `;

    document.getElementById('gh-send-btn').addEventListener('click', async () => {
      const phone = document.getElementById('gh-phone').value.trim();
      if (!/^1[3-9]\d{9}$/.test(phone)) {
        showMsg('请输入正确的11位手机号', 'err'); return;
      }
      await sendCode(phone);
    });
  }

  // ─── 发送验证码 ───
  async function sendCode(phone) {
    const btn = document.getElementById('gh-send-btn');
    btn.disabled = true;
    showMsg('发送中…', 'ok');

    try {
      const res = await fetch(`${SMS_API}/api/sms/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone }),
      });
      const data = await res.json();
      if (!data.ok) { showMsg(data.error || '发送失败', 'err'); btn.disabled = false; return; }

      showMsg('验证码已发送 ✓', 'ok');
      renderCodeStep(phone);
      startCooldown();
    } catch (e) {
      showMsg('网络错误，请重试', 'err');
      btn.disabled = false;
    }
  }

  // ─── 渲染第二步：输入验证码 ───
  function renderCodeStep(phone) {
    modalEl.innerHTML = `
      <div id="gh-auth-box">
        <h2>🔐 输入验证码</h2>
        <p>验证码已发送至 ${phone.slice(0,3)}****${phone.slice(-4)}</p>
        <input id="gh-code" class="gh-auth-input" type="text" placeholder="6位验证码" maxlength="6" inputmode="numeric">
        <div id="gh-auth-msg" class="gh-auth-err"></div>
        <button id="gh-verify-btn" class="gh-auth-btn">验证</button>
        <button class="gh-auth-link" id="gh-resend">重新发送 (60s)</button>
      </div>
    `;

    document.getElementById('gh-verify-btn').addEventListener('click', () => {
      verifyCode(phone, document.getElementById('gh-code').value.trim());
    });

    document.getElementById('gh-resend').addEventListener('click', () => {
      if (cooldownSec > 0) return;
      renderPhoneStep();
      document.getElementById('gh-phone').value = phone;
    });

    // 自动聚焦
    setTimeout(() => document.getElementById('gh-code')?.focus(), 100);
  }

  // ─── 验证验证码 ───
  async function verifyCode(phone, code) {
    if (code.length !== 6) { showMsg('请输入6位验证码', 'err'); return; }

    const btn = document.getElementById('gh-verify-btn');
    btn.disabled = true;
    showMsg('验证中…', 'ok');

    try {
      const res = await fetch(`${SMS_API}/api/sms/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone, code }),
      });
      const data = await res.json();

      if (!data.ok) { showMsg(data.error || '验证失败', 'err'); btn.disabled = false; return; }

      // 登录成功
      GameSupabase.setPlayerSession({ token: data.token, id: data.playerId, phone });
      modalEl.remove();
      loginCallbacks.forEach(fn => { try { fn(); } catch(e) {} });
      loginCallbacks = [];

    } catch (e) {
      showMsg('网络错误，请重试', 'err');
      btn.disabled = false;
    }
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
    renderPhoneStep();
  }

  // ─── 自动检测：如果 URL 有 ?cid= 且未登录，自动弹窗 ───
  document.addEventListener('DOMContentLoaded', () => {
    if (GameSupabase.getCampaignId() && !GameSupabase.isLoggedIn()) {
      showModal();
    }
  });

  return { requireLogin, onLoginSuccess };
})();
