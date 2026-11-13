# GameHub 全仓架构评审（深度分析）

- 评审对象：`gamehub-mini-games`，HEAD `e816c37`（工作区有未提交改动）
- 评审日期：2026-10-28
- 方法：全量读源码 + 静态度量 + 实跑现有检查链；证据统一为 `路径:行号`
- 实跑环境：Node v22.23.1

## 0. 实跑记录

| 命令 | 结果 |
|---|---|
| `node scripts/check-project.mjs` | 通过，277 文件（只覆盖 `.js/.mjs/.cjs`） |
| `npm run test:architecture / test:platform / test:games` | 8 / 8 / 6 通过 |
| `npm run check:boundaries` | 通过（`平台边界检查通过`） |
| `npm run test:smoke` | **本地跑不起来**：`browserType.launch: Executable doesn't exist ... chrome-headless-shell`（`scripts/smoke-test.mjs:26`） |
| 补充检查：HTML 内联脚本语法 | 76 个 HTML / 72 个内联块 / 1,194,088 字节 → **语法错误 0** |
| 补充检查：本地资源引用 | **1 处 404**：`personality-test.html:567` → `2048.html`（实际文件 `game-2048.html`） |

## 1. 结论速览

| # | 判断 | 证据 |
|---|---|---|
| 1 | 仓库同存 **4 代**平台抽象，代码量 95% 仍在旧 HTML 里 | 根目录 HTML 89,292 行 vs `app/` 646 + `games/` 240 + `platform/` 150 |
| 2 | 新版「发布→分享→游玩」闭环**只写 localStorage**，跨设备必失效 | `platform/sharing/browser-share-service.js:9-10` |
| 3 | 所有分数上报打向 **SQL 里不存在的 `leaderboard` 表** | `supabase.js:56`；全仓 5 个 SQL 无该表 |
| 4 | 两个 Edge Function 等于公网无鉴权接口 | `create-client-user/index.ts:4-22`、`ai-config/index.ts:2` |
| 5 | 无 Godot 工程；`GameHubBridge` 对端是 Next.js 静态导出 | `find project.godot` 空；`runtime/bridge.js:6` → `wheelcut/` 为 `_next` 产物 |
| 6 | 大厅被未提交的 `index.html` 整体删除，且链到未跟踪文件 | `git diff index.html`（-160 行）；`index.html:21` → `player-history.html`（untracked） |

## 2. 全仓代码地图

### 2.1 目录职责

| 路径 | 职责 | 规模 | 状态 |
|---|---|---|---|
| `*.html`（根目录） | 单文件小游戏 + 大厅 + 后台 + 文档页 | 76 个 HTML，89,292 行；内联 JS 1.19 MB | 主体，可运行 |
| `runtime/` | 第一代 block 引擎：`engine.js`、`block-registry.js`、`core/`、`effects/`、`games/*`、`bridge.js` | 4,512 行 | 仅 `play.html` 使用 |
| `app/games/` | 第二代：45 个 `*-adapter.js` + `game-contract.js` + `game-registry.js` | ~500 行 | 55 个页面加载 |
| `app/platform/` | 第二代半：`game-registry-v2.js`、`game-contracts.js`、`config-store.js`、`bootstrap.js` | ~120 行 | `play.html`、`builder-v2.html` |
| `app/shell/`、`app/data/`、`app/ui/` | 外壳、目录、反馈 | ~200 行 | 与 `app/games` 绑定 |
| `platform/` | 第三代：契约/注册表/配置/会话/分享/路由，工厂式 `create()` | 150 行 | **只被测试引用**；3 个文件是 CommonJS |
| `games/wheel/` | 首个独立游戏模块（config/engine/editor/player/manifest） | 240 行 | `create-v2`/`play-v2` 使用 |
| `wheelcut/` | Next.js/React 静态导出（`_next/`、`__next.*.txt`） | 948 KB | 被 bridge 当 Godot 端引用 |
| `supabase/functions/` | 2 个 Edge Function（Deno） | 218 行 | 已部署（注释含部署命令） |
| `db/`、`supabase/migrations/` | 5 个 SQL（含 2 份重复迁移） | 319 行 | 与线上 schema 漂移 |
| `scripts/` | 检查/测试入口 | 137 行 | CI 只用其中 2 个 |
| `tests/` | `node:test` 单测 | 182 行，22 用例 | 绿，但不覆盖旧页面 |
| `docs/` | 架构/设计/计划 | 6,690 行 | 与实现有偏差 |
| `legacy/` | 只有 `README.md`（5 行） | — | 空壳 |
| `.worktrees/gamehub-rebuild/` | 整仓副本（被 `.gitignore` 忽略） | 同规模 | 污染本地检查 |

### 2.2 入口页面

| 页面 | 角色 | 关键依赖 | 备注 |
|---|---|---|---|
| `index.html:35` | 玩家终端：粘贴分享链接 → `location.assign` | 无外部 JS | 已无游戏列表（未提交改动） |
| `creator.html` | 创作中心静态入口（无脚本） | — | 未跟踪 |
| `create-v2.html:3` | V2 创作者（大转盘） | `games/wheel/*` + `platform/config|sharing/browser-*.js` | 只写 localStorage |
| `play-v2.html:3` | V2 玩家 | 同上 | 只读 localStorage |
| `builder-v2.html:181-185,537-555` | 旧创作者：写 `user_configs`、生成 `share_slug` | `auth-player.js` + `supabase.js` + `app/platform/*` | 唯一真正落库的发布链路 |
| `play.html:200-231` | 旧玩家：`?config=slug` / `?cid=id` 读 `user_configs` | 40+ 脚本 | 唯一可跨设备的分享链路 |
| `game-wrapper.html` | 旧兼容壳 | — | 文档声明「仅保留跳转」 |
| `admin.html:1339-1346` | 管理后台 | **无脚本依赖、无鉴权、数据硬编码** | 公开可访问的静态样机 |
| `admin-you.html:156`、`admin-client.html:122` | 客户/运营控制台 | `signInWithPassword` | 真实 Supabase 登录 |
| `leaderboard.html` / `profile.html` / `shop.html` | 榜单/个人/商店 | `leaderboard.js`（localStorage）+ `user.js` | 与 Supabase 榜并存 |

