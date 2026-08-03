import test from 'node:test';
import assert from 'node:assert/strict';
import configModule from '../../platform/config/config-service.js';
import sessionModule from '../../platform/session/session-service.js';
import shareModule from '../../platform/sharing/share-service.js';
import routeModule from '../../platform/app-shell/routes.js';
const { createConfigService } = configModule;
const { createSessionService } = sessionModule;
const { createShareService } = shareModule;
const { resolvePlatformRoute } = routeModule;

test('配置服务保存版本化信封且分享只暴露引用', async () => {
  const configs = createConfigService();
  const shares = createShareService();
  const saved = await configs.save({ gameType: 'wheel', gameVersion: 1, payload: { secret: '配置内容' } });
  const reference = await shares.publish(saved);
  assert.match(reference, /^cfg_/);
  assert.equal((await shares.resolve(reference)).id, saved.id);
});

test('会话服务只接受完成状态的结果', () => {
  const sessions = createSessionService();
  const session = sessions.start({ configId: 'cfg_1', gameVersion: 1 });
  assert.throws(() => sessions.complete(session.id, null), /结果/);
  assert.equal(sessions.complete(session.id, { result: '奖品' }).status, 'completed');
});

test('平台路由不包含玩法实现路径', () => {
  assert.equal(resolvePlatformRoute('play', 'wheel', 'cfg_1'), 'play-v2.html?game=wheel&config=cfg_1');
  assert.equal(resolvePlatformRoute('create', 'wheel'), 'create-v2.html?game=wheel');
});
