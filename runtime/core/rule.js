/**
 * 数值规则引擎 — 管理游戏全局变量（不可变模式）
 * 依赖：无
 */
const RuleEngine = (() => {
  function init(variables = []) {
    const values = {};
    for (const v of variables) {
      values[v.key] = v.value;
    }
    return { values, history: [] };
  }

  function get(state, key) {
    return state.values[key];
  }

  function set(state, key, value) {
    if (state.values[key] === value) return state;
    const newValues = { ...state.values, [key]: value };
    const newHistory = [...state.history, { key, from: state.values[key], to: value, ts: Date.now() }];
    return { values: newValues, history: newHistory.slice(-100) };
  }

  function incr(state, key, delta) {
    const current = state.values[key] || 0;
    return set(state, key, current + delta);
  }

  function getAll(state) {
    return { ...state.values };
  }

  return { init, get, set, incr, getAll };
})();