### 2.3 四代并存

```
gen0  runtime/engine.js  (GameEngine IIFE, blocks 模型)      ← play.html
gen1  app/games/game-contract.js → GameHubGameRegistry Map  ← 55 页 + 45 adapter
gen2  app/platform/game-registry-v2.js → GameHubGameRegistryV2
      app/platform/game-contracts.js  → GameHubContracts
      app/platform/config-store.js    → GameHubConfigStore   ← play.html/builder-v2
gen3  platform/contracts/game-definition.js → GameHubPlatformContracts
      platform/registry/game-registry.js    → GameHubPlatformRegistry (create())  ← 仅 tests
```

**关键冲突**：`app/platform/bootstrap.js:5-8` 路由为 `create:'builder-v2.html', play:'play.html'`，`platform/app-shell/routes.js:4-5` 路由为 `create-v2.html` / `play-v2.html`。两张路由表同时存在，没有单一事实来源。

### 2.4 关键文件

| 文件 | 行数 | 作用 |
|---|---|---|
| `supabase.js` | 114 | Supabase 客户端 + 玩家会话 + 榜/分数写 |
| `runtime/bridge.js` | 190 | `GameHubBridge` postMessage 层 |
| `runtime/engine.js` | 183 | block 分发 + 事件总线（自动广播到 bridge） |
| `runtime/init.js` | 104 | 全局 `GameHub` 健康检查（模块全 `required:false`） |
| `leaderboard.js` | 272 | localStorage 榜 + 动态注入 SDK/supabase/auth/reporter |
| `auth-player.js` | 303 | 邮箱 OTP 登录弹窗 |
| `reporter.js` | 152 | 会话/活动统计上报 + 猴补 leaderboard |
| `games/wheel/config.js` | 88 | `normalizeConfig` / `pickOutcome` / `getOutcomeAngle` |
| `platform/config/browser-config-service.js` | 14 | localStorage 配置仓储 |
| `platform/sharing/browser-share-service.js` | 14 | localStorage 分享引用 |

## 3. 架构与数据流

### 3.1 五条链路

**A. 旧发布（唯一真正落库）**
`builder-v2.html` → `auth-player.js:162-181 signInWithOtp` → `verifyOtp` → `players.upsert({email})` → `user_configs.insert/update`（`builder-v2.html:537-544`）→ `is_published:true, share_slug:slug`（`:555`）。

**B. 旧游玩**
`play.html:213-231`：`?config=slug` → `from('user_configs').select('*').eq('share_slug',slug).single()` → RLS 只放行 `is_published=true`（`20260711000000_gamehub_v2.sql:46-50`）→ `normalizeGameConfig`（`play.html:233-242`）→ `GameEngine.init` → `runtime/games/*`。
**断点**：`play.html:226` 的 `plays_count` 读改写对匿名用户必被 RLS 拒绝，且 `.catch(function(){})` 静默吞掉 → 播放计数事实上永不增长。

**C. 新发布/游玩（V2 大转盘）**
`create-v2.html:3` → `GameHubBrowserConfigService.save` → `localStorage['gamehub-wheel-configs']` → `GameHubBrowserShareService.publish` → `localStorage['gamehub-wheel-shares']`，返回 `share_<base36>` → 链接 `play-v2.html?game=wheel&config=share_xxx` → `shares.resolve(ref)` 只读本机 localStorage（`browser-share-service.js:10`）。
**断点**：跨设备/跨浏览器 100% 失效；`play-v2.html:3` 自己写了兜底文案「它可能已失效，或不在当前浏览器的数据中」。计划文档要求的 Supabase 适配器（`docs/superpowers/plans/2026-08-03-platform-rebuild-implementation.md:45-46`）从未实现。

**D. 分数与结果**
`GameReporter.report`（`reporter.js:16-85`）→ `play_sessions.insert`（RLS `with check (true)`，`db/schema.sql:101-102`）→ `campaign_stats` 读改写（`:43-80`）→ `GameSupabase.submitScore`（`supabase.js:51-67`）→ **表 `leaderboard` 不存在** → `safeQuery` 吞错返回 fallback（`supabase.js:21-33`）→ 页面回落 `localStorage['gh_leaderboard']`（`leaderboard.js:36-40`）。
**结论**：`leaderboard` 写入是死代码，榜单数据永远来自本机。

**E. 认证**
`signInWithOtp` → `verifyOtp({type:'email'})` → `players.upsert({email})` → `select id` → `setPlayerSession({token: session?.access_token || userId, ...})`（`auth-player.js:214-244`）。
`token` 可能是 **userId 而非 JWT**，而 `supabase.js:82-84 isLoggedIn()` 只判 `localStorage['gh_player_token']` 是否存在 → 客户端「已登录」状态可被一行 `localStorage.setItem` 伪造。真正写权限仍由 supabase-js 携带的 JWT 决定，RLS 是最后一道闸；但所有「是否本人」的业务判断都建立在可伪造字段上。

### 3.2 认证与权限模型

