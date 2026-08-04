import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { createBrowserConfigService } = require('../../platform/config/browser-config-service.js');
const { createBrowserShareService } = require('../../platform/sharing/browser-share-service.js');
function memoryStorage() { const data = {}; return { getItem: (key) => data[key] || null, setItem: (key, value) => { data[key] = String(value); } }; }
test('发布的大转盘快照可由分享标识读取', async () => {
  const storage = memoryStorage(), configs = createBrowserConfigService(storage), shares = createBrowserShareService(storage);
  const payload = { title: '测试转盘', prizes: [{ name: 'A' }, { name: 'B' }] };
  const draft = await configs.save({ gameType: 'wheel', gameVersion: 1, payload });
  const reference = await shares.publish(draft);
  assert.deepEqual((await shares.resolve(reference)).payload, payload);
});
