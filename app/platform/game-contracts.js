// 游戏平台的纯协议层：配置可分享，运行时状态与结果独立存在。
(function (root, factory) {
  var api = factory();
  root.GameHubContracts = api;
  if (typeof module === 'object' && module.exports) module.exports = api;
}(typeof window !== 'undefined' ? window : globalThis, function () {
  function createEnvelope(type, version, payload) {
    if (!type) throw new Error('配置缺少游戏类型');
    if (!Number.isInteger(version) || version < 1) throw new Error('配置版本无效');
    return { type: type, version: version, payload: payload };
  }

  function normalizeEnvelope(input, manifest) {
    if (!manifest || !manifest.type) throw new Error('游戏定义无效');
    if (!input || input.type !== manifest.type) throw new Error('配置类型不匹配');

    var payload = input.payload;
    var version = Number(input.version || 1);
    if (!Number.isInteger(version) || version < 1) throw new Error('配置版本无效');
    if (version > manifest.configVersion) throw new Error('配置版本高于当前游戏版本');

    while (version < manifest.configVersion) {
      if (typeof manifest.migrate !== 'function') throw new Error('配置无法迁移');
      payload = manifest.migrate(version, payload);
      version += 1;
    }

    if (typeof manifest.validate !== 'function') throw new Error('游戏定义缺少配置校验');
    return createEnvelope(manifest.type, manifest.configVersion, manifest.validate(payload));
  }

  function createSession(configId) {
    if (!configId) throw new Error('会话缺少配置标识');
    return { configId: configId, status: 'active', outcomes: [], startedAt: Date.now() };
  }

  return {
    createEnvelope: createEnvelope,
    normalizeEnvelope: normalizeEnvelope,
    createSession: createSession,
  };
}));
