# GameHub 架构地基实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 在不切换技术栈、不破坏现有分享链接的前提下，为 GameHub 建立唯一游戏定义、版本化配置和统一配置读取边界，并让大转盘成为第一个可接入该架构的样板。

**架构：** 继续使用原生 JavaScript、静态 HTML 和 Supabase。新增浏览器与 Node 测试均可使用的 UMD 协议模块；游戏注册表只管理玩法定义与路由语义，不再保存互相冲突的 HTML 文件路径。配置以 `{ type, version, payload }` 信封在客户端规范化，并在数据库中逐步以 `config_payload` 保存；旧 `blocks` 保持兼容读取。

**技术栈：** 原生 JavaScript、Node 内置 `node:test`、Supabase、Playwright。

## 全局约束

- 不引入 React、Next.js、TypeScript 或构建工具。
- 旧入口在迁移完成前只能兼容或重定向，不能删除。
- 正式分享继续使用 Supabase `share_slug`；URL Hash 不是正式配置来源。
- 游戏引擎先确定结果，再触发动画；动画状态不得写入分享配置。
- 所有新增生产逻辑必须先有可失败的 Node 测试。
- 所有新增文本、注释和提交信息使用中文。

---

## 文件结构

```text
app/platform/
├── game-contracts.js       # 配置、状态、结果与会话的纯协议
├── game-registry-v2.js     # 唯一游戏类型注册表与路由语义
├── config-store.js         # Supabase 记录与版本化配置之间的适配层
└── manifests/
    └── wheel.js            # 大转盘玩法定义、默认值、校验与迁移

tests/architecture/
├── game-contracts.test.mjs
├── game-registry-v2.test.mjs
├── config-store.test.mjs
└── wheel-manifest.test.mjs

supabase/migrations/
└── 20260803000000_game_config_envelope.sql
```

### Task 1：版本化配置协议

**文件：**
- 创建：`tests/architecture/game-contracts.test.mjs`
- 创建：`app/platform/game-contracts.js`

**接口：**
- 产出：`GameHubContracts.createEnvelope(type, version, payload)`。
- 产出：`GameHubContracts.normalizeEnvelope(input, manifest)`，按 manifest 执行迁移、校验和规范化。
- 产出：`GameHubContracts.createSession(configId)`，只创建运行时会话，不将状态写入配置。

- [ ] **Step 1：写失败测试**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import contracts from '../../app/platform/game-contracts.js';

const manifest = {
  type: 'wheel', configVersion: 2,
  migrate(version, payload) { return version === 1 ? { items: payload.prizes } : payload; },
  validate(payload) { return { items: payload.items.map((item) => ({ name: item.name.trim(), weight: item.weight })) }; },
};

test('规范化旧版本配置并升级到当前版本', () => {
  const result = contracts.normalizeEnvelope({ type: 'wheel', version: 1, payload: { prizes: [{ name: ' 奖品 ', weight: 1 }] } }, manifest);
  assert.deepEqual(result, { type: 'wheel', version: 2, payload: { items: [{ name: '奖品', weight: 1 }] } });
});
```

- [ ] **Step 2：运行失败测试**

运行：`node --test tests/architecture/game-contracts.test.mjs`

预期：失败，原因是 `app/platform/game-contracts.js` 尚不存在。

- [ ] **Step 3：实现最小协议**

```js
(function (root, factory) {
  var api = factory();
  root.GameHubContracts = api;
  if (typeof module === 'object' && module.exports) module.exports = api;
}(typeof window !== 'undefined' ? window : globalThis, function () {
  function createEnvelope(type, version, payload) { return { type: type, version: version, payload: payload }; }
  function normalizeEnvelope(input, manifest) {
    if (!input || input.type !== manifest.type) throw new Error('配置类型不匹配');
    var payload = input.payload;
    var version = Number(input.version || 1);
    while (version < manifest.configVersion) { payload = manifest.migrate(version, payload); version += 1; }
    return createEnvelope(manifest.type, manifest.configVersion, manifest.validate(payload));
  }
  function createSession(configId) { return { configId: configId, status: 'active', outcomes: [], startedAt: Date.now() }; }
  return { createEnvelope: createEnvelope, normalizeEnvelope: normalizeEnvelope, createSession: createSession };
}));
```

- [ ] **Step 4：运行通过测试与语法检查**

运行：`node --test tests/architecture/game-contracts.test.mjs && npm run check`

预期：测试通过，语法检查通过。

### Task 2：唯一游戏注册表

**文件：**
- 创建：`tests/architecture/game-registry-v2.test.mjs`
- 创建：`app/platform/game-registry-v2.js`

**接口：**
- 产出：`GameHubGameRegistryV2.register(registration)`、`get(type)`、`resolveRoute(type, mode, configRef)`。
- `registration` 至少包含 `manifest`、`routes.create`、`routes.play`；不得包含旧页面文件路径。

- [ ] **Step 1：写失败测试**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import registry from '../../app/platform/game-registry-v2.js';

test('游玩路由始终显式携带玩法类型和配置引用', () => {
  registry.clear();
  registry.register({ manifest: { type: 'wheel', configVersion: 1 }, routes: { create: 'builder-v2.html', play: 'play.html' } });
  assert.equal(registry.resolveRoute('wheel', 'play', 'summer-spin'), 'play.html?game=wheel&config=summer-spin');
});
```

- [ ] **Step 2：运行失败测试**

运行：`node --test tests/architecture/game-registry-v2.test.mjs`

预期：失败，原因是注册表不存在。

- [ ] **Step 3：实现最小注册表**