| 主体 | 凭据 | 能做什么（RLS 事实） | 关键行 |
|---|---|---|---|
| 匿名 | anon publishable key | 读已发布 `user_configs`；**可插任意 `play_sessions`**；**可改 `campaign_stats`** | `schema.sql:101-102`、`:131-135` |
| 玩家（邮箱 OTP） | Supabase JWT | 增删改自己的 `players`、`user_configs`（按 `email=auth.email()`） | `schema.sql:91-95`、`20260711...:52-57` |
| 管理员 | 硬编码邮箱 `superjj199901@gmail.com` | `clients` 全表 | `schema.sql:67-71`、`db/migration-rls-fix.sql:8-12`、`db/migrate.mjs:26-30` |
| service_role | Edge Function 环境变量 | 造 Auth 用户、全表 | `create-client-user/index.ts:12-22` |

三个问题：
1. 管理员身份**写死在 SQL 里的一个邮箱**，换人/加人需改迁移；同一邮箱出现在 3 个文件（`schema.sql:70`、`migration-rls-fix.sql:11`、`migrate.mjs:29`）。
2. `campaign_stats` 策略 `for all using (auth.role()='service_role' or true)`（`schema.sql:131-135`）—— `or true` 让整条策略恒真，等于没开 RLS。
3. `play_sessions` 的 `insert ... with check (true)` 让任何人可伪造任意 `player_id`/`campaign_id` 的流水；`reporter.js:51-58` 又用该表 `count` 推断「今日新玩家」→ 统计可被刷。

### 3.3 配置、常量与泄漏面

| 项 | 位置 | 性质 | 风险 |
|---|---|---|---|
| `SUPABASE_URL` / `SUPABASE_ANON` | `supabase.js:7-8` 硬编码 | publishable key 本身可公开 | 阻断多环境；已进 git 历史与 `.worktrees` 副本 |
| 同一 URL 第二份 | `db/migrate.mjs:9` | 重复常量 | 换项目要改两处 |
| supabase-js CDN | 14 个页面静态引 `@supabase/supabase-js@2`，`leaderboard.js:28` 又动态注入一次 | 双加载路径 | 版本漂移、CSP 无法收紧 |
| `DEEPSEEK_API_KEY` | 仅 `ai-config/index.ts:51` 服务端 | 正确 | — |
| `SUPABASE_SERVICE_ROLE_KEY` | 仅 Edge Function（`create-client-user/index.ts:14`） | 正确 | 客户端 grep 0 命中 |
| `.env.example` | 4 个变量名 | 无值 | 但无任何构建步骤消费它 |

## 4. 代码质量与风险审计

### 4.1 语法与运行时

- **无语法错误**：76 个 HTML 的 72 个内联块（1,194,088 字节）用 `vm.Script` 全量编译，0 失败；112 个 `.js` 经 `node --check` 全过。
- **但现有检查抓不到**：`scripts/check-project.mjs:15` 只收 `\.(js|mjs|cjs)$`，把 1.19 MB 内联 JS 完全排除；`scripts/check-project.mjs:6` 的 `ignored` 只有 `node_modules/.git/wheel-v0-files/wheelcut/_next`，不含 `.worktrees` → 本地实跑报 277 个文件，其中约一半是 `.worktrees/gamehub-rebuild/` 整仓副本。
- **运行时硬伤 1（404）**：`personality-test.html:567` 导航指向 `2048.html`，实际文件名 `game-2048.html`。
- **运行时硬伤 2（冒烟不可复现）**：`scripts/smoke-test.mjs:25-26` 先 `server.listen` 再 `chromium.launch`，launch 抛异常没有 `try/finally` → 进程崩溃且 HTTP server 泄漏。CI 有 `npx playwright install --with-deps chromium`（`.github/workflows/quality.yml:35-36`）所以能过，本地跑不出同样绿灯。

### 4.2 双份事实来源

| 重复项 | 位置 A | 位置 B | 后果 |
|---|---|---|---|
| 平台注册表 | `app/games/game-registry.js:3-9` | `platform/registry/game-registry.js:7-24` | 两套互不相识的注册语义 |
| 配置模型 | `app/platform/manifests/wheel.js:9-40`（`{type,version,payload.blocks}`） | `games/wheel/config.js:21-60`（`{prizes,geometry,theme,title}`） | 同一游戏两套 schema，`config_payload` 与 `blocks` 双写（`config-store.js:24-31`） |
| 分享 | `platform/sharing/browser-share-service.js`（localStorage） | `user_configs.share_slug`（Supabase） | 见 §3.1 C |
| 榜 | `leaderboard.js:36-40`（localStorage） | `supabase.js:40-67`（不存在的表） | 用户看到本机数据 |
| SQL 迁移 | `db/migration-v2.sql` | `supabase/migrations/20260711000000_gamehub_v2.sql` | 同名同内容两份，策略名还不一致 |
| RLS 策略 | `db/schema.sql` | `db/migration-rls-fix.sql` + `db/migrate.mjs:23-78` | 3 份「当前策略」 |
| 路由 | `app/platform/bootstrap.js:5-8` | `platform/app-shell/routes.js:4-5` | 指向不同页面 |
| 桥接协议 | `CONTRACT.md:8-45` | `runtime/bridge.js` | 文档声明 `fetchWheelConfig`/`claimPrize`，`supabase.js:113` 实际导出里没有 |
| 适配器 | 45 个 `app/games/*-adapter.js` | — | 95% 是同一模板的复制粘贴 |

### 4.3 全局变量污染

实测 112 个 JS + 72 个内联块共 **1,701 个顶层声明**，同名高频项：`state:25`、`startGame:23`、`updateStats:21`、`init:19`、`closeModal:16`、`showToast:15`、`canvas:15`、`ctx:14`、`resetGame:13`、`renderHistory:12`。经典脚本 + 顶层声明 → 直接落 `window`。`wheel.html` 一次加载 8 个共享模块，任一重名即静默互相覆盖。

