(function (root, factory) {
  var api = factory();
  root.GameHubPlatformContracts = api;
  if (typeof module === 'object' && module.exports) module.exports = api;
}(typeof window !== 'undefined' ? window : globalThis, function () {
function createGameDefinition(definition) {
  if (!definition || !definition.type) throw new Error('游戏定义缺少 type');
  if (typeof definition.createEngine !== 'function') throw new Error('游戏定义缺少 createEngine');
  if (typeof definition.createPlayer !== 'function') throw new Error('游戏定义缺少 createPlayer');
  return Object.freeze({
    type: definition.type,
    name: definition.name || definition.type,
    version: Number.isInteger(definition.version) ? definition.version : 1,
    createDefaultConfig: definition.createDefaultConfig || (() => ({})),
    normalizeConfig: definition.normalizeConfig || ((payload) => payload),
    migrateConfig: definition.migrateConfig || ((_version, payload) => payload),
    createEditor: definition.createEditor || null,
    createEngine: definition.createEngine,
    createPlayer: definition.createPlayer,
  });
}

function createGameRecords() {
  function createConfig(input) {
    return Object.freeze({ id: input.id, gameType: input.gameType, gameVersion: input.gameVersion, payload: input.payload, status: input.status || 'draft' });
  }
  function createSession(input) {
    return Object.freeze({ id: input.id, configId: input.configId, gameVersion: input.gameVersion, status: input.status || 'active', startedAt: input.startedAt || Date.now() });
  }
  function createOutcome(input) {
    return Object.freeze({ sessionId: input.sessionId, result: input.result, score: input.score || 0, rewards: input.rewards || [], occurredAt: input.occurredAt || Date.now() });
  }
  return { createConfig: createConfig, createSession: createSession, createOutcome: createOutcome };
}
return { createGameDefinition: createGameDefinition, createGameRecords: createGameRecords };
}));
