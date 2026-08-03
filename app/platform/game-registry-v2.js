// 唯一游戏类型注册表：统一玩法定义和创建、游玩路由语义。
(function (root, factory) {
  var api = factory();
  root.GameHubGameRegistryV2 = api;
  if (typeof module === 'object' && module.exports) module.exports = api;
}(typeof window !== 'undefined' ? window : globalThis, function () {
  var registrations = {};

  function register(registration) {
    var manifest = registration && registration.manifest;
    var routes = registration && registration.routes;
    if (!manifest || !manifest.type || !Number.isInteger(manifest.configVersion)) throw new Error('游戏定义无效');
    if (!routes || !routes.create || !routes.play) throw new Error('游戏路由不完整');
    if (registrations[manifest.type]) throw new Error('游戏类型已注册：' + manifest.type);
    registrations[manifest.type] = registration;
    return registration;
  }

  function get(type) { return registrations[type] || null; }

  function resolveRoute(type, mode, configRef) {
    var registration = get(type);
    if (!registration) throw new Error('未知游戏类型：' + type);
    var base = registration.routes[mode];
    if (!base) throw new Error('未知路由模式：' + mode);
    var params = new URLSearchParams({ game: type });
    if (mode === 'play') {
      if (!configRef) throw new Error('游玩路由缺少配置引用');
      params.set('config', configRef);
    }
    return base + '?' + params.toString();
  }

  function clear() { registrations = {}; }

  return { register: register, get: get, resolveRoute: resolveRoute, clear: clear };
}));