### 4.4 事件与定时器泄漏

| 位置 | 问题 |
|---|---|
| `runtime/engine.js:20-23` | `on()` 只 push，`init()`（`:47-99`）不重置 `_listeners`；`play.html:256-259` 每次 `startGame` 都 `on` 4 个监听且从不 `off` → 同一次 `emit` 触发 N 份回调 |
| `maze.html:1268` / `:1305` | 开始与「恢复」都 `setInterval(tickTimer,1000)`，恢复前不 `clearInterval` → 暂停再继续后倒计时 2×/秒 |
| `claw-machine.html:1058`、`smash-egg.html:756`、`gift-box.html:1038`、`personality-test.html:1082`、`name-generator.html:1342` | `setInterval` 裸调用、无句柄、无清理 |
| `games/wheel/player.js:29-42` | `setTimeout(...,3850)`；`destroy()` 只清 `innerHTML` 不 `clearTimeout` |
| `auth-player.js:254-263` | 验证码冷却 `setInterval`，切换步骤/关弹窗都不清理 |
| 全仓 | 51 处 `setInterval` / 71 处 `clearInterval`（含跨文件引用），配比说明相当比例是裸调用 |

### 4.5 异步与错误处理

- `supabase.js:21-33` `safeQuery` 把任何错误变成 fallback：无法区分「没数据」和「表不存在/被 RLS 拒」。这是 `leaderboard` 缺失能潜伏至今的直接原因。
- `reporter.js:33-36` 上报失败只 `console.warn`；`:235-237` 两步写库中间失败无回滚。
- `create-v2.html:3` 的 `publish`/`saveDraft`：`await configs.save` 与 `shares.publish` 无 try/catch，`localStorage` 配额超限或隐私模式抛错即 unhandled rejection，UI 停在按钮无反馈。
- `play.html:226` `.then(function(){}).catch(function(){})` 明确吞掉播放计数失败。
- `app/services/event-bus.js:3-12` `emit` 无 `try/catch`，一个 handler 抛错中断其余订阅者（`runtime/engine.js:33` 是包了的，两代不一致）。

### 4.6 竞态

| 位置 | 竞态 |
|---|---|
| `reporter.js:43-80` | 先 `select` 再 `update/insert`（读-改-写）→ 并发丢更新 |
| `reporter.js:51-58` | `isNewPlayerToday = todayCount === 1` 依赖刚插入那条，并发/重试误判；该表匿名可插，可被外部刷 |
| `play.html:226` | `plays_count: (config.plays_count||0)+1` 客户端算好再写，两人同开互相覆盖 |
| `leaderboard.js:8-34` | 动态注入 4 个脚本靠回调嵌套定序；`reporter.js:127-151` 回头猴补 `submitAndNotify` → 初始化顺序由网络时序决定 |

### 4.7 XSS / 注入面

| 位置 | 注入源 → 汇 | 可达性 |
|---|---|---|
| `play.html:283`、`:291-294`、`:300` | `config` 的 `score`/`p.name`/`p.emoji`/`log[]` → `innerHTML` | **存储型**：创作者配置进 `user_configs`，任何玩家打开分享链接即执行 |
| `play.html:229` | `e.message` → `innerHTML` | 反射型 |
| `auth-player.js:184-211` | `${email}` 拼进 `innerHTML` | 反射型 |
| `play-v2.html:3` | `config.title` → `innerHTML` | localStorage 注入后可达 |
| `create-v2.html:3` | `message.innerHTML = text + '<a href="'+link+'">'`，`text` 含 `outcome.prize.name` | 配置内容可注入 |
| `player-history.html:5` | `'<a href="'+item.url+'">'` | `index.html:35` 只校验了 `protocol/host/.html`，本页不复校验 → `javascript:` 链接可达 |
| `play.html:270-278` | `innerHTML` 塞 `onclick="MonopolyGame.rollDice()"` | 内联事件处理器，阻断 CSP |

对照：`games/wheel/player.js:11` 与 `editor.js:6` 已有 `escapeHtml`，`app/platform/manifests/wheel.js:23-40` 有 `validate` → **新模块有防线，旧页面全线没有**，缺的不是意识而是统一工具函数。

### 4.8 RLS 与密钥

| 项 | 证据 | 级别 |
|---|---|---|
| `campaign_stats` 策略恒真 | `db/schema.sql:131-135` `or true` | P0 |
| `play_sessions` 匿名可插 | `db/schema.sql:101-102` | P0 |
| `clients` 管理员邮箱硬编码 | `db/schema.sql:67-71` | P1 |
| `user_configs` 属主策略缺 `with check` | `supabase/migrations/20260711000000_gamehub_v2.sql:52-57` | P1 |
| `leaderboard` 表从未创建 | `supabase.js:40,56`；`grep -rn leaderboard --include=*.sql` 空 | P0（功能级） |
| service_role 未泄漏到客户端 | 客户端 grep 0 命中 | 通过 |

### 4.9 路径脆弱点（GitHub Pages 子路径 / 自定义域名）

- `CNAME = games.jydigtal.com` 存在 → 自定义域名走根路径；但项目同时声称兼容 `github.io/<repo>/` 子路径。
- **真正的破点**：`wheelcut/index.html` 的资源是根绝对路径（`/wheelcut/_next/static/chunks/*.js`、`/assets/index-*.js`、`/icon.svg`）。部署到子路径时整站资源 404，而 `runtime/bridge.js:6` 用相对 `src="wheelcut/index.html"` 引它 → 外层能进、内层全白。
- **做对了的**：`leaderboard.js:9-17` 从自身 `<script src>` 反推 `base` 再拼 `supabase.js`，子路径安全。
- `index.html:35` 要求 `url.host === location.host && /\.html$/` → 域名从 `github.io/repo` 切到 `games.jydigtal.com` 后，旧链接全部被拒。
- `platform/app-shell/routes.js:4-5` 返回 `create-v2.html?...` 相对路径 → 从任意子目录页面调用都会拼错。

