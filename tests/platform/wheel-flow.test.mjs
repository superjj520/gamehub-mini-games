import test from 'node:test';
import assert from 'node:assert/strict';
import registryFactory from '../../platform/registry/game-registry.js';
import { createConfigService } from '../../platform/config/config-service.js';
import { createSessionService } from '../../platform/session/session-service.js';
import { createShareService } from '../../platform/sharing/share-service.js';
import wheel from '../../games/wheel/index.js';

test('平台完成大转盘配置、发布、加载和结算', async () => {
  const registry = registryFactory.create();
  registry.register(wheel);
  const configs = createConfigService();
  const shares = createShareService();
  const sessions = createSessionService();
  const config = await configs.save({ gameType: 'wheel', gameVersion: wheel.version, payload: wheel.normalizeConfig({ prizes: [{ name: '奖品', weight: 1 }, { name: '谢谢参与', weight: 1 }] }) });
  const reference = await shares.publish(config);
  const loaded = await shares.resolve(reference);
  const session = sessions.start({ configId: loaded.id, gameVersion: loaded.gameVersion });
  const instance = registry.createInstance('wheel', { config: loaded.payload });
  const outcome = instance.engine.spin({ next: () => 0 }).complete();
  assert.equal(sessions.complete(session.id, { result: outcome.prize.name }).status, 'completed');
});
