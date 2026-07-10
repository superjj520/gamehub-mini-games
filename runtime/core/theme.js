/**
 * 主题渲染器 — 将 Theme Block 配置应用到页面
 * 依赖：无
 */
const ThemeRenderer = (() => {
  const PRESETS = {
    '暗紫': { accent: '#7C3AED', accent2: '#EC4899', bg: '#0D0720', deep: '#1A0A2E', card: 'rgba(124,58,237,0.07)', gold: '#F5C842', text: '#F0EAF8', muted: 'rgba(240,234,248,0.5)' },
    '暗金': { accent: '#D97706', accent2: '#F59E0B', bg: '#0C0A00', deep: '#1A1200', card: 'rgba(251,191,36,0.07)', gold: '#FDE68A', text: '#FEF9EC', muted: 'rgba(254,249,236,0.5)' },
    '暗绿': { accent: '#059669', accent2: '#10B981', bg: '#020F0A', deep: '#041A10', card: 'rgba(16,185,129,0.07)', gold: '#6EE7B7', text: '#ECFDF5', muted: 'rgba(236,253,245,0.5)' },
    '暗蓝': { accent: '#2563EB', accent2: '#3B82F6', bg: '#020817', deep: '#0A1628', card: 'rgba(59,130,246,0.07)', gold: '#93C5FD', text: '#EFF6FF', muted: 'rgba(239,246,255,0.5)' },
    '经典都市': { accent: '#6366F1', accent2: '#EC4899', bg: '#0F0F23', deep: '#1A1A2E', card: 'rgba(99,102,241,0.08)', gold: '#F59E0B', text: '#E2E8F0', muted: 'rgba(226,232,240,0.5)' },
    '赛博朋克': { accent: '#06B6D4', accent2: '#F43F5E', bg: '#0A0A0A', deep: '#111111', card: 'rgba(6,182,212,0.08)', gold: '#FBBF24', text: '#E0F2FE', muted: 'rgba(224,242,254,0.5)' },
    '童话王国': { accent: '#EC4899', accent2: '#8B5CF6', bg: '#1A0A2E', deep: '#2D1B4E', card: 'rgba(236,72,153,0.08)', gold: '#FDE047', text: '#FCE7F3', muted: 'rgba(252,231,243,0.5)' },
  };

  function apply(config = {}) {
    const preset = PRESETS[config.preset] || PRESETS['暗紫'];
    const vars = {
      '--accent':  config.accent  || preset.accent,
      '--accent2': config.accent2 || preset.accent2,
      '--gold':    config.gold    || preset.gold,
      '--bg':      preset.bg,
      '--deep':    preset.deep,
      '--card':    preset.card,
      '--text':    preset.text,
      '--muted':   preset.muted,
      '--border':  'rgba(255,255,255,0.1)',
    };
    const root = document.documentElement;
    for (const [key, value] of Object.entries(vars)) {
      root.style.setProperty(key, value);
    }
    return vars;
  }

  function getPresets() { return Object.keys(PRESETS); }

  return { apply, getPresets, PRESETS };
})();
