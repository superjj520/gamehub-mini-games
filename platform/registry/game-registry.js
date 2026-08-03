// 平台只管理游戏模块的注册与实例化，不了解任何玩法细节。
(function (root, factory) {
  var api = factory();
  root.GameHubPlatformRegistry = api;
  if (typeof module === 'object' && module.exports) module.exports = api;
}(typeof window !== 'undefined' ? window : globalThis, function () {
  function create() {
    var definitions = {};
    function register(definition) {
      if (!definition || !definition.type) throw new Error('游戏模块缺少类型');
      if (typeof definition.createEngine !== 'function' || typeof definition.createPlayer !== 'function') throw new Error('游戏模块不完整');
      if (definitions[definition.type]) throw new Error('游戏类型已注册：' + definition.type);
      definitions[definition.type] = definition;
      return definition;
    }
    function get(type) { return definitions[type] || null; }
    function createInstance(type, context) {
      var definition = get(type);
      if (!definition) throw new Error('未知游戏类型：' + type);
      return { definition: definition, engine: definition.createEngine(context), player: definition.createPlayer(context) };
    }
    return { register: register, get: get, createInstance: createInstance };
  }
  return { create: create };
}));