### 4.10 未提交漂移（威胁「main 必须始终可部署」）

```
M  index.html                (-160 行：大厅被删，改为「粘贴分享链接」终端)
M  scripts/smoke-test.mjs    (页面清单加了 creator.html / player-history.html)
?? creator.html
?? office-escape.html        (202 行新游戏，未进大厅/未进冒烟清单)
?? player-history.html       (index.html:21 已链接)
```

`index.html:21` 已 `href="player-history.html"`，但该文件未跟踪。任何只提交 `index.html` 的提交都会让 main 出死链。同时「大厅」被删意味着 `app/data/game-catalog.js` 与 60+ 个带 `nav-tabs` 的旧页面失去入口 —— 产品级决策藏在未提交改动里。

### 4.11 其他

- `admin.html` 是**静态样机**：`activityData`（`:1339-1346`）6 条硬编码活动，`animateNumber(2847/634/12/1203)`（`:1358-1361`）假统计，无鉴权、无持久化，却挂在公开站点；第 8 行还引了 `runtime/bridge.js`（无用途）。
- `games/wheel/manifest.js:1-5`、`platform/app-shell/routes.js:8`、`platform/config/config-service.js:11`、`platform/sharing/share-service.js:6` 是 CommonJS，浏览器不能直接加载；同目录兄弟文件又都是 UMD。
- `runtime/init.js:14-21` 8 个模块全 `required:false` → 健康检查永远 `ok:true`。

## 5. Godot 与 Web 通信层

### 5.1 现状取证

| 断言 | 事实 |
|---|---|
| 「正逐步加入 Godot 旗舰游戏」 | `find . -name project.godot -o -name '*.gd' -o -name '*.tscn'` → **0 命中** |
| 「GameHubBridge 是 Godot ↔ JS 双向层」 | `runtime/bridge.js:1-7` 自述 Godot，`:6` iframe 指向 `wheelcut/index.html`；而 `wheelcut/` 是 Next.js 静态导出（`_next/`、`__next._tree.txt`、948 KB）。`docs/architecture/game-migration-map.md:5-10` 自己写明 wheelcut「仅视觉参考」 |
| 桥协议 | `CONTRACT.md:8-45` 定义 `game:ready`/`spin:start`/`spin:result`/`prize:claim`/`config:sync`/`auth:session`；实现只覆盖 ready 与通用 `_emit` |

### 5.2 桥接口缺陷（可复现）

```js
runtime/bridge.js:51    _target.postMessage(msg, '*');          // 目标 origin 通配
runtime/bridge.js:143   function _handleMessage(event) { ... }  // 不校验 event.origin / event.source
runtime/bridge.js:173   window.addEventListener('message', _handleMessage, false);
runtime/bridge.js:160   var timer = _pendingTimers[msg.payload.id];  // _pendingTimers 从未写入
runtime/bridge.js:23    var TIMEOUT_MS = 5000;                  // 声明后从未使用
```

任何能向本页 postMessage 的窗口（任意被嵌入的第三方 iframe、`window.opener` 打开的窗口）都可伪造 `game:ready` 触发队列 flush，或伪造 `spin:result` / `prize:claim` 让业务层当真实结果处理。ACK/超时是死代码。

另一侧耦合：`runtime/engine.js:35-38` 把**每一个**内部事件自动 `GameHubBridge.send('engine:'+event, data)`，业务事件与传输层焊死，`targetOrigin='*'` 时等于把配置和规则状态广播给任何嵌入方。

### 5.3 迁移就绪度矩阵

| 候选（`docs/architecture/game-migration-map.md:5-10`） | 现有实现 | 可迁移性 | 阻塞点 |
|---|---|---|---|
| 大转盘 | `games/wheel/*` 独立模块 + 单测 | **高**（唯一就绪） | 配置/分享未接 Supabase；双 schema |
| 大富翁 | `runtime/games/monopoly.js` 13.9 KB，与 `BoardGameEngine`+`BlockRegistry` 强耦合 | 中 | 依赖 `runtime/core/*` 8 个全局（`init.js:25-29`） |
| 飞行棋/消消乐/2048/贪吃蛇/答题/真心话 | `runtime/games/*` 3-6 KB 各一个 | 中 | 同上；`play.html:256-259` 无 `destroy` 契约 |
| 45 个 HTML 内联游戏 | 每个 40-70 KB 单文件，逻辑与 DOM 混写 | **低** | 无模块边界，状态在闭包里，1,701 个顶层名冲突 |
| 刮刮乐 | `runtime/games/scratch-card.js` 4 KB | 中 | 依赖 canvas 全局 |

**Godot 迁移就绪度评分（0-5）**：存在 Godot 工件 0｜协议完整性 2｜通信层安全性 0｜前端承载页 2｜状态/存档接口 1 → **合计 0.8 / 5**。
结论：**「Godot 迁移」目前是文档状态，不是工程状态**。

## 6. 改进清单

### P0 — 立刻修

