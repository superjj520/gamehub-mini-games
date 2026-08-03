function createSessionService() {
  var sessions = {}, count = 0;
  function start(input) { var session = { id: 'ses_' + (++count), configId: input.configId, gameVersion: input.gameVersion, status: 'active' }; sessions[session.id] = session; return session; }
  function complete(id, outcome) { if (!outcome || !outcome.result) throw new Error('结果不能为空'); var session = sessions[id]; if (!session) throw new Error('会话不存在'); session.status = 'completed'; session.outcome = outcome; return session; }
  return { start: start, complete: complete };
}
module.exports = { createSessionService: createSessionService };
