(function (root, factory) {
  var api = factory(); root.GameHubBrowserConfigService = api;
  if (typeof module === 'object' && module.exports) module.exports = api;
}(typeof window !== 'undefined' ? window : globalThis, function () {
function createBrowserConfigService(storage) {
  var key = 'gamehub-wheel-configs';
  function read() { try { return JSON.parse(storage.getItem(key) || '{}'); } catch (error) { return {}; } }
  function write(value) { storage.setItem(key, JSON.stringify(value)); }
  async function save(input) { var records = read(), id = input.id || 'cfg_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 7), record = Object.assign({}, input, { id: id, status: input.status || 'draft', updatedAt: Date.now() }); records[id] = record; write(records); return record; }
  async function load(id) { return read()[id] || null; }
  return { save: save, load: load };
}
return { createBrowserConfigService: createBrowserConfigService };
}));
