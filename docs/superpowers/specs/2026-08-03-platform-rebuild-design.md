# GameHub 平台重建架构设计

**状态：** 已确认，作为后续重建的唯一架构约束。

## 目标

把 GameHub 重建为“轻量互动游戏创作与分享平台”。平台服务玩家和创作者；游戏是相互隔离的玩法模块，而不是散落的独立 HTML 页面或共享全局脚本。

## 非目标

- 不迁移旧页面的 UI 和逻辑实现。
- 不将所有游戏强制套入 `blocks` 配置。
- 不立即切换 React、Next.js 或新的部署体系。
- 不删除旧文件和历史链接，直到相应新游戏完成替换。

## 架构决策

采用原生 JavaScript + Supabase 的模块化单体：一个仓库、一套部署、一套数据库；平台和游戏只通过稳定契约通信。未来若某游戏需要独立部署，可在不改平台接口的前提下拆出。

```text
platform/                 # 不含任何玩法细节
  app-shell/              # 首页、创建页、玩家页、路由和错误边界
  identity/               # 登录、玩家、授权
  config/                 # 草稿、版本、发布、改编、迁移
  session/                # 会话、结果、恢复与幂等
  sharing/                # 短链接、公开性、嵌入
  analytics/              # 参与、完成、复玩、分享
  services/               # 音效、反馈、奖励、排行榜端口
  ui/                     # 设计令牌和通用组件

games/<type>/             # 一个目录代表一个可独立重做和下线的玩法
  manifest.js             # 元数据、版本、能力和加载入口
  config.js               # 默认值、校验、迁移、预设
  engine.js               # 纯玩法规则；先确定结果，再驱动动画
  editor.js               # 该玩法专属创作器，仅编辑内容区域
  player.js               # 该玩法玩家视图，仅渲染和派发操作
  tests/                  # 引擎、配置和端到端契约测试

legacy/                   # 冻结的旧页面、旧适配器与参考素材
tests/                    # 平台、契约、路由和游戏回归测试
```

## 强制依赖规则

```text
app-shell → platform/* → 游戏注册表
games/* → platform/contracts + platform/ui
games/* ─╳→ 其他 games/*
games/* ─╳→ Supabase、页面全局 DOM、排行榜实现
platform/* ─╳→ 任意游戏玩法字段
legacy/* ─╳→ 新平台代码
```

## 核心契约

```js
GameDefinition = {
  type, name, version, capabilities,
  createDefaultConfig, normalizeConfig, migrateConfig,
  createEditor, createEngine, createPlayer
}

GameConfig = { id, gameType, gameVersion, payload, title, ownerId, status, shareSlug, forkFrom }
GameSession = { id, configId, gameVersion, playerId, status, startedAt, completedAt }
GameOutcome = { sessionId, result, score, rewards, occurredAt }
```

`payload` 只由对应游戏模块解释；动画状态、临时 DOM 状态与上次结果不得写入配置。平台通过 `GameContext` 注入配置、会话和服务端口；游戏只返回操作和结果事件。

## 路由与用户流

```text
首页：/index.html
创建：/create.html?game=<type>
游玩：/play.html?game=<type>&config=<shareSlug>
分享：/s/<shareSlug>（静态站重写可用前，兼容到 play 查询参数）
```

玩家：打开分享链接 → 理解规则 → 游玩 → 结果 → 再玩 / 分享 / 改编。

创作者：选择玩法或预设 → 专属编辑器 → 实时试玩 → 保存草稿 → 发布 → 分享与数据。

## 数据与可信边界

`user_configs` 演进为 GameConfig 存储，保留历史 `blocks` 兼容读取；新记录使用 `game_type`、`config_version`、`config_payload`。`play_sessions` 记录 GameSession，结果写入独立的 outcome 字段或表。分享始终引用 Supabase 中的配置；URL 不存可信奖品、隐私信息或会话状态。

客户端随机仅适用于娱乐；涉及真实奖品、排名或竞争的结果由服务端生成或验证。所有游戏通过平台分析服务上报完成、复玩、分享和改编，不直接操作数据表。

## 迁移策略

1. 建立平台骨架、契约测试和注册表，不迁移任何旧玩法。
2. 将现有页面、适配器和 V0 导出归入 `legacy/` 清单，禁止新链接指向它们。
3. 用全新实现重做大转盘，验证创建—发布—游玩—改编—统计闭环。
4. 只重做经过产品验证的游戏；其余旧游戏显示“暂未重制”，不迁移无价值代码。
5. 每个新模块完成后才替换相应旧路由；旧链接只做兼容跳转。

## 验收标准

- 新增游戏不修改已有游戏文件或平台玩法代码。
- 删除一个游戏目录不会破坏平台或其他游戏。
- 每个游戏有配置、引擎和注册契约测试。
- 任意发布配置可按版本加载或得到可理解的失败提示。
- 任何结果均经过统一会话和分析边界。
- 平台首页、创建页和游玩页不存在具体游戏判断分支。
