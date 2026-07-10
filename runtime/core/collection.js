/**
 * 卡堆/奖池抽选器 — 支持随机均匀、按权重、顺序循环三种模式
 * 依赖：无
 */
const CollectionManager = (() => {
  function draw(config, state = {}) {
    const { drawMode = 'random', cards = [] } = config;
    if (cards.length === 0) return { card: null, state };
    switch (drawMode) {
      case 'random':     return drawRandom(cards, state);
      case 'weighted':   return drawWeighted(cards, state);
      case 'sequential': return drawSequential(cards, state);
      default:           return drawRandom(cards, state);
    }
  }

  function drawRandom(cards, state) {
    const index = Math.floor(Math.random() * cards.length);
    return { card: cards[index], state: { lastIndex: index } };
  }

  function drawWeighted(cards, state) {
    const totalWeight = cards.reduce((sum, c) => sum + (c.weight || 1), 0);
    let r = Math.random() * totalWeight;
    for (let i = 0; i < cards.length; i++) {
      r -= (cards[i].weight || 1);
      if (r <= 0) return { card: cards[i], state: { lastIndex: i } };
    }
    return { card: cards[cards.length - 1], state: { lastIndex: cards.length - 1 } };
  }

  function drawSequential(cards, state) {
    const lastIndex = state.lastIndex != null ? state.lastIndex : -1;
    const nextIndex = (lastIndex + 1) % cards.length;
    return { card: cards[nextIndex], state: { lastIndex: nextIndex } };
  }

  function addCard(config, card) {
    const newCard = { ...card, id: card.id || 'card_' + Math.random().toString(36).slice(2, 8) };
    return { ...config, cards: [...config.cards, newCard] };
  }

  function removeCard(config, cardId) {
    return { ...config, cards: config.cards.filter(c => c.id !== cardId) };
  }

  function updateCard(config, cardId, updates) {
    return { ...config, cards: config.cards.map(c => c.id === cardId ? { ...c, ...updates } : c) };
  }

  return { draw, addCard, removeCard, updateCard };
})();
