/**
 * GameHub 全局音效引擎
 * 纯 Web Audio API 合成，无需音频文件
 * 用法：GameSound.play('spin') / GameSound.play('win') 等
 */

const GameSound = (() => {
  let ctx = null;
  let enabled = true;
  let volume = 0.6;

  // 懒加载 AudioContext（需用户手势触发）
  function getCtx() {
    if (!ctx) {
      try {
        ctx = new (window.AudioContext || window.webkitAudioContext)();
      } catch (e) {
        return null;
      }
    }
    if (ctx.state === 'suspended') ctx.resume();
    return ctx;
  }

  // 主音量节点
  function getMaster() {
    const c = getCtx();
    if (!c) return null;
    const g = c.createGain();
    g.gain.value = enabled ? volume : 0;
    g.connect(c.destination);
    return { ctx: c, master: g };
  }

  /**
   * 基础振荡器音
   * @param {number} freq 频率 Hz
   * @param {string} type 波形 sine/square/sawtooth/triangle
   * @param {number} duration 时长（秒）
   * @param {number} gainPeak 峰值音量
   * @param {number} startDelay 延迟（秒）
   */
  function tone(freq, type = 'sine', duration = 0.15, gainPeak = 0.3, startDelay = 0) {
    const r = getMaster();
    if (!r) return;
    const { ctx: c, master } = r;
    const osc = c.createOscillator();
    const gain = c.createGain();
    osc.connect(gain);
    gain.connect(master);
    osc.type = type;
    osc.frequency.setValueAtTime(freq, c.currentTime + startDelay);
    gain.gain.setValueAtTime(0, c.currentTime + startDelay);
    gain.gain.linearRampToValueAtTime(gainPeak, c.currentTime + startDelay + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.001, c.currentTime + startDelay + duration);
    osc.start(c.currentTime + startDelay);
    osc.stop(c.currentTime + startDelay + duration + 0.05);
  }

  /**
   * 噪声音效（用于爆炸/打击）
   */
  function noise(duration = 0.2, gainPeak = 0.2, startDelay = 0) {
    const r = getMaster();
    if (!r) return;
    const { ctx: c, master } = r;
    const bufSize = c.sampleRate * duration;
    const buf = c.createBuffer(1, bufSize, c.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;
    const src = c.createBufferSource();
    src.buffer = buf;
    const gain = c.createGain();
    const filter = c.createBiquadFilter();
    filter.type = 'bandpass';
    filter.frequency.value = 1000;
    src.connect(filter);
    filter.connect(gain);
    gain.connect(master);
    gain.gain.setValueAtTime(gainPeak, c.currentTime + startDelay);
    gain.gain.exponentialRampToValueAtTime(0.001, c.currentTime + startDelay + duration);
    src.start(c.currentTime + startDelay);
    src.stop(c.currentTime + startDelay + duration + 0.05);
  }

  // ─── 音效定义 ───
  const sounds = {

    // 点击/按钮
    click() {
      tone(800, 'sine', 0.08, 0.2);
    },

    // 转盘旋转（滴答声，循环调用）
    tick() {
      tone(600, 'triangle', 0.05, 0.15);
    },

    // 旋转加速时的连续滴答
    spin() {
      tone(400, 'square', 0.04, 0.1);
    },

    // 普通中奖
    win() {
      tone(523, 'sine', 0.12, 0.3);        // C5
      tone(659, 'sine', 0.12, 0.3, 0.12);  // E5
      tone(784, 'sine', 0.2,  0.35, 0.24); // G5
    },

    // 大奖（三连音上扬）
    bigWin() {
      tone(523, 'sine', 0.1, 0.35);
      tone(659, 'sine', 0.1, 0.35, 0.1);
      tone(784, 'sine', 0.1, 0.35, 0.2);
      tone(1047,'sine', 0.25, 0.4, 0.3);
    },

    // 谢谢参与（降调）
    lose() {
      tone(400, 'sine', 0.15, 0.2);
      tone(300, 'sine', 0.2,  0.2, 0.15);
    },

    // 刮开/揭示
    scratch() {
      noise(0.15, 0.15);
      tone(300, 'sawtooth', 0.1, 0.1, 0.05);
    },

    // 翻牌
    flip() {
      tone(500, 'triangle', 0.1, 0.2);
      tone(700, 'triangle', 0.1, 0.2, 0.08);
    },

    // 配对成功
    match() {
      tone(600, 'sine', 0.08, 0.25);
      tone(900, 'sine', 0.12, 0.3, 0.08);
    },

    // 消除（消消乐等）
    pop() {
      tone(800, 'sine', 0.06, 0.2);
      tone(1000,'sine', 0.08, 0.2, 0.04);
    },

    // 连消奖励
    combo() {
      [523, 659, 784, 1047].forEach((f, i) => {
        tone(f, 'sine', 0.08, 0.3, i * 0.07);
      });
    },

    // 移动/步进
    move() {
      tone(350, 'triangle', 0.06, 0.12);
    },

    // 吃到东西（贪吃蛇/接金币）
    eat() {
      tone(600, 'sine', 0.06, 0.2);
      tone(900, 'sine', 0.08, 0.2, 0.05);
    },

    // 爆炸/炸弹
    boom() {
      noise(0.3, 0.4);
      tone(80, 'sawtooth', 0.3, 0.3);
    },

    // 游戏结束
    gameOver() {
      [400, 350, 300, 250].forEach((f, i) => {
        tone(f, 'sawtooth', 0.15, 0.25, i * 0.12);
      });
    },

    // 升级/过关
    levelUp() {
      [523, 659, 784, 1047, 1319].forEach((f, i) => {
        tone(f, 'sine', 0.1, 0.3, i * 0.08);
      });
    },

    // 计时/倒计时滴答
    countdown() {
      tone(880, 'square', 0.05, 0.15);
    },

    // 紧张（最后5秒）
    urgentTick() {
      tone(1100, 'square', 0.04, 0.2);
    },

    // 砸蛋/打击
    smash() {
      noise(0.2, 0.35);
      tone(200, 'sawtooth', 0.15, 0.25);
    },

    // 投币/金币
    coin() {
      tone(1047, 'sine', 0.06, 0.25);
      tone(1319, 'sine', 0.1,  0.25, 0.06);
    },

    // 签到/打卡
    checkin() {
      tone(659, 'sine', 0.08, 0.25);
      tone(880, 'sine', 0.12, 0.3, 0.08);
    },

    // 开箱
    openBox() {
      noise(0.1, 0.2);
      tone(400, 'sine', 0.15, 0.25, 0.05);
      tone(600, 'sine', 0.15, 0.3, 0.15);
      tone(800, 'sine', 0.2,  0.35, 0.25);
    },

    // 抽卡（盲盒/扭蛋）
    gacha() {
      tone(300, 'sawtooth', 0.05, 0.15);
      tone(600, 'sine', 0.1, 0.25, 0.08);
      tone(900, 'sine', 0.15, 0.35, 0.18);
    },

    // SSR/传说级稀有
    legendary() {
      [262, 330, 392, 523, 659, 784, 1047].forEach((f, i) => {
        tone(f, 'sine', 0.12, 0.35, i * 0.06);
      });
    },

    // 浇水（成长树）
    water() {
      [800, 700, 600, 500].forEach((f, i) => {
        tone(f, 'sine', 0.08, 0.15, i * 0.05);
      });
    },

    // 能量收集
    collect() {
      tone(700, 'sine', 0.06, 0.2);
      tone(1000,'sine', 0.08, 0.2, 0.05);
    },

    // 倒计时结束/时间到
    timeUp() {
      tone(300, 'square', 0.1, 0.3);
      tone(250, 'square', 0.15, 0.3, 0.1);
      tone(200, 'square', 0.25, 0.35, 0.22);
    },
  };

  return {
    /**
     * 播放音效
     * @param {string} name 音效名称
     */
    play(name) {
      if (!enabled) return;
      if (sounds[name]) {
        try { sounds[name](); } catch (e) { /* 静默失败 */ }
      }
    },

    /** 开关音效 */
    toggle() {
      enabled = !enabled;
      return enabled;
    },

    /** 设置音量 0~1 */
    setVolume(v) {
      volume = Math.max(0, Math.min(1, v));
    },

    /** 是否开启 */
    isEnabled() { return enabled; },

    /** 初始化（在用户首次交互时调用） */
    init() { getCtx(); },

    /** 所有可用音效名称 */
    list: Object.keys(sounds),
  };
})();

// 自动在首次点击时初始化 AudioContext
document.addEventListener('click', () => GameSound.init(), { once: true });
document.addEventListener('touchstart', () => GameSound.init(), { once: true });
