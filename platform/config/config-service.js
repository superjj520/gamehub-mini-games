function createConfigService() {
  var records = {}, count = 0;
  async function save(input) {
    var id = input.id || 'cfg_' + (++count);
    var record = { id: id, gameType: input.gameType, gameVersion: input.gameVersion, payload: input.payload, status: input.status || 'draft' };
    records[id] = record;
    return record;
  }
  async function load(id) { return records[id] || null; }
  return { save: save, load: load };
}
module.exports = { createConfigService: createConfigService };
