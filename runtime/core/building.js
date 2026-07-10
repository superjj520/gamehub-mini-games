/**
 * 建筑系统 — 可建造/升级结构
 * 依赖：无
 */
const BuildingManager = (() => {
  function getTypes(config) {
    return (config.buildings || []).map(b => ({ ...b }));
  }

  function getLevelStats(building, level) {
    level = level || 1;
    return {
      cost: (building.cost || 0) * Math.pow(2, level - 1),
      rentMultiplier: (building.effect?.rent_multiplier || 1) * level,
    };
  }

  return { getTypes, getLevelStats };
})();
