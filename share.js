/**
 * GameHub 分享裂变模块
 * 功能：生成游戏结果分享卡片（Canvas绘制），支持下载和复制文案
 * 用法：GameShare.show({ game:'大转盘', result:'一等奖', score:100, extra:'恭喜获得iPhone 15！' })
 */

const GameShare = (() => {

  // ─── 分享浮层 DOM ───
  function ensureOverlay() {
    if (document.getElementById('gs-overlay')) return;
    const el = document.createElement('div');
    el.id = 'gs-overlay';
    el.innerHTML = `
      <style>
        #gs-overlay {
          position: fixed; inset: 0; z-index: 9999;
          background: rgba(0,0,0,0.85);
          display: flex; align-items: center; justify-content: center;
          backdrop-filter: blur(8px);
          opacity: 0; pointer-events: none;
          transition: opacity 0.3s;
        }
        #gs-overlay.show { opacity: 1; pointer-events: all; }
        #gs-box {
          background: #1A0A2E;
          border: 1px solid rgba(255,255,255,0.12);
          border-radius: 20px;
          padding: 24px;
          width: min(380px, 90vw);
          display: flex; flex-direction: column; align-items: center; gap: 16px;
          transform: scale(0.9);
          transition: transform 0.3s;
        }
        #gs-overlay.show #gs-box { transform: scale(1); }
        #gs-title {
          font-size: 16px; font-weight: 700; color: #F0EAF8;
          font-family: -apple-system,'PingFang SC','Microsoft YaHei',sans-serif;
        }
        #gs-canvas {
          border-radius: 12px;
          max-width: 100%;
          box-shadow: 0 8px 32px rgba(0,0,0,0.5);
        }
        #gs-actions {
          display: flex; gap: 10px; width: 100%;
        }
        .gs-btn {
          flex: 1; padding: 11px; border-radius: 10px;
          font-size: 14px; font-weight: 600; cursor: pointer;
          border: none; transition: opacity 0.2s;
          font-family: -apple-system,'PingFang SC','Microsoft YaHei',sans-serif;
        }
        .gs-btn:hover { opacity: 0.85; }
        .gs-btn-primary {
          background: linear-gradient(135deg, #7C3AED, #EC4899);
          color: white;
        }
        .gs-btn-secondary {
          background: rgba(255,255,255,0.08);
          border: 1px solid rgba(255,255,255,0.15);
          color: #F0EAF8;
        }
        #gs-copy-hint {
          font-size: 12px; color: rgba(240,234,248,0.5);
          font-family: -apple-system,'PingFang SC',sans-serif;
        }
      </style>
      <div id="gs-box">
        <div id="gs-title">🎉 分享你的成绩</div>
        <canvas id="gs-canvas" width="340" height="200"></canvas>
        <div id="gs-actions">
          <button class="gs-btn gs-btn-primary" id="gs-download">⬇️ 保存图片</button>
          <button class="gs-btn gs-btn-secondary" id="gs-copy">📋 复制文案</button>
        </div>
        <div id="gs-copy-hint">长按图片可直接分享到社交媒体</div>
        <button class="gs-btn gs-btn-secondary" id="gs-close" style="width:100%">关闭</button>
      </div>
    `;
    document.body.appendChild(el);

    document.getElementById('gs-close').onclick = () => hide();
    el.addEventListener('click', (e) => { if (e.target === el) hide(); });
    document.getElementById('gs-download').onclick = download;
    document.getElementById('gs-copy').onclick = copyText;
  }

  let currentData = {};

  // ─── 绘制分享卡片 ───
  function drawCard(data) {
    const canvas = document.getElementById('gs-canvas');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const W = 340, H = 200;
    canvas.width = W;
    canvas.height = H;

    // 背景渐变
    const bg = ctx.createLinearGradient(0, 0, W, H);
    bg.addColorStop(0, '#1A0A2E');
    bg.addColorStop(0.5, '#0D0720');
    bg.addColorStop(1, '#1A0A2E');
    ctx.fillStyle = bg;
    ctx.roundRect(0, 0, W, H, 16);
    ctx.fill();

    // 光晕
    const glow = ctx.createRadialGradient(W/2, H/2, 0, W/2, H/2, 140);
    glow.addColorStop(0, 'rgba(124,58,237,0.25)');
    glow.addColorStop(1, 'transparent');
    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, W, H);

    // 顶部装饰线
    const line = ctx.createLinearGradient(0, 0, W, 0);
    line.addColorStop(0, 'transparent');
    line.addColorStop(0.3, '#7C3AED');
    line.addColorStop(0.7, '#EC4899');
    line.addColorStop(1, 'transparent');
    ctx.strokeStyle = line;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(0, 2); ctx.lineTo(W, 2);
    ctx.stroke();

    // 游戏名
    ctx.font = 'bold 13px -apple-system, PingFang SC, sans-serif';
    ctx.fillStyle = 'rgba(240,234,248,0.5)';
    ctx.textAlign = 'left';
    ctx.fillText(`🎮 ${data.game || '小游戏中台'}`, 20, 30);

    // 品牌标识
    ctx.font = 'bold 11px -apple-system, PingFang SC, sans-serif';
    ctx.fillStyle = '#F5C842';
    ctx.textAlign = 'right';
    ctx.fillText('GameHub', W - 20, 30);

    // 主结果
    const result = data.result || '完成挑战';
    ctx.font = `bold ${result.length > 6 ? 26 : 32}px -apple-system, PingFang SC, sans-serif`;
    const grad = ctx.createLinearGradient(0, 55, W, 95);
    grad.addColorStop(0, '#F5C842');
    grad.addColorStop(1, '#EC4899');
    ctx.fillStyle = grad;
    ctx.textAlign = 'center';
    ctx.fillText(result, W/2, 85);

    // 副标题/描述
    if (data.extra) {
      ctx.font = '14px -apple-system, PingFang SC, sans-serif';
      ctx.fillStyle = 'rgba(240,234,248,0.75)';
      ctx.textAlign = 'center';
      ctx.fillText(data.extra, W/2, 112);
    }

    // 分隔线
    ctx.strokeStyle = 'rgba(255,255,255,0.08)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(20, 128); ctx.lineTo(W-20, 128);
    ctx.stroke();

    // 底部数据
    const stats = [];
    if (data.score != null)  stats.push({ label: '得分', value: String(data.score) });
    if (data.rank  != null)  stats.push({ label: '排名', value: `#${data.rank}` });
    if (data.time  != null)  stats.push({ label: '用时', value: data.time });
    if (data.level != null)  stats.push({ label: '关卡', value: String(data.level) });
    if (stats.length === 0)  stats.push({ label: '挑战', value: '完成' });

    const col = W / Math.max(stats.length, 1);
    stats.slice(0, 4).forEach((s, i) => {
      const x = col * i + col / 2;
      ctx.font = 'bold 18px -apple-system, PingFang SC, sans-serif';
      ctx.fillStyle = '#F5C842';
      ctx.textAlign = 'center';
      ctx.fillText(s.value, x, 158);
      ctx.font = '11px -apple-system, PingFang SC, sans-serif';
      ctx.fillStyle = 'rgba(240,234,248,0.45)';
      ctx.fillText(s.label, x, 174);
    });

    // 底部文字
    ctx.font = '10px -apple-system, PingFang SC, sans-serif';
    ctx.fillStyle = 'rgba(240,234,248,0.3)';
    ctx.textAlign = 'center';
    ctx.fillText('扫码一起玩 → gamehub.io', W/2, 192);
  }

  // ─── 生成分享文案 ───
  function buildText(data) {
    const game = data.game || '小游戏';
    const result = data.result || '完成挑战';
    const extra = data.extra ? `\n${data.extra}` : '';
    const scoreStr = data.score != null ? `\n得分：${data.score}` : '';
    return `我在【${game}】中获得了「${result}」！${extra}${scoreStr}\n\n快来和我一起玩 → GameHub 小游戏中台`;
  }

  function download() {
    const canvas = document.getElementById('gs-canvas');
    if (!canvas) return;
    const a = document.createElement('a');
    a.download = `gamehub-${Date.now()}.png`;
    a.href = canvas.toDataURL('image/png');
    a.click();
  }

  function copyText() {
    const text = buildText(currentData);
    if (navigator.clipboard) {
      navigator.clipboard.writeText(text).then(() => {
        const btn = document.getElementById('gs-copy');
        if (btn) { btn.textContent = '✅ 已复制'; setTimeout(() => btn.textContent = '📋 复制文案', 2000); }
      });
    } else {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed'; ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select(); document.execCommand('copy');
      document.body.removeChild(ta);
      const btn = document.getElementById('gs-copy');
      if (btn) { btn.textContent = '✅ 已复制'; setTimeout(() => btn.textContent = '📋 复制文案', 2000); }
    }
  }

  function hide() {
    const el = document.getElementById('gs-overlay');
    if (el) el.classList.remove('show');
  }

  return {
    /**
     * 展示分享弹窗
     * @param {Object} data
     * @param {string} data.game    游戏名称
     * @param {string} data.result  结果文字（如"一等奖"、"2048"）
     * @param {string} [data.extra] 副标题（如"恭喜获得iPhone 15！"）
     * @param {number} [data.score] 分数
     * @param {number} [data.rank]  排名
     * @param {string} [data.time]  用时（如"1:23"）
     * @param {number} [data.level] 关卡
     */
    show(data) {
      currentData = data || {};
      ensureOverlay();
      drawCard(currentData);
      const el = document.getElementById('gs-overlay');
      if (el) { el.classList.add('show'); }
    },

    hide,

    /** 直接下载卡片（不弹窗） */
    download(data) {
      ensureOverlay();
      drawCard(data || {});
      download();
    },
  };
})();
