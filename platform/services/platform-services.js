// 游戏只能通过这里获得平台能力；默认实现不产生外部副作用。
function createPlatformServices(overrides) {
  var base = {
    identity: { getCurrentPlayer: async function () { return null; } },
    analytics: { track: async function () {} },
    feedback: { notify: function () {} },
    leaderboard: { submit: async function () {}, list: async function () { return []; } },
  };
  return Object.assign(base, overrides || {});
}
module.exports = { createPlatformServices: createPlatformServices };
