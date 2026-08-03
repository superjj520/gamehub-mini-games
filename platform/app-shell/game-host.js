function createGameHost(registry, services) {
  var active = null;
  function mount(type, container, config) {
    if (active) destroy();
    var context = { config: config, services: services || {} };
    active = registry.createInstance(type, context);
    if (active.player.mount) active.player.mount(container);
    return active;
  }
  function destroy() {
    if (active && active.player.destroy) active.player.destroy();
    active = null;
  }
  return { mount: mount, destroy: destroy, getActive: function () { return active; } };
}
module.exports = { createGameHost: createGameHost };
