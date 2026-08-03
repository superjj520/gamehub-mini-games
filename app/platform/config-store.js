// 配置存储适配层：新旧数据库记录在这里收敛，游戏模块不直接读取 Supabase 行结构。
(function (root, factory) {
  var api = factory(root.GameHubContracts);
  root.GameHubConfigStore = api;
  if (typeof module === 'object' && module.exports) module.exports = api;
}(typeof window !== 'undefined' ? window : globalThis, function (contracts) {
  if (!contracts && typeof require === 'function') contracts = require('./game-contracts.js');

  function create(options) {
    var registry = options && options.registry;
    if (!registry || typeof registry.get !== 'function') throw new Error('配置存储缺少游戏注册表');

    function normalizeRecord(record) {
      var registration = registry.get(record && record.game_type);
      if (!registration) throw new Error('配置引用了未知游戏类型');
      var envelope = {
        type: record.game_type,
        version: Number(record.config_version || record.version || 1),
        payload: record.config_payload || { blocks: record.blocks || [] },
      };
      return contracts.normalizeEnvelope(envelope, registration.manifest);
    }

    function toWritePayload(envelope) {
      return {
        game_type: envelope.type,
        config_version: envelope.version,
        config_payload: envelope.payload,
        blocks: Array.isArray(envelope.payload && envelope.payload.blocks) ? envelope.payload.blocks : [],
      };
    }

    return { normalizeRecord: normalizeRecord, toWritePayload: toWritePayload };
  }

  return { create: create };
}));
