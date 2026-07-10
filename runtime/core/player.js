/**
 * 玩家管理器 — 创建和操作玩家状态（不可变模式）
 * 依赖：无
 */
const PlayerManager = (() => {
  function createPlayers(config) {
    const { players = [], initialGold = 1500 } = config;
    if (players.length > 0) {
      return players.map(p => ({
        id: p.id || 'p_' + Math.random().toString(36).slice(2, 6),
        name: p.name || '玩家',
        emoji: p.emoji || '🎮',
        isAI: p.isAI || false,
        color: p.color || '#7C3AED',
        position: 0,
        score: 0,
        gold: p.gold || initialGold,
        laps: 0,
        skipNext: false,
        prizes: [],
        properties: [],
      }));
    }
    // 默认创建 2 个玩家
    return [
      { id: 'p1', name: '玩家 A', emoji: '🧑', isAI: false, color: '#7C3AED', position: 0, score: 0, gold: initialGold, laps: 0, skipNext: false, prizes: [], properties: [] },
      { id: 'p2', name: '玩家 B', emoji: '🤖', isAI: true,  color: '#EC4899', position: 0, score: 0, gold: initialGold, laps: 0, skipNext: false, prizes: [], properties: [] },
    ];
  }

  function getCurrent(players, index) { return players[index]; }

  function movePlayer(player, steps, totalCells) {
    const newPos = ((player.position + steps) % totalCells + totalCells) % totalCells;
    const lapsGained = Math.floor((player.position + steps) / totalCells);
    return { ...player, position: newPos, laps: player.laps + lapsGained };
  }

  function addGold(player, amount) {
    return { ...player, gold: Math.max(0, player.gold + amount) };
  }

  function addPrize(player, prize) {
    return { ...player, prizes: [...player.prizes, prize] };
  }

  function addProperty(player, cellIndex) {
    if (player.properties.includes(cellIndex)) return player;
    return { ...player, properties: [...player.properties, cellIndex] };
  }

  return { createPlayers, getCurrent, movePlayer, addGold, addPrize, addProperty };
})();
