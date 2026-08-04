(function (root, factory) {
  var api = factory(); root.GameHubBrowserShareService = api;
  if (typeof module === 'object' && module.exports) module.exports = api;
}(typeof window !== 'undefined' ? window : globalThis, function () {
function createBrowserShareService(storage) {
  var key = 'gamehub-wheel-shares';
  function read() { try { return JSON.parse(storage.getItem(key) || '{}'); } catch (error) { return {}; } }
  function write(value) { storage.setItem(key, JSON.stringify(value)); }
  async function publish(config) { var refs = read(), reference = config.shareReference || 'share_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 7); refs[reference] = JSON.parse(JSON.stringify(Object.assign({}, config, { status: 'published', shareReference: reference }))); write(refs); return reference; }
  async function resolve(reference) { return read()[reference] || null; }
  return { publish: publish, resolve: resolve };
}
return { createBrowserShareService: createBrowserShareService };
}));
