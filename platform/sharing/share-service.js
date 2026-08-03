function createShareService() {
  var refs = {};
  async function publish(config) { refs[config.id] = config; return config.id; }
  async function resolve(reference) { return refs[reference] || null; }
  return { publish: publish, resolve: resolve };
}
module.exports = { createShareService: createShareService };
