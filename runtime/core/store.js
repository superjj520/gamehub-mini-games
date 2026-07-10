/**
 * 商店交易器
 * 依赖：无
 */
const StoreManager = (() => {
  function getItems(config) {
    return (config.items || []).map(item => ({ ...item }));
  }

  function findItem(config, itemId) {
    return (config.items || []).find(i => i.id === itemId) || null;
  }

  function canBuy(player, item, currencyKey) {
    currencyKey = currencyKey || 'gold';
    return player[currencyKey] >= (item.cost || 0);
  }

  function buy(player, item, currencyKey) {
    currencyKey = currencyKey || 'gold';
    if (!canBuy(player, item, currencyKey)) return player;
    return { ...player, [currencyKey]: player[currencyKey] - (item.cost || 0) };
  }

  return { getItems, findItem, canBuy, buy };
})();
