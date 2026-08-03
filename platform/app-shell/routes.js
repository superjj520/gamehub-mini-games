function resolvePlatformRoute(mode, type, reference) {
  if (!type) throw new Error('路由缺少游戏类型');
  var query = 'game=' + encodeURIComponent(type);
  if (mode === 'create') return 'create-v2.html?' + query;
  if (mode === 'play') return 'play-v2.html?' + query + (reference ? '&config=' + encodeURIComponent(reference) : '');
  throw new Error('未知路由模式');
}
module.exports = { resolvePlatformRoute: resolvePlatformRoute };