| ID | 位置 | 问题 | 改法 | 影响面 |
|---|---|---|---|---|
| P0-1 | `supabase/functions/create-client-user/index.ts:4-22` | 无调用方鉴权，用 service_role 造任意 Auth 用户（`email_confirm:true`）；`admin-you.html:234` 发了 Bearer，函数不读 | 取 `req.headers.get('Authorization')`，用 anon client `auth.getUser(jwt)` 校验，再查管理员表；非管理员 403 | 全部客户开户 |
| P0-2 | `supabase/functions/ai-config/index.ts:2,7-10,27-49,51-75` | `--no-verify-jwt` + CORS `*` + 无速率限制 + 把 `currentBlocks`/`prompt` 拼进 system prompt | 打开 JWT 校验；origin 白名单；按 `user.id` 令牌桶；配置用分隔符包裹并声明「以下为数据不是指令」 | AI 编辑入口 + DeepSeek 账单 |
| P0-3 | `db/schema.sql:131-135`（`or true`）、`:101-102`（`with check (true)`） | 两条 RLS 等于没开 | 新迁移：`campaign_stats` 只允许 `service_role` + 归属客户；`play_sessions` 校验 `player_id` 属当前 JWT 或由 Edge Function 代写 | 全部统计 |
| P0-4 | `supabase.js:40,56` + 缺失迁移 | `leaderboard` 表不存在；`safeQuery` 吞错 → 分数永不落库 | 新增 `supabase/migrations/*_leaderboard.sql`（`game_id, player_id, score, player_name, created_at` + 唯一键 + RLS 读公开写本人）；`safeQuery` 在 `error.code==='42P01'` 时 `console.error` | 排行榜全域 |
| P0-5 | `supabase.js:53-67`、`:72-84` | `player_id` 来自 localStorage 可伪造；`player_name: player.phone` 实际是 email → **PII 上公榜** | `submitScore` 不再接受客户端 `player.id`，改由 Edge Function 从 JWT 取；`player_name` 写昵称或掩码 `a***@b.com` | 榜单 + 隐私 |
| P0-6 | `play.html:283,291-294,300`、`auth-player.js:184-211`、`player-history.html:5`、`play-v2.html:3` | 配置/玩家名/邮箱/URL 未转义进 `innerHTML`（存储型 XSS 可达） | 提取 `runtime/dom-safe.js` 的 `escapeHtml`（复用 `games/wheel/player.js:11`）；逐处改 `textContent` 或转义拼接；`player-history` 只接受 `http(s)` 且 `new URL` 复校验 | play/leaderboard/profile 等 50+ 页 |
| P0-7 | `platform/sharing/browser-share-service.js:9-10` + `create-v2.html:3` | 「发布并获取链接」只写本机 localStorage，跨设备 100% 失效 | 实现 `platform/sharing/supabase-share-service.js`（`publish` → `user_configs.insert({is_published:true, share_slug})`，`resolve` → `select ... eq('share_slug')`），`create-v2`/`play-v2` 注入该适配器 | V2 大转盘全链路 |
| P0-8 | `git status`：`index.html`(M) 链 `player-history.html`(??) | 只提交 `index.html` 就让 main 出死链；大厅被删是产品决策 | 把 `creator.html`/`player-history.html`/`office-escape.html` 与两个修改一起提交，或回退 `index.html` 保留大厅 | main 可部署性 |

### P1 — 本迭代内

| ID | 位置 | 问题 | 改法 |
|---|---|---|---|
| P1-1 | `runtime/bridge.js:51,143,160,173,23` | 无 origin/source 校验；ACK 死代码；`TIMEOUT_MS` 未用 | `_post` 用 `new URL(iframe.src).origin` 作 targetOrigin；`_handleMessage` 首行校验 source/origin；写入 `_pendingTimers[id]` 并超时 reject |
| P1-2 | `runtime/engine.js:35-38` | 每个内部事件都广播到 bridge | 改白名单：只转发 `CONTRACT.md:8-45` 的 6 类消息 |
| P1-3 | `runtime/engine.js:20-23,47` + `play.html:256-259` | 监听器永不释放 | `init()` 开头 `_listeners={}`；`play.html` 在 `startGame` 前 `off` 或提供 `reset()` |
| P1-4 | `maze.html:1268/1305`、`claw-machine.html:1058`、`smash-egg.html:756`、`gift-box.html:1038`、`personality-test.html:1082`、`name-generator.html:1342` | 计时器泄漏/重复 tick | `startGame` 前 `clearInterval(handle)`；`visibilitychange` 暂停 |
| P1-5 | `games/wheel/player.js:29-42` | `setTimeout` 未随 `destroy` 清理 | 保存 `_timer`，`destroy()` 里 `clearTimeout` |
| P1-6 | `reporter.js:43-80,51-58`、`play.html:226` | 读改写竞态、非原子「新玩家」判定 | `campaign_stats` 用 RPC `insert ... on conflict do update set plays = plays + 1`；`isNewPlayerToday` 改查 `players.first_seen_at`；`plays_count` 走 RPC 自增 |
| P1-7 | 三套注册表 | `app/games/game-registry.js` vs `app/platform/game-registry-v2.js` vs `platform/registry/game-registry.js` | 冻结 `app/games/*` 为兼容层（只读），新代码只允许 `platform/registry`；`app/platform/*` 标 `@deprecated`，1 个迭代后删除 |
| P1-8 | `app/platform/bootstrap.js:5-8` vs `platform/app-shell/routes.js:4-5` | 两张路由表指向不同页面 | 只留一张（`bootstrap.js` 改成读 `routes.js` 常量） |
| P1-9 | `.github/workflows/quality.yml:29-39` + `scripts/check-project.mjs:6,15` | CI 不跑单测/边界；语法检查漏 1.19 MB 内联 JS；`ignored` 不含 `.worktrees` | CI 加 `test:architecture && test:platform && test:games && check:boundaries`；检查器加内联 `<script>` 抽取 + `vm.Script`；`ignored` 加 `.worktrees`、`wheelcut` |
| P1-10 | `db/schema.sql:67-71`、`db/migration-rls-fix.sql:8-12`、`db/migrate.mjs:26-30` | 管理员邮箱硬编码 3 处 | 建 `admins(user_id)` 表 + `auth.uid() in (select user_id from admins)` |
| P1-11 | `personality-test.html:567` | `2048.html` 404 | 改 `game-2048.html` |
| P1-12 | `admin.html:1339-1361` | 假数据后台公开可达 | 加 `admin-you.html:156` 同款登录门 + 「演示数据」标识，或移出部署目录 |
| P1-13 | `scripts/smoke-test.mjs:25-26` | launch 失败即崩且泄漏 server | `try/finally` 包住 `server.close()`；README 写明 `npx playwright install chromium` |
| P1-14 | `play.html:270-278` | `innerHTML` 塞内联 `onclick` | 改 `addEventListener` + `data-action`，为 CSP 让路 |