实现 UMD 模块，使用内部对象保存注册项；`register` 验证 `manifest.type`、`manifest.configVersion` 和两条路由；`resolveRoute` 对 `create` 返回 `builder-v2.html?game=wheel`，对 `play` 返回 `play.html?game=wheel&config=引用`，使用 `URLSearchParams` 编码参数。

- [ ] **Step 4：运行通过测试**

运行：`node --test tests/architecture/game-registry-v2.test.mjs && npm run check`

预期：测试和语法检查均通过。

### Task 3：配置存储兼容层与数据库迁移

**文件：**
- 创建：`tests/architecture/config-store.test.mjs`
- 创建：`app/platform/config-store.js`
- 创建：`supabase/migrations/20260803000000_game_config_envelope.sql`

**接口：**
- 产出：`GameHubConfigStore.create({ registry, client })`。
- 产出：`normalizeRecord(record)`，优先读取 `config_payload`，旧记录回退为 `{ blocks: record.blocks }`。
- 产出：`toWritePayload(envelope)`，始终写入 `game_type`、`config_version`、`config_payload`，并同步 `blocks` 以兼容当前 `play.html`。

- [ ] **Step 1：写失败测试**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import storeFactory from '../../app/platform/config-store.js';

test('旧版 blocks 记录会被包装为版本化配置', () => {
  const store = storeFactory.create({ registry: { get() { return { manifest: { type: 'wheel', configVersion: 1, migrate(v, p) { return p; }, validate(p) { return p; } }; } } } });
  assert.deepEqual(store.normalizeRecord({ game_type: 'wheel', version: 1, blocks: [{ id: 'prizes' }] }), { type: 'wheel', version: 1, payload: { blocks: [{ id: 'prizes' }] } });
});
```

- [ ] **Step 2：运行失败测试**

运行：`node --test tests/architecture/config-store.test.mjs`

预期：失败，原因是存储适配层不存在。

- [ ] **Step 3：实现存储适配层和迁移 SQL**

迁移必须添加 `config_version integer not null default 1`、`config_payload jsonb`，并以 `jsonb_build_object('blocks', blocks)` 回填空配置。适配层只负责记录转换；不得让游戏模块直接调用 Supabase。

- [ ] **Step 4：运行通过测试**

运行：`node --test tests/architecture/config-store.test.mjs && npm run check`

预期：测试和语法检查均通过。

### Task 4：大转盘玩法定义

**文件：**
- 创建：`tests/architecture/wheel-manifest.test.mjs`
- 创建：`app/platform/manifests/wheel.js`

**接口：**
- 产出：`GameHubWheelManifest`，包含 `type: 'wheel'`、`configVersion: 1`、`defaults`、`validate`、`migrate`。
- 配置 payload 为 `{ blocks: [{ type: 'collection', config: { cards: [...] } }], theme?: object }`，与 `runtime/games/wheel.js` 的既有读取方式兼容。

- [ ] **Step 1：写失败测试**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import manifest from '../../app/platform/manifests/wheel.js';

test('大转盘拒绝空奖池', () => {
  assert.throws(() => manifest.validate({ blocks: [{ type: 'collection', config: { cards: [] } }] }), /至少需要 2 个奖项/);
});
```

- [ ] **Step 2：运行失败测试**

运行：`node --test tests/architecture/wheel-manifest.test.mjs`

预期：失败，原因是大转盘玩法定义不存在。

- [ ] **Step 3：实现最小玩法定义**

默认配置使用至少 6 个奖项。校验要求奖项数量至少为 2、名称非空且不重复、权重为正数；返回深拷贝后的规范化 payload。`migrate` 的第一版返回输入 payload，保留未来升级入口。

- [ ] **Step 4：运行通过测试**

运行：`node --test tests/architecture/wheel-manifest.test.mjs && npm run check`

预期：测试和语法检查均通过。

### Task 5：架构注册与回归测试

**文件：**
- 修改：`package.json`
- 修改：`scripts/smoke-test.mjs`
- 修改：`docs/gamehub-2-architecture.md`

**接口：**
- `npm run test:architecture` 运行全部 `tests/architecture/*.test.mjs`。
- 冒烟页新增 `play.html?game=wheel`，确保统一游玩入口可加载。
- 架构文档记录旧入口迁移状态：`wheel-page.html`、`wheel.html`、`game-wrapper.html?game=wheel` 均为待兼容入口，不能再作为新链接来源。

- [ ] **Step 1：先写测试脚本并确认失败**

在 `package.json` 添加：

```json
"test:architecture": "node --test tests/architecture/*.test.mjs"
```

运行：`npm run test:architecture`

预期：在前四个任务完成前失败；完成后通过。

- [ ] **Step 2：更新冒烟测试和架构文档**

将 `play.html?game=wheel` 纳入浏览器冒烟范围；文档明确“新入口必须由 V2 注册表解析，旧入口只做兼容”。

- [ ] **Step 3：完整验证**

运行：`npm run test:architecture && npm run check && npm run test:smoke`

预期：三项全部通过。

- [ ] **Step 4：提交**

```bash
git add app/platform tests/architecture supabase/migrations package.json scripts/smoke-test.mjs docs/gamehub-2-architecture.md docs/superpowers/plans/2026-08-03-gamehub-architecture-foundation.md
git commit -m "建立游戏配置与注册架构地基"
```

## 自检结果

- 产品双路径：由统一 `create` / `play` 路由语义承接。
- 游戏专属编辑器：注册表只定义入口，未强制通用表单。
- 配置兼容：旧 `blocks` 可回退读取，新配置可版本化迁移。
- 分享与数据：继续以 Supabase `share_slug` 为正式来源。
- 大转盘优先：仅建立 manifest 与校验，不提前重写所有游戏。
- 旧入口：本阶段不删除；下一阶段在大转盘产品重构时做兼容跳转。
