# GameHub 平台重建实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 建立可独立加载、测试、替换与下线游戏模块的平台骨架，并冻结旧页面作为兼容层。

**架构：** 新平台代码只写入根目录 `platform/` 与 `games/`。`platform/contracts` 定义唯一通信协议；`platform/registry` 只加载游戏模块；`platform/config`、`session`、`sharing` 提供共享服务。旧 `app/`、`runtime/` 和 HTML 页面不再承载新增玩法。

**技术栈：** 原生 JavaScript、Node `node:test`、Supabase、Playwright。

## 任务顺序

### Task 1：建立平台契约与模块目录

**文件：**
- 创建：`platform/contracts/game-definition.js`
- 创建：`platform/contracts/game-context.js`
- 创建：`platform/contracts/game-records.js`
- 创建：`tests/platform/contracts.test.mjs`

- [ ] 先写失败测试：验证游戏定义缺少 `type`、`createEngine` 或 `createPlayer` 时拒绝注册；验证 `GameConfig`、`GameSession`、`GameOutcome` 分离。
- [ ] 运行 `node --test tests/platform/contracts.test.mjs`，确认失败。
- [ ] 实现纯 UMD 契约模块，不引用 DOM、Supabase 或任何游戏。
- [ ] 再次运行测试并执行 `npm run check`。

### Task 2：建立游戏注册表和宿主

**文件：**
- 创建：`platform/registry/game-registry.js`
- 创建：`platform/app-shell/game-host.js`
- 创建：`tests/platform/registry.test.mjs`

- [ ] 先写失败测试：注册表能注册一个游戏，按类型创建独立实例；重复类型和跨模块引用被拒绝。
- [ ] 实现注册表与游戏宿主；宿主只注入 context、挂载、销毁，不包含玩法分支。
- [ ] 验证注册、挂载和销毁的测试通过。

### Task 3：建立配置、会话、分享服务端口

**文件：**
- 创建：`platform/config/config-service.js`
- 创建：`platform/session/session-service.js`
- 创建：`platform/sharing/share-service.js`
- 创建：`tests/platform/services.test.mjs`

- [ ] 先写失败测试：配置服务以版本信封保存；会话服务只接受规范化结果；分享服务只返回配置引用，不泄露 payload。
- [ ] 实现内存适配器和 Supabase 适配器端口，游戏只能调用 context 注入的服务。
- [ ] 执行服务测试、历史配置兼容测试和语法检查。

### Task 4：建立首个独立游戏模块骨架

**文件：**
- 创建：`games/wheel/manifest.js`
- 创建：`games/wheel/config.js`
- 创建：`games/wheel/engine.js`
- 创建：`games/wheel/editor.js`
- 创建：`games/wheel/player.js`
- 创建：`games/wheel/index.js`
- 创建：`games/wheel/tests/*.test.mjs`

- [ ] 先写奖池配置、可注入随机源、结果先定后动画的失败测试。
- [ ] 实现不依赖旧 `wheel.html` 的大转盘模块，只依赖平台契约。
- [ ] 验证该模块可由注册表加载，且删除旧实现时测试仍通过。

### Task 5：旧系统冻结与迁移地图

**文件：**
- 创建：`legacy/README.md`
- 创建：`docs/architecture/game-migration-map.md`
- 修改：`scripts/smoke-test.mjs`

- [ ] 将现有页面、旧适配器、旧运行时按“冻结参考 / 兼容入口 / 候选重做 / 淘汰”分类；不删除文件。
- [ ] 将冒烟测试拆为旧兼容与新平台两组，防止旧页面阻塞新模块测试。
- [ ] 为任何新链接建立断言：不得指向 `legacy` 或旧游戏页。

### Task 6：平台验收与切换准备

**文件：**
- 修改：`package.json`
- 创建：`tests/e2e/platform-wheel-flow.spec.mjs`
- 修改：`docs/superpowers/specs/2026-08-03-platform-rebuild-design.md`

- [ ] 新增 `test:platform`、`test:games`、`test:e2e` 命令。
- [ ] 验证“创建配置 → 发布引用 → 玩家加载 → 产生结果 → 改编配置”完整流程。
- [ ] 通过后才允许创建新的 `create.html` 与新版 `play.html`，旧入口继续兼容。

## 全局验收

运行：`npm run test:platform && npm run test:games && npm run check && npm run test:smoke`

预期：平台测试、游戏测试、语法检查和旧兼容冒烟测试全部通过；任何游戏模块删除后，平台契约测试仍通过。