### P2 — 结构性

| ID | 位置 | 问题 | 改法 |
|---|---|---|---|
| P2-1 | `games/wheel/manifest.js:1-5`、`platform/{app-shell/routes,config/config-service,sharing/share-service}.js` | CommonJS 混在 UMD 群里 | 统一 UMD 尾巴（`game-definition.js:1-5` 是模板） |
| P2-2 | `CONTRACT.md:53-66` | 文档声明的方法不存在 | 以 `supabase.js:113` 实际导出为准重写契约，或补齐 `fetchWheelConfig`/`claimPrize` |
| P2-3 | 根目录 `user.js`(480)、`achievement.js`(843)、`themes.js`(590)、`share.js`(262)、`sound.js`(294)、`invite.js`(76) | 6 个全局单例；`invite.js` 只被 1 页引用、`reporter.js` 仅由 `leaderboard.js:31` 动态加载 | 按引用数排序，<3 引用的合并或删除；改显式 `window.GameHub.<module>` 命名空间 |
| P2-4 | `.worktrees/gamehub-rebuild/` | 整仓副本污染本地检查（277 vs 112 文件） | 进 `check-project.mjs` 的 `ignored` |
| P2-5 | `db/migration-v2.sql` vs `supabase/migrations/20260711000000_gamehub_v2.sql` | 同内容两份 | 删 `db/` 副本，迁移只留 `supabase/migrations/` |
| P2-6 | `wheelcut/`（948 KB Next.js 导出） | 与 bridge 的「Godot」语义不符 | 改名为 `design-ref/` 或删除；bridge 注释同步修正 |
| P2-7 | `legacy/README.md`(5 行)、`test-monopoly.html`(3.1 KB)、`lucky-draw-upgrades.js`(705 B) | 无引用死文件 | 删除或补 README 说明 |

## 7. 最小可行重构顺序（每步独立可发布）

**Step 1 — 数据面止血（只动 SQL + Edge Function，前端零改动）**
`create-client-user` 鉴权 → 三条 RLS 修正 → 建 `leaderboard` 表 + RPC 自增。
验证：匿名 key `curl` 打 `play_sessions` insert 必须 401/403；`select count(*) from leaderboard` 可执行。

**Step 2 — 打通发布闭环（只动 `platform/sharing/` + 两个 v2 页）**
新增 `supabase-share-service.js`，`browser-*` 降级为 fallback。
验证：`play-v2.html?config=<slug>` 在**另一个浏览器**能打开 —— 唯一能证明 P0-7 修好的测试。

**Step 3 — XSS 收口（只动渲染函数）**
`runtime/dom-safe.js` + 替换 `play.html:283/291-294/300`、`auth-player.js:184-211`、`player-history.html:5`、`play-v2.html:3`。
验证：构造 `title: "<img src=x onerror=alert(1)>"` 的配置，页面只显示字面量、控制台无报错。

**Step 4 — 生命周期与计时器（只动 `engine.js` + 各游戏 start/stop）**
`_listeners` 重置、`setInterval` 句柄化。
验证：`play.html` 连续切换游戏 5 次，监听数不增长；`maze.html` 暂停/继续后倒计时仍为 1 Hz。

**Step 5 — 入口与路由唯一化**
提交未跟踪文件；`bootstrap.js` 复用 `routes.js` 常量；修 `2048.html` 死链。
验证：冒烟全绿 + 链接检查 0 缺失。

**Step 6 — CI 加固**
`check-project.mjs` 加内联脚本检查；workflow 加 4 个 npm script。
验证：故意在 `index.html` 内联块插一个 `})()` → CI 必须红。

## 8. 验证配方（可直接落库）

```bash
# 1. 现有语法检查（只覆盖 .js/.mjs/.cjs）
node scripts/check-project.mjs

# 2. 补充：HTML 内联脚本语法检查（建议固化进 scripts/）
node -e '
const {readdirSync,readFileSync}=require("fs"),vm=require("vm"),p=require("path");
let n=0,b=0,bad=[];(function w(d){for(const e of readdirSync(d,{withFileTypes:true})){
 if(["node_modules",".git","wheelcut",".worktrees"].includes(e.name))continue;
 const f=p.join(d,e.name); if(e.isDirectory()){w(f);continue} if(!f.endsWith(".html"))continue;
 const h=readFileSync(f,"utf8"); for(const m of h.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)){
  if(/\bsrc\s*=/.test(m[1])||!m[2].trim())continue; n++; b+=m[2].length;
  try{new vm.Script(m[2])}catch(err){bad.push(f+": "+err.message)}}}
})(".");console.log(`内联块 ${n} 个 / ${b} 字节 / 错误 ${bad.length}`);bad.forEach(x=>console.log("  "+x));'

# 3. 单测与边界
npm run test:architecture && npm run test:platform && npm run test:games && npm run check:boundaries

# 4. 冒烟（需先装浏览器；CI 已有该步）
npx playwright install chromium && npm run test:smoke
```

