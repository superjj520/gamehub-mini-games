// 所有新游戏都遵循这个生命周期，旧页面通过适配器逐步迁移。
(function (root) {
  root.GameHubGameContract = function (options) {
    options = options || {};
    if (!options.id || typeof options.mount !== 'function') throw new Error('游戏必须提供 id 和 mount 方法');
    return {
      id: options.id,
      meta: Object.assign({ name: options.id, category: '其他', accent: '#47F1D0' }, options.meta || {}),
      mount: options.mount,
      start: options.start || function () {},
      handleAction: options.handleAction || function () {},
      getState: options.getState || function () { return {}; },
      destroy: options.destroy || function () {},
    };
  };
}(window));
