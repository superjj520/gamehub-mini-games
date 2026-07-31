// 游戏注册表：新游戏和旧游戏适配器统一从这里查找。
(function (root) {
  var registry = new Map();
  root.GameHubGameRegistry = {
    register: function (game) { if (!game || !game.id) throw new Error('注册游戏缺少 id'); if (registry.has(game.id)) throw new Error('游戏已注册：' + game.id); registry.set(game.id, game); return game; },
    get: function (id) { return registry.get(id) || null; },
    list: function () { return Array.from(registry.values()); },
    resolveEntry: function (id) { return root.GameHubCatalog && root.GameHubCatalog.get(id); },
  };
}(window));