冒烟应补 3 条行为断言（而非仅「无 console error」）：
1. `index.html` 粘贴合法同源 `.html` 链接 → 写入 `gamehub-player-history` 并跳转；
2. `create-v2.html` 点「发布并获取链接」→ 链接在**新 context** 能打开并抽奖（挂住 P0-7）；
3. `play.html?config=<slug>` 匿名打开 → 抽奖一轮 → `play_sessions` 行数 +1（挂住 P0-3/P1-6）。

## 9. 结论

### 9.1 最值得先修的 3 件事

**① 关掉 `create-client-user` 与三处 RLS 放行（P0-1 + P0-3）**
唯一能让「匿名者改统计、批量开账号」停下来的一步，且零前端改动。证据：`create-client-user/index.ts:18-22` 用 service_role 造号；`schema.sql:131-135` 的 `or true`；`schema.sql:101-102` 的 `true`。

**② 让 `leaderboard` 真实存在，并停止伪造玩家身份（P0-4 + P0-5）**
现在整链路是「写不存在的表 → safeQuery 吞错 → 读 localStorage」，同时把 email 当昵称公开。补表 + RPC + Edge Function 从 JWT 取 `player_id`，排行榜才从 UI 幻觉变成功能。

**③ 把 V2 发布链路的存储从 localStorage 换成 Supabase（P0-7）**
「创作者发布 → 朋友跨设备打开」是核心承诺，现在只是本机自娱，页面自己写着「不在当前浏览器的数据中」。实现 `supabase-share-service.js` 即可，`publish/resolve` 端口已干净，替换成本最低。

P0-6 的 XSS 排第 4：它的利用前提是「有人点开分享链接」，而分享链路目前跨不了设备 —— ①②③ 修完，XSS 可达面会立刻放大，必须紧随其后。

### 9.2 未来三个迭代

**迭代 1：把「两套宇宙」合并成一套（无新功能）**
- 唯一配置模型：以 `{type,version,payload}`（`platform/contracts/game-definition.js:24-26`）为准，`games/wheel/config.js` 的 `normalizeConfig` 输出改成 envelope 的 `payload`；`app/platform/manifests/wheel.js` 的 blocks 与 `games/wheel` 的 prizes 择一，另一个改 `migrate`。
- 唯一路由表、唯一注册表（`platform/registry`），`app/platform/*` 与 `app/games/*` 标记冻结。
- 唯一迁移目录（删 `db/migration-v2.sql`）。
- 退出标准：`GameHubGameRegistryV2` 与 `user_configs` 的引用点各自收敛到 ≤2 个文件。

**迭代 2：建立「宿主页」契约，让 Godot 真能接进来**
- 先做 `games/wheel` 宿主化：`play-v2.html` 只保留 `mount(gameType, config, hostEl)` 一行，游戏自管 DOM 与生命周期（`mount/start/destroy`，`games/wheel/player.js` 已有雏形）。
- `runtime/bridge.js` 升级 v2 协议：targetOrigin 白名单、`event.source` 校验、ACK + 超时生效、消息类型白名单（只转发 `CONTRACT.md:8-45` 的 6 类）。
- 新增 `games/wheel/godot-adapter.js` 骨架：同一 `mount/start/destroy` 接口，内部走 bridge，`<iframe>` 目标先用 `wheelcut/`，将来换 Godot Web 导出 —— 这才是「迁移就绪」的可验证形态：**换 iframe 的 src 不需要改业务代码**。
- 退出标准：把 `wheelcut/index.html` 换成任意 iframe 页，`play-v2` 抽奖流程不报错。

**迭代 3：把「部署一致性」变成机器约束**
- CI 从 4 步扩到「语法（含内联）→ 单测 → 边界 → 冒烟 → 链接检查 → 路径规范（禁根绝对 `/`，`wheelcut` 白名单）」。
- 新增 `scripts/check-paths.mjs`：校验每个 HTML 的 `src/href` 可解析，`wheelcut` 内绝对路径必须在白名单 —— 锁死 §4.9 的子路径破点。
- 新增 `scripts/check-links.mjs`：把 `personality-test.html:567` 这类 404 挡在合并前。
- 部署前 `git status --porcelain` 必须为空。

## 10. 评审元数据

- **Positive Observations**（真实优点）：
  - `games/wheel/` 是全仓唯一「有接口、有单测、有校验、有转义」的模块：`config.js:21-60`、`engine.js:8-16` 的 phase 状态机、`player.js:11` 的 `escapeHtml`、三层测试。
  - `scripts/check-platform-boundaries.mjs:14-18` 用正则强制「游戏模块不得引用 supabase/runtime/其他游戏」，依赖方向约束正确。
  - `leaderboard.js:9-17` 从自身 `<script src>` 反推 base —— 全仓唯一真正考虑过 GitHub Pages 子路径的代码。
  - `platform/config|sharing` 的端口设计（`save/load`、`publish/resolve`）是正确的可替换抽象，缺的只是 Supabase 适配器。
  - `docs/superpowers/plans/2026-08-03-platform-rebuild-implementation.md:5-9` 目标表述清晰（「平台只加载游戏模块、冻结旧页面」），方向没错，执行只到 Task 4。
- **ADR Compliance**：`NO ADRS FOUND`
- **Engine Specialist Findings**：`NOT ASSESSED — no engine configured`（无 `project.godot`/`project.yaml`）
- **Required Changes**：P0-1 ~ P0-8 全部
- **Verdict**：**CHANGES REQUIRED**（Godot 迁移相关结论标注 `NOT ASSESSED — NO DATA`）
