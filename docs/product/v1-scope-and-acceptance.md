# GameHub V1 产品范围与可观察验收标准

**版本**：v1.0（基于 HEAD `e816c37` + 工作区未提交改动）
**日期**：2026-10-28
**依据**：`docs/architecture/codebase-audit-2026-10-28.md`（434 行）、`AGENTS.md`、`docs/gamehub-2-architecture.md`、`docs/architecture/game-migration-map.md`、`docs/superpowers/plans/2026-08-03-platform-rebuild-implementation.md`、`docs/superpowers/plans/2026-08-04-wheel-v1.md`，以及本次现场复核（`index.html`、`create-v2.html`、`play-v2.html`、`play.html`、`player-history.html`、`leaderboard.html`、`leaderboard.js`、`reporter.js`、`supabase.js`、`platform/sharing/browser-share-service.js`、`supabase/migrations/*`、`db/schema.sql`、`.github/workflows/quality.yml`）
**本文不含**：PRD 式背景叙事、视觉方案、排期甘特图。只含范围、判定条件、以及必须由你拍板的分歧点。

---

## 0. 一页速览

### 0.1 V1 一句话命题

> **一条创作者发布的大转盘链接，换一台设备、换一个浏览器打开，能玩，并且这一局的结果能被任何拿到这条链接的人读回。**

V1 只承诺这一个闭环成立。它不承诺平台变大、游戏变多、Godot 落地。

### 0.2 反命题（V1 明确不做，用于挡住范围蔓延）

- 不做「全站排行榜」「跨游戏排行」「可信竞技榜」。
- 不做账号体系、登录后历史、跨设备「我的记录」。
- 不做 Godot 工程、不做 `GameHubBridge` 协议升级。
- 不做旧页面迁移/重写、不做 45 个内联游戏统一化。
- 不做发奖、核销、商城、活动运营后台。

### 0.3 四条假设的裁决

| # | 你的表述 | 裁决 | 一句话重述 | 关键证据 |
|---|---|---|---|---|
| P1 | 创作者做完游戏，分享链接只在本机 localStorage 有效，朋友打开是空的 | **确认，但需限定范围** | 只有 V2（大转盘）链路失效；旧链路 `builder-v2 → play.html?config=slug` 是真落库、能跨设备；且 V2 还有一层更表面的断点——产出的「分享链接」是相对路径 | `platform/sharing/browser-share-service.js:9-10`；`create-v2.html:3`（`link='play-v2.html?game=wheel&config='+...`）；`play.html:213-231` |
| P2 | 玩家玩完看不到可信的榜与历史记录（分数写入不存在的表，回落本机） | **确认，且比描述更严重** | 写入表不存在、读侧也无调用点、`submitAndNotify` 根本不发请求、V2 玩家页零上报；「榜」100% 是本机数据 | `supabase.js:40,56`；SQL 中 `leaderboard` 0 命中；`supabase.js:37` 定义 `getLeaderboard` 但全仓无调用；`leaderboard.js:254`；`reporter.js:20`；`play-v2.html:3` |
| P3 | 仓库有 60+ 个旧页面，但大厅入口被未提交改动删掉，内容无法被发现 | **推翻原表述** | 不是「被误删」，而是一次**未声明的产品转向**：`index.html` 已改成「接收分享链接的终端」，并非大厅；且即使回退，HEAD 大厅也只有 9 张硬编码卡，catalog 有 38 条 | `index.html:21`、`index.html:35`（终端逻辑）；`git show HEAD:index.html`（9 张 `.game-card`）；`app/data/game-catalog.js`（实测 `all.length = 38`）；`app/shell/home.js:3-11` 只过滤这 9 张 |
| P4 | 计划中的 Godot 旗舰游戏没有任何工程工件，投入无法验证 | **确认，并升级为「承诺与事实不符」** | 不只是「没有工件」，而是文档承诺（AGENTS.md 当前重点 1、2）与工程现实脱节：`GameHubBridge` 的对端是一个 Next.js 静态导出，不是 Godot；桥本身还不安全 | `find` 三模式 0 命中；`runtime/bridge.js:6`（`wheelcut/index.html`）、`:51`（`targetOrigin='*'`）、`:143`（不校验 `event.origin`） |

### 0.4 你漏掉的两个问题（V1 必须带）

| # | 问题 | 为什么不能留到下一迭代 |
|---|---|---|
| P5 | **修好分享，等于把存储型 XSS 的到达路径修通** | 配置类 XSS 需要「陌生人打开你的配置」才可达。分享链路跨不了设备时，攻击面被偶然关着；M1/M2 一上线，`play-v2.html:3`（`config.title`）、`create-v2.html:3`、`player-history.html:4`（`innerHTML` 拼 `item.url`）、`play.html:283,291-294,300` 立刻对外可达 |
| P6 | **「可验证」本身不可用，V1 完成与否无法判定** | 实测 `npm run test:smoke` 与 `npm run test:e2e` 均崩在 `browserType.launch`（包 1.61.1 要 `chromium_headless_shell-1228`，本机缓存只有 `-1248`）；`scripts/check-project.mjs:15` 只覆盖 `.js/.mjs/.cjs`；CI 只有语法检查 + 冒烟 3 步。没有可复现验收，「V1 完成」是主观判断 |

### 0.5 一个迭代的容量与削减顺序

Must 五项合计约 **7.5 人日**（1 名熟悉该仓库的前端），加 20% 缓冲约 **9 人日**——单人两周一迭代刚好，无余量接 Godot 或大厅重做。
若容量不足，削减顺序固定为：**S1（目录页） → A8（旧链回归） → S2 → M4 降级为「提交入口文件 + 死链 0 + 本机标注」，不做入口形态改造**。`M1/M2/M3` 不可裁，裁掉任何一条，V1 命题即不成立。

### 0.6 今天必须拍板的 3 件事

1. **玩家入口形态**：终端（现状）/ 大厅（HEAD）/ 双层。（推荐：双层，见 Q1）
2. **匿名发布策略**：给 `user_configs` 加匿名 insert 策略（快、无部署面）vs 走 Edge Function（稳、多一个部署面）。（推荐：前者，见 Q2）
3. **结果是否要防伪造**：V1 声明「可读」还是「可信」。（推荐：只声明「可读」，见 Q3）

---

## 1. 用户问题重述（附证据）

### 1.1 我推断的业务目标（含推断依据）

这不是从零立项，是从一份自评「CHANGES REQUIRED」的仓库里找出唯一值得先做对的事。据此推断：

| 编号 | 推断 | 依据 |
|---|---|---|
| B1 | 产品定位是「可配置 + 可分享 + 可验证」的自助小游戏平台，不是流量平台 | `AGENTS.md` 定位段；`docs/gamehub-2-architecture.md`「正式分享继续使用 Supabase 的 share_slug，URL 只携带 game 与 config 引用」；`docs/architecture/game-migration-map.md`「新链接只能指向平台宿主和 `games/<type>` 模块」 |
| B2 | 当前核心资产是「一条跑得通的闭环」，不是「游戏数量」 | 95% 代码仍在旧 HTML（根目录 HTML 89,292 行 vs `app/` 646 + `games/` 240 + `platform/` 150）；4 代平台抽象并存；`games/wheel/` 是唯一有接口/单测/校验/转义的模块 |
| B3 | Godot 是承诺，不是范围 | `find` 三模式 0 工件；审计自评迁移就绪度 0.8/5，「Godot 迁移是文档状态，不是工程状态」 |
| B4 | 真正付费方（活动主办方）没有产品面，因此不是 V1 用户 | `campaigns`/`clients` 表存在，`admin.html` 是硬编码样机（`admin.html:1339-1346` 假数据、`:1358-1361` 假统计），无鉴权却公开可达 |

由此得出：**V1 的目标不是增长，是把一句已有的产品承诺变成可证伪的事实**。因此 V1 的成功指标是「闭环正确率」类指标，不是 DAU（§7 会解释为什么不设 DAU）。

### 1.2 P1：分享只在本机有效

- **你的表述**：创作者做完游戏，分享链接只在本机 `localStorage` 有效，朋友打开是空的。
- **裁决**：确认，但需要两处校正。

**校正一：范围只到 V2。** 旧链路是真的落了库的：`builder-v2.html:537-555` → `user_configs.insert/update` + `is_published:true` + `share_slug`；`play.html:213-231` 用 `select('*').eq('share_slug', slug).single()` 读回，RLS 对 `is_published=true` 放行（`supabase/migrations/20260711000000_gamehub_v2.sql:48-50`）。所以「分享必失效」不成立——**失效的是新的那条（大转盘），可用但已被声明冻结的是旧的那条**。这两条链路并存本身是问题：同一件事有两个实现，一个能跨设备、一个不能，而入口指向不能的那个。

**校正二：还有一层更表面的断点，比 localStorage 更早引爆。** 发布后拼出来的链接是相对路径：

```js
// create-v2.html:3（publish 分支）
var reference = await shares.publish(saved),
    link = 'play-v2.html?game=wheel&config=' + encodeURIComponent(reference)
setMessage('已发布，分享这个链接给朋友：', link)
```

`link` 没有 origin。创作者复制到的是一串 `play-v2.html?game=...`，粘进微信/浏览器都不成立。也就是说：**即使朋友就在同一台机器上，这条链接也不是一条可发送的 URL**。修 M1 时必须同时约束「分享 URL 由 `location.origin + location.pathname` 派生」，否则验收 A2 会在第一步就卡住。

**重述（P1）**：创作者发布后拿到的不是一条可发送的绝对 URL；即使手动补全，接收端也只会在自己的浏览器存储里找配置，跨设备必然落空。

### 1.3 P2：榜与历史不可信

- **你的表述**：分数写入不存在的表，回落本机。
- **裁决**：确认，且实际有四处断点，比你描述的更彻底。

1. **写入打向不存在的表**：`supabase.js:56` `GHSupabase.from('leaderboard').upsert(...)`；全仓 5 个 SQL 文件对 `leaderboard` 0 命中（本次 `grep -rn "leaderboard" --include=*.sql` 返回空）。错误被 `safeQuery`（`supabase.js:21-33`）转成 fallback，因此这个缺口从上线潜伏到今天。
2. **读侧也是死的**：`supabase.js:37` 定义了 `getLeaderboard`，全仓**无任何页面调用**（`grep -rn "getLeaderboard" --include=*.html` 只命中定义处）。所以「有榜可看」这件事在服务端从来没被实现过，不是坏了，是没做。
3. **本地提交根本不发网络请求**：`leaderboard.js:254` 的 `submitAndNotify` 只调用 `submit()` 写 `localStorage`；只有被 `reporter.js:132` 打补丁、且满足 `reporter.js:20` 的 `player && campaignId` 双条件时，才会有一次 `play_sessions` 上报。**51 个根目录页面在调 `submitAndNotify`**（本次计数），它们都在往自己浏览器里写。
4. **V2 玩家页零上报**：`play-v2.html:3` 抽奖后只做一件事——`resultName.textContent = ...; result.hidden = false`。没有 `play_sessions`、没有 `game_results`、没有 `leaderboard`。大转盘是审计认定的「唯一就绪」旗舰模块，也是全站唯一一个玩完连本机记录都不写的主力游戏——51 个旧页面至少还会往 localStorage 写一条。

**重述（P2）**：平台上不存在任何一条可跨设备读回的玩家结果；「榜」是 51 个页面各自往 localStorage 写的本机数据，且写入路径打向一张不存在的表。

### 1.4 P3：大厅被删

- **你的表述**：60+ 旧页面，大厅入口被未提交改动删掉，内容无法被发现。
- **裁决**：**推翻**。真实情况更接近「一次未声明的产品转向」，而且发现性问题在删之前就存在。

当前工作区的 `index.html` 不是残缺版大厅，是一个完整、刻意设计的**分享链接接收终端**：

```
GAME LINK RECEIVER / ONLINE
朋友发来一局游戏。 现在，按下开始。
INSERT A GAME LINK → 打开朋友分享的游戏
「进入后直接开玩。你不会改动创作者设置。」
chips：即时开玩 / 玩家不可编辑 / 分享链接直达
```

它有自己的表单校验、自己的历史写入（`index.html:35`，键 `gamehub-player-history`，`list.slice(0, 12)`）、自己的成功文案。这不是删除，这是**换了产品形态**：从「游戏大厅」变成「玩家模式的单点入口」。

三个后果：

1. **这个决策没有进任何文档**。`docs/` 里没有一条记录说「大厅不再是大厅」；AGENTS.md 的当前重点也不含入口形态。产品决策藏在未提交改动里，等于不存在。
2. **它指向一个未跟踪文件**：`index.html:21` 的 `nav` 直接 `href="player-history.html"`，而 `player-history.html` 是 `??` 未跟踪。只提交 `index.html` 的任何一个 commit 都会让 main 出现死链——这直接违反 `AGENTS.md` 的「`main` 只保持可部署状态」。
3. **即使回退到 HEAD，发现性也只到 9/38**：HEAD 大厅是 9 张硬编码 `.game-card`，`app/shell/home.js:3-11` 只是拿 catalog 给这 9 张卡补元数据与过滤，catalog 里另外 29 条从来没有入口。所以「内容无法被发现」在删之前就是 29/38 的状态，删除只是把它变成 38/38。

**重述（P3）**：入口形态（大厅 / 链接终端）从未被决策并记录；当前代码已单方面转向「终端」，使 38 条 catalog 条目与 72 个根页面失去统一入口；且该转向引用未跟踪文件，随时可让 main 出死链。

### 1.5 P4：Godot 无工程工件

- **你的表述**：没有工程工件，投入无法验证。
- **裁决**：确认，并需要升级表述——**这是一种误导性承诺，不只是空投入**。

- `find . \( -name "project.godot" -o -name "*.gd" -o -name "*.tscn" -o -name "*.tres" \)` → 0 命中（本次实跑）。
- `AGENTS.md` 当前重点第 1 条「以大转盘作为 Godot 品质标杆」、第 2 条「建立 Godot 与 `GameHubBridge` 的前后端通信层」—— 两条都以 Godot 为前提。
- 而 `GameHubBridge` 的真实对端是 `wheelcut/` 的 Next.js 静态导出：`runtime/bridge.js:6` 的 iframe `src="wheelcut/index.html"`。**桥里没有一个 Godot 对象**，它是一层 iframe 封装。
- 这层封装自身不安全：`runtime/bridge.js:51` `targetOrigin: '*'`；`:143` 不校验 `event.origin` / `event.source`；`:160` `_pendingTimers` 从未写入、`:23` 的 `TIMEOUT_MS` 从未使用。
- 迁移就绪度自评 0.8/5（工件 0｜协议完整性 2｜通信层安全性 0｜前端承载页 2｜状态/存档 1）。

**重述（P4）**：路线图把「Godot 旗舰 + 桥」当作当前重点，仓库里既没有 Godot 工件，也没有一个与 Godot 对话的协议实现；现有桥的对端是别的技术栈的静态导出，且不校验来源。V1 不投入此处，但必须给出「去留」的判定时点（Q5）。

### 1.6 P5：修好分享即放大 XSS 攻击面（补）

审计 §9.1 已经点明这个顺序问题：「P0-6 XSS 排第 4：利用前提是有人点开分享链接，而分享链路目前跨不了设备 —— ①②③ 修完可达面会立刻放大，必须紧随其后」。这句话应该直接成为 V1 范围约束。

具体可达点（都是「陌生人的配置/链接进入我的页面」这一条路径）：

| 位置 | 注入源 |
|---|---|
| `play-v2.html:3` | `config.title` 直接拼进 `innerHTML` |
| `create-v2.html:3` | `setMessage(...)` 把 `outcome.prize.name` 拼进 `innerHTML` |
| `player-history.html:4` | `'<a class="btn btn-ghost" href="'+item.url+'">再玩一次</a>'`，而 `index.html:35` 的校验只拦 `javascript:` 于写入侧，本页读取侧不复校验 |
| `play.html:283,291-294,300` | 旧链路配置的 `score` / `p.name` / `p.emoji` / `log[]` |
| `play.html:229` | `e.message` 反射 |

对照：`games/wheel/player.js:11` 与 `games/wheel/editor.js:6` 已有 `escapeHtml`，`app/platform/manifests/wheel.js:23-40` 有 `validate`。**新模块有防线，旧页面没有**；缺的是一个共用工具函数，不是知识。

### 1.7 P6：验收不可复现（补）

- 本地实测：`npm run test:smoke` → `browserType.launch: Executable doesn't exist at .../chromium_headless_shell-1228/...`，退出非 0；`npm run test:e2e` 同一错误。缓存目录里是 `chromium_headless_shell-1248`，包是 `playwright@1.61.1`。
- `scripts/check-project.mjs:15` 的正则只收 `\.(js|mjs|cjs)$`，把 1.19MB 内联脚本排除在外；`:6` 的 ignored 不含 `.worktrees`，导致 277 个被检查文件里近半是 `.worktrees/gamehub-rebuild/` 的副本。
- `scripts/smoke-test.mjs:25-26` 先 `listen` 再 `launch`，没有 `try/finally`，崩溃时服务器进程残留。
- CI（`.github/workflows/quality.yml`）只有：`npm run check` → `npx playwright install --with-deps chromium` → `npm run test:smoke`。`test:architecture / test:platform / test:games / check:boundaries` 4 个已存在的脚本没有接线。

**含义**：任何「V1 完成」的声明都无法被第三方复现。所以「验收脚本可跑」本身是 Must（M5），不是收尾工作。

### 1.8 问题优先级

维度：**用户可感知**（有外部用户会因此受损）× **可判定性**（能否用命令判定修好）× **成本**（人日）。

| 问题 | 可感知 | 可判定 | 成本 | V1 |
|---|---|---|---|---|
| P1 分享跨设备失效 | 高（唯一闭环断了） | 高（两个 context 即判定） | 1.5 | **Must** |
| P2 结果/榜不可信 | 高 | 中（需要新表 + 一致性校验） | 2.0 | **Must**（缩到「单链接流水」） |
| P5 XSS 可达 | 中（需点开分享链接） | 高（`window.__xss` 断言） | 1.5 | **Must** |
| P3 入口/发现性 | 中（老用户找不到旧游戏） | 高（死链计数 + 卡片数） | 1.0 | **Must**（只做决策落地与死链 0；目录页给 Should） |
| P6 验收不可复现 | 低（用户无感） | 高 | 1.5 | **Must**（否则全表不可判定） |
| P4 Godot 空承诺 | 低（尚无用户） | 高（文件存在性） | 大 | **Not Now**（要的是决策，不是工程，见 Q5） |

---

## 2. 目标用户与优先级

只用三档，不用五档——这个仓库只有一个开发者，用户档位越多越无法执行。

### 2.1 P0：创作者（唯一有完整创作 → 发布路径的人）

- **是谁**：想把一次选择/抽奖变成一条可发送链接的人。做一次，发出去，不打算长期运营。
- **当前他有的东西**：`create-v2.html`（可视化配置 + 实时预览 + 试玩 + 发布）；`games/wheel/`（config/engine/editor/player 四件套，唯一有单测的模块）；`platform/config|sharing` 的 `save/load`、`publish/resolve` 端口设计。
- **他今天卡在哪**：拿到的是一条相对路径（§1.2 校正二）；就算补成绝对路径，接收端也读不到。**他可以完成创作，但无法完成「分享」。**
- **为什么 P0**：他是唯一会主动复制链接的人；链接是 V1 全部价值的载体。没有他，P1 用户不存在。
- **V1 对他的承诺**：点「发布并获取链接」→ 得到一条可直接发出去的绝对 URL → 这条 URL 在别人的设备上能打开同一局。

### 2.2 P1：被分享的玩家（数量上限取决于创作者，但每次分享都至少 1 人）

- **是谁**：点开链接的人。不注册、不创作、不逛站、大概率在手机上、从微信里点开。
- **当前他有的东西**：`play-v2.html`（标题 + 转盘 + 一次抽奖 + 结果弹层 + 再玩一次 + 分享按钮）。
- **他今天卡在哪**：打开就是「这个分享链接不可用 / 它可能已失效，或不在当前浏览器的数据中」（`play-v2.html:3` 的兜底分支）。这是 V1 最刺眼的一句话——它是写给开发者看的，不是写给玩家看的。
- **V1 对他的承诺**：打开 → 看到朋友配的标题与奖项 → 抽一次 → 看到结果 → 这条结果留在能看到这条链接的地方。

### 2.3 P2：维护者（内部用户，1 人；但 V1 的一半工作是为他做的）

- **是谁**：你。改代码、发部署、判断「能不能上线」。
- **他今天卡在哪**：`main` 上躺着 6 个未提交/未跟踪项（`index.html`、`scripts/smoke-test.mjs`、`creator.html`、`office-escape.html`、`player-history.html`、本审计文档）；本地冒烟跑不起来；CI 只跑 3 步。
- **V1 对他的承诺**：一条命令判定 V1 是否成立；`git status --porcelain` 为空才算可发布；死链 0。

### 2.4 非目标用户（明确写，用来砍需求）

| 非目标 | 为什么现在不是用户 | 相关资产（存在但不上线承诺） |
|---|---|---|
| 付费活动主办方 | 无产品面：无活动创建、无核销、无结算；`admin.html` 是静态样机 | `campaigns`/`clients` 表、`admin.html`、`campaign_stats` |
| 需要排名的竞技玩家 | V1 不存在可信榜；承诺榜单等于承诺反作弊 | `leaderboard.js`（本机）、`supabase.js:37`（死代码） |
| 要「我的历史」的注册用户 | 认证 token 不可信（`auth-player.js:237` 的 token 可能等于 userId；`supabase.js:82-84` 只判 key 存在），做历史=做账号 | `auth-player.js`、`players` 表 |
| Godot 品质玩家 | 0 工件 | `runtime/bridge.js`、`wheelcut/` |
| 多游戏类型创作者 | 只有大转盘一个模块有完整编辑器 | `app/platform/manifests/`、`app/games/` |
| 移动端重度性能用户 | 无性能预算、无设备矩阵、无度量 | `design-system.css` |
| 需要「离线也能玩」的用户 | 现有离线体验 = localStorage 兜底，V1 的方向是消灭兜底 | `safeQuery`、`gh_leaderboard` |

### 2.5 用户 → 场景 → 责任面对齐

| 用户 | 主要场景 | 主要责任面 |
|---|---|---|
| P0 创作者 | S1 | 前端（`create-v2.html`）+ 数据面（`user_configs` 写入策略） |
| P1 玩家 | S2、S3、S4 | 前端（`play-v2.html`、`player-history.html`）+ 数据面（`game_results` 读写） |
| P2 维护者 | S4 + 全部验收 | 前端（工具链）+ 内容（文档/入口决策） |

---

## 3. 核心场景

### S1 创作者发布并自测

- **触发**：手上有一场聚会/一次抽奖，需要一个随机选择工具。
- **行为**：打开 `create-v2.html` → 改标题与奖项 → 点「试玩抽奖」看效果 → 点「发布并获取链接」。
- **期望结果**：`#message` 出现一条**绝对 URL**（形如 `https://games.jydigtal.com/play-v2.html?game=wheel&config=share_xxx`），可直接复制；本机打开该 URL 能完整抽一次。
- **当前断点**：`create-v2.html:3` 拼的是相对路径 `'play-v2.html?game=wheel&config='+...`，复制即不可发送。另外 publish 分支没有 `try/catch`，localStorage 配额超限时是 unhandled rejection、UI 无反馈（审计 §4.5）。

### S2 玩家在另一台设备打开并抽一次

- **触发**：收到一条链接（微信/短信/任何 IM）。
- **行为**：点开 → 看到标题与转盘 → 点「开始抽奖」→ 看到结果。
- **期望结果**：标题与奖项与创作者配置一致；抽一次出结果；**不出现**「这个分享链接不可用」。
- **当前断点**：`play-v2.html:3` 的 `shares.resolve(ref)` 只读本机（`platform/sharing/browser-share-service.js:10`），跨设备必为空 → 命中兜底文案。这是 P1 的全部内容。

### S3 任何人回看这条链接的结果

- **触发**：创作者想知道「我发出去之后有人玩了吗」；玩家想回看自己刚抽到什么。
- **行为**：打开 `player-history.html`（或带 `?config=<ref>` 的深链）。
- **期望结果**：列出这条链接最近若干条结果（奖项名 + 时间），数据来自服务端；「本机打开记录」作为独立区块存在，并明确标注「仅本机」。
- **当前断点**：`player-history.html:4` 只读 `localStorage['gamehub-player-history']`，且这个键只在 `index.html:35` 的终端表单提交时写入——**从 `play-v2.html` 进来的玩家根本不会产生任何记录**。空态文案（「你还没有玩过游戏」）是当前唯一可能的结果。

### S4 玩家从入口进入一局

- **触发**：手上没有链接，想知道这里有什么可玩。
- **行为**：打开站点根路径。
- **期望结果**：两种形态之一，但必须是**被决策过**的：终端（粘贴链接）或目录（从 catalog 选）。不允许出现「终端的样子 + 大厅的文案」「指向未跟踪文件的导航」。
- **当前断点**：`index.html:21` 的 nav 指向 `player-history.html`（未跟踪，提交即死链）；`index.html` 正文无任何 catalog 入口，38 条 catalog 条目与 51 个计分页面在此页面之外不可达。

### S5 恶意配置与恶意链接

- **触发**：一个不怀好意的人发布了 title 为 `<img src=x onerror=...>` 的配置，或在自己的 localStorage 里塞了 `javascript:` 链接，然后请人打开。
- **行为**：受害者正常打开链接。
- **期望结果**：页面把注入内容当**文本**渲染（用户看到字面量 `<img ...>`），不执行脚本；`javascript:` 链接被拒绝或降级为纯文本。
- **当前断点**：`play-v2.html:3`（title）、`create-v2.html:3`（prize name）、`player-history.html:4`（`href`）全部直接拼 `innerHTML`。S2 一旦修通，S5 就从「不可达」变成「一键可达」。

---

## 4. V1 范围：Must / Should

### 4.1 Must（5 条，缺一条 V1 命题不成立）

| ID | 能力 | 可交付物 | 责任面 | 估时 |
|---|---|---|---|---|
| M1 | 分享链接跨设备可开 | `platform/sharing/rest-client.js`（fetch 最小客户端，40 行）+ `platform/sharing/supabase-share-service.js`（实现 `publish/resolve` 端口，不动调用方签名）+ `create-v2.html`/`play-v2.html` 注入 + 绝对 URL 派生 + `user_configs` 匿名发布策略 | 数据面 + 前端 | 1.5 人日 |
| M2 | 单链接结果可写可读 | 新迁移（`game_results` 表 + RLS + 列级 grant）+ `play-v2.html` 结果回写 + 读侧查询封装 | 数据面 + 前端 | 2.0 人日 |
| M3 | 玩家可见的落点 | `player-history.html` 支持 `?config=` 服务端流水 + 本机区块标注「仅本机」+ `runtime/dom-safe.js` 工具函数 + 5 个渲染点收口 | 前端 + 内容 | 1.5 人日 |
| M4 | 入口决策落地与漂移收口 | 入口形态写进文档并实现（终端或目录，见 Q1）+ 提交 3 个未跟踪文件（顺序见 R4）+ 修 `personality-test.html:567` 死链 + 页面上明确标注「本机记录」 | 内容 + 前端 | 1.0 人日 |
| M5 | 验收可复现 | 新增 `scripts/acceptance/*.mjs` + `npm run accept` + `scripts/check-links.mjs` + playwright 版本/浏览器对齐 + CI 接上 4 个既有 npm script | 前端 | 1.5 人日 |

#### M1 细节：适配器，不是重写

现有「端口」是一种形状约定，不是正式接口文件：`platform/sharing/share-service.js:1-6` 是内存版（`publish` 存 `refs[config.id]`、`resolve` 读同一个对象），`browser-share-service.js:9-10` 是 localStorage 版，两者都只暴露 `publish/resolve` 且都返回 Promise。V1 只新增第三个同形状实现，因此**不需要改调用方**。

一个必须先补的前置事实：`create-v2.html` 与 `play-v2.html` **都没有加载 `supabase.js`**（实测两文件对 `supabase` 的引用计数为 0），而 `supabase.js:7-8` 把 URL 与 anon key 硬编码在旧代码里、还依赖 CDN 的 supabase-js。因此 M1 的交付物必须包含一个不引入依赖的最小客户端：

```js
// platform/sharing/rest-client.js（V1 新增，约 40 行，UMD，只用 fetch）
// createRestClient({ url, anonKey }) -> { select(table, query), insert(table, row), count(table, query) }
// 统一处理：非 2xx 抛错（不吞）、把 {message, code, details} 还原成 Error 以便 A5 判定可见失败
```

只有这样才能同时满足「不引入构建链」与「失败必须可见」。据此实现第三个同形状版本：

```js
// platform/sharing/supabase-share-service.js（V1 新增；形状与 browser 版一致）
// publish(config) -> { reference, url }
//   insert user_configs { game_type, title, config_version, config_payload, blocks, is_published: true, share_slug }
//   share_slug = 'share_' + 8 位 base36（客户端生成，唯一约束兜底，冲突重试 1 次）
//   url = location.origin + location.pathname.replace(/[^/]*$/, '') + 'play-v2.html?game=' + type + '&config=' + slug
// resolve(reference) -> { id, shareSlug, type, version, payload } | null
//   select id, share_slug, game_type, config_version, config_payload
//   from user_configs where share_slug = eq(ref) and is_published = true  (RLS 已放行)
//   注：V1 在适配器里硬编码 play-v2.html 路径；路由唯一化（platform/app-shell/routes.js）留到审计 §9.2 迭代 2，避免本次动到旧页面
```

三条硬约束（写进验收）：

1. `publish` 必须返回**绝对 URL**，且 `new URL(result.url).origin === location.origin`。
2. `publish` 的 Promise 必须可失败且失败可见——不允许 unhandled rejection（对应 A5）。
3. `resolve` 返回 `null` 时，`play-v2.html` 的兜底文案必须改成面向玩家的人话（当前那句是写给开发者的），且**不得**用 `innerHTML` 插入任何来自 URL 的内容。

#### M2 细节：新表，而不是修 `play_sessions`

不修 `play_sessions`：它绑死 `campaign_id` + `player_id`，RLS 是 `with check (true)`（`db/schema.sql` 的「玩家插入流水」策略），且读策略要求 `players.email = auth.email()`——匿名玩家读不到自己刚写的那行。要让它服务 V1，等于重做它的语义。

V1 新增一张只做一件事的表（迁移文件只新增，不改旧表，可整体回滚）：

```sql
-- supabase/migrations/<ts>_v1_game_results.sql
create table if not exists game_results (
  id           bigint primary key generated always as identity,
  config_id    uuid not null references user_configs(id) on delete cascade,
  game_type    text not null,
  result_index integer not null,
  result_label text not null,
  client_token text,                     -- 浏览器 uuid，仅做弱关联，不作身份
  created_at   timestamptz not null default now()
);
create index if not exists idx_game_results_config on game_results(config_id, created_at desc);

alter table game_results enable row level security;
create policy "任何人可读结果流水" on game_results for select using (true);
create policy "任何人可写一条结果" on game_results for insert with check (true);

-- 关键：列级授权，堵住「写别人的 config_id 之外还能写其它列」的面
revoke all on game_results from anon, authenticated;
grant select on game_results to anon, authenticated;
grant insert (config_id, game_type, result_index, result_label, client_token)
  on game_results to anon, authenticated;
```

**信任边界必须写在代码注释与本文里**：这张表允许匿名写入，因此「记录存在」可保证，「记录未被伪造」不保证。V1 的对外措辞只能是「这条链接上有人抽到了这些结果」，不是「可信榜」。可观测的补偿手段是一致性校验（A3 的第二条判定）与增量异常阈值（R3）。

还有一条要提前承认的边界：`select using (true)` 意味着**任意人可以在不带 `config_id` 过滤的情况下读取全表**（奖项名 + 时间戳，不含任何身份信息）。V1 接受这一点——它与「任何人可以读所有已发布配置」是同一级别的公开性；收口方式是 S3 里改成 `results_for_config(slug)` RPC（只能按 slug 读，不能全表扫），不在 V1 做。

#### M3 细节：收口工具函数，而不是逐处打补丁

新增 `runtime/dom-safe.js`（UMD，与现有模块风格一致），导出 `text(node, value)`、`attr(node, name, value)`、`safeHref(url)`。收口清单固定为 5 处：`play-v2.html:3`、`create-v2.html:3`、`player-history.html:4`、`play.html:283/291-294/300`、`play.html:229`。`games/wheel/player.js:11` 的私有 `escapeHtml` 改为引用该工具（保留导出以兼容现有测试）。

#### M4 细节：把决策写下来

无论选终端还是目录，M4 的交付物都必须包含一句可检索的决策记录（本文 §8.3 Q1 定稿后回写），以及：

- 提交顺序：`player-history.html` → `creator.html`/`office-escape.html` → `index.html` → `scripts/smoke-test.mjs`。理由：`index.html:21` 已 `href` 未跟踪文件，先提交被引用者才能保证每个中间 commit 都可部署。
- 修 `personality-test.html:567` 的 `2048.html` → `game-2048.html`。
- `leaderboard.html` 顶部加「本机记录」标注（数据 100% 来自 `localStorage`，这是事实陈述，不是降级）。

### 4.2 Should（V1 内有余量才做，不阻塞命题）

| ID | 能力 | 交付物 | 责任面 | 不做会怎样 |
|---|---|---|---|---|
| S1 | 目录页 | 新增 `games.html`，由 `app/data/game-catalog.js` 驱动渲染全部 38 条，`status` 非 `live` 的标注而不是隐藏；每条 href 必须 200 | 前端 + 内容 | 38 条里最多 9 条可达；旧游戏资产对用户不可见 |
| S2 | `plays_count` 与 `campaign_stats` 修正 | `increment_plays` RPC（替代 `play.html:226` 的读改写）+ `campaign_stats` 的 `or true` 收紧 | 数据面 + 前端 | 播放数不准（匿名必被 RLS 拒，且静默）；统计表任何人可改 |
| S3 | 发布收口到 Edge Function | 新增 `publish-config`（服务端校验 payload 形状/体积 + 限速 + 生成 slug），匿名直写策略回收 | 数据面 | 匿名可无限发布配置（垃圾数据面） |
| S4 | `admin.html` 处理 | 移出部署路径（推荐）或加登录门 | 内容 | 假数据后台公网可达（`admin.html:1339-1361`） |
| S5 | PII 收口 | 任何公开面不展示 `player_name`（`supabase.js:53-67` 的 `player_name: player.phone` 实为 email） | 前端 + 数据面 | V1 若展示名字即泄露邮箱 |

### 4.3 容量与削减

Must 合计 7.5 人日 + 20% 缓冲 ≈ **9 人日**。削减顺序（固定，先砍后四项）：

1. S1 目录页（降级为「终端 + 一行『看全部游戏』链到 catalog 渲染的最简页」）
2. A8 旧链回归（改为人工一次性确认，不进冒烟）
3. S2 计数修正
4. M4 降级为「提交入口文件 + 死链 0 + 本机标注」，入口形态维持现状并登记为未解决

**绝不削减**：M1、M2、M3、M5 的核心用例（A1–A7、A9）。裁掉任一条，§0.1 的命题就不成立，V1 变成「改了代码但没改变事实」。

---

## 5. Not Now（暂缓）与不做的理由

| ID | 事项 | 为什么现在不做 | 什么条件下重新考虑 |
|---|---|---|---|
| N1 | Godot 工程与 `GameHubBridge` v2 | 0 工件、0 协议实现、桥不校验 origin；做了也无法验收「品质标杆」 | 出现 `project.godot` + 一个可玩片段 + 明确的「迁移哪一款、验收什么」；否则按 Q5 走删除承诺 |
| N2 | 45 个内联 HTML 游戏迁移/重写 | 迁移不是用户问题；当前用户问题是「分享不通」 | V1 闭环连续两个迭代无 P0；且 catalog 里某款有真实使用信号 |
| N3 | 全站排行榜 / 多游戏排行 | 需要可信身份 + 反作弊 + 口径定义；V1 只能做到「记录存在」 | 有 ≥1 个游戏有稳定玩家量；且已实现服务端结果复算 |
| N4 | 账号体系 / 登录后历史 | `auth-player.js:237` 的 `token: data.session?.access_token || userId` 可能把 userId 当 token 用，`supabase.js:82-84` 只判 key 存在 → 现在做历史=做假历史 | Token 换成真 JWT（可验证签名），并有至少一个需要身份的功能 |
| N5 | 结果服务端复算 / 反作弊 | 大转盘是「配置决定概率 + 客户端随机」，服务端复算需要先定义可验证随机源；成本 > V1 全部 | 结果被用于发奖或排名 |
| N6 | 发奖、核销、商城、活动运营 | 无产品面、无结算、无客服；`admin.html` 是样机 | 有第一个真实活动需求与兑付流程 |
| N7 | `wheelcut/` 清理、`app/`+`runtime/` 冻结收尾、P2 结构整治 | 不影响闭环正确性；删了也不改变用户体验 | V1 之后专门做一次「删代码」迭代（审计 §9.2 迭代 1） |
| N8 | 多游戏类型创建器（答题/大富翁等） | 只有大转盘一个模块有完整编辑器 + 单测；扩类型=扩未验证面 | 大转盘闭环稳定，且模板抽象被至少 2 个游戏验证 |
| N9 | 移动端专项性能与设备矩阵 | 无预算、无度量、无测试设备 | 有真实移动端会话数据 |

---

## 6. 验收标准（可直接写进冒烟测试）

### 6.0 前置：环境与 fixture

```bash
# 0.1 依赖与浏览器对齐（当前阻塞项，见 R1）
npm ci
npx playwright install chromium          # 必须与 package.json 里的 playwright 版本一致

# 0.2 本地静态服务（任一即可）
python3 -m http.server 4173              # 或复用 scripts/smoke-test.mjs 的内置服务
export BASE=http://127.0.0.1:4173

# 0.3 从仓库读取出后端地址与匿名键（已硬编码在 supabase.js:7-8，无需另配环境变量）
export SUPABASE_URL=$(grep -oE 'https://[a-z0-9]+\.supabase\.co' supabase.js | head -1)
export ANON=$(grep -oE 'eyJhbGciOi[A-Za-z0-9._-]+' supabase.js | head -1)
curl -s "$SUPABASE_URL/rest/v1/" -H "apikey: $ANON" -o /dev/null -w '%{http_code}\n'   # 期望 200
```

判定规则：**`curl` 返回非 200、或任一脚本无法启动 = 该轮验收记 `BLOCKED`，V1 整体不通过。** 不接受 `SKIP`——「不可判定」在 V1 里等同于失败，因为 V1 的全部目的就是让事实可判定。

### 6.1 A1 发布写入（数据面，M1）

- **可观察信号**：`user_configs` 中出现且仅出现一条 `share_slug = <REF>`、`is_published = true`、`title` 与编辑器一致的行。
- **复现步骤**：

```bash
REF=$(node scripts/acceptance/publish.mjs --title "V1 验收转盘" --prizes "A,B,C" | tail -1)
echo "$REF"
curl -s "$SUPABASE_URL/rest/v1/user_configs?share_slug=eq.$REF&select=id,share_slug,is_published,title,config_version,config_payload" \
  -H "apikey: $ANON" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s);console.log(JSON.stringify({rows:r.length,ok:r.length===1&&r[0].is_published===true&&r[0].title==="V1 验收转盘"&&(r[0].config_payload?.prizes?.length||0)===3}))})'
```

- **通过**：`rows === 1` 且 `ok === true`。
- **失败**：`rows === 0`（策略未开或写入失败）／`rows > 1`（slug 冲突未处理）／`is_published !== true`／`title` 不符。
- **同时判定**：`publish.mjs` 输出的 URL 必须满足 `new URL(url).origin === location.origin`（脚本内断言），否则该条也 FAIL。

### 6.2 A2 跨设备打开（前端，M1）

- **可观察信号**：一个**全新的 browser context**（无任何前序存储）打开同一 URL，渲染出正确扇区数与标题，且没有兜底文案。
- **复现步骤**：

```bash
node scripts/acceptance/cross-device.mjs --ref "$REF"
# 内部：ctxA 打开 create-v2 发布拿 URL → ctxB = browser.newContext() 打开该 URL
#      收集 pageerror / console.error；断言 .wheel-sector 计数、h1 文本、.error 存在性
```

- **通过**（四条同时成立）：
  1. `document.querySelectorAll('.wheel-sector').length === payload.prizes.length`
  2. `h1` 文本 === 配置 `title`
  3. `document.querySelector('.error') === null`（不出现「这个分享链接不可用」）
  4. `pageerror` 计数 `=== 0`，且 `console.error` 中不含 `Failed to fetch` / `null`
- **失败**：任一不成立。特别注意 3：兜底文案出现即代表仍在本机存储里找配置。

### 6.3 A3 结果写入与一致性（数据面，M2）

- **可观察信号**：抽一次 → `game_results` 行数 +1，且该行 `config_id` 等于 A1 的 `id`、`result_label` 属于该配置的奖项名集合。
- **复现步骤**：

```bash
node scripts/acceptance/spin-and-count.mjs --ref "$REF"
# 内部：curl count before → ctxB 点 #spin 等 #result 可见 → 读 #resultName 文本 → curl count after
#      再拉最后一行 (config_id, result_label) 与 payload.prizes 名字集合对比
```

- **通过**：`count_after - count_before === 1`；`row.config_id === A1.id`；`row.result_label` ∈ 奖项名集合；`#resultName` 文本包含该 label。
- **失败**：增量 `0`（未写入）／`> 1`（重复写或双触发）／label 不在集合（记录不可信，说明写入的不是本局结果）。

### 6.4 A4 跨设备读回（前端 + 数据面，M2/M3）

- **可观察信号**：第三个全新 context 打开 `player-history.html?config=<REF>`，看到 A3 那条结果。
- **复现步骤**：

```bash
node scripts/acceptance/history-cross-device.mjs --ref "$REF" --label "<A3 的 label>"
```

- **通过**（四条同时成立）：
  1. `document.querySelectorAll('[data-result-row]').length >= 1`
  2. 首行 `[data-result-label]` 文本 === A3 的 label
  3. 首行时间与当前时间差 `< 5 分钟`
  4. 页面内 `a[href^="javascript:"]` 计数 `=== 0`
- **失败**：空态出现（「你还没有玩过游戏」）／label 不符／时间不符／存在 `javascript:` 链接。

### 6.5 A5 写失败必须可见（前端，M1/M2）

- **可观察信号**：把发布请求强制失败，页面出现可见错误提示，而不是只有 console。
- **复现步骤**：

```bash
node scripts/acceptance/write-failure-visible.mjs
# 子场景 a（网络/服务端失败）：
#   page.route('**/rest/v1/user_configs*', r => r.fulfill({ status: 500, body: '{}' }))
# 子场景 b（RLS 拒绝）：先临时 drop 匿名发布策略，或用一个错误的 anon key，
#   使 POST 返回 401/403 —— 这是上线后最可能真实发生的失败形态
# 两个子场景都执行：打开 create-v2 → 点 #publish → 等 2s → 断言 [data-error-banner]
# 全程监听 pageerror 与 unhandledrejection
```

- **通过**：两个子场景都满足——`[data-error-banner]` 存在、文本非空、含「重试」；`pageerror === 0`；`unhandledrejection === 0`。
- **失败**：无横幅（静默失败）／只有 console 输出／出现未捕获异常。当前基线两个子场景都失败：`create-v2.html:3` 的 publish 分支无 `try/catch`，且失败时 `#message` 不会有任何变化。

### 6.6 A6 注入不执行（前端，M3）

- **可观察信号**：恶意配置被当作纯文本渲染，脚本未执行。
- **复现步骤**：

```bash
node scripts/acceptance/injection.mjs
# 内部：用 REST 插入一条已发布配置：title=<img src=x onerror="window.__xss=1">，
#      prizes[0].name=<svg onload="window.__xss=2">；再向 localStorage['gamehub-player-history']
#      注入 {url:'javascript:window.__xss=3', name:'x'}，然后打开 play-v2 与 player-history
```

- **通过**（五条同时成立）：
  1. `window.__xss === undefined`（三个载荷都未执行）
  2. `document.querySelector('img[src="x"]') === null`
  3. `document.querySelector('svg[onload]') === null`
  4. `document.body.innerText` 含字面量 `<img`
  5. `pageerror === 0`
- **失败**：任一载荷执行、或元素被创建、或注入内容不可见（说明被错误地整体丢弃而不是转义）。

### 6.7 A7 入口与死链（内容 + 前端，M4）

- **可观察信号**：仓库内 0 个本地死链；入口文件不再引用未跟踪文件；工作区干净。
- **复现步骤**：

```bash
node scripts/check-links.mjs        # 新增：解析所有 .html 的 href/src，本地路径逐个 HEAD
git status --porcelain              # 在待发布分支上必须为空
node -e "…断言 index.html 不引用未跟踪文件…"   # 已包含在 check-links.mjs 里
```

- **通过**：`check-links` 退出码 `0` 且输出 `dead links: 0`；`git status --porcelain` 输出为空；`index.html` 若保留终端形态，则其 demo 链接 `play-v2.html?game=wheel` 返回 200。
- **失败**：任一 404（当前基线 1 处：`personality-test.html:567` → `2048.html`）／`git status` 非空／`index.html` 引用 `player-history.html` 而该文件未被跟踪。

### 6.8 A8 旧链回归（前端，防回归）

- **可观察信号**：`play.html?config=<旧 slug>` 仍能打开并抽完一轮。
- **复现步骤**：

```bash
node scripts/acceptance/legacy-share.mjs --slug "$LEGACY_SLUG"
# LEGACY_SLUG 来自线上已有 slug；若不存在，用 scripts/acceptance/fixtures.mjs 以 SERVICE_ROLE
# 造一条 blocks 格式的 is_published 行（fixture 脚本不进 CI，只在本地跑一次）
```

- **通过**：`play.html` 渲染出发起者 `title`；点一次主按钮后出现结果文案；`pageerror === 0`。
- **失败**：出现「找不到」／渲染空白／抛错。这条用例的存在意义是：M1/M2 动的是 `platform/` 与两个 v2 页，**不允许**顺手改坏旧链路——`AGENTS.md` 要求「前端和 Godot 改动必须保留现有 Supabase 接口兼容性」。

### 6.9 A9 验收可复现（工具链，M5）

- **可观察信号**：干净环境下一条命令得到确定结论。
- **复现步骤**：

```bash
npm run check \
 && npm run test:architecture \
 && npm run test:platform \
 && npm run test:games \
 && npm run check:boundaries \
 && npm run accept
```

- **通过**：全部退出码 `0`；`npm run accept` 输出 `PASS 8 / FAIL 0`（A1–A8 共 8 条；A9 自身不计入）。
- **失败**：任一非 0；或 `accept` 出现 `BLOCKED`、`SKIP`；或 `pageerror` 非 0 被脚本吞掉（脚本必须在结尾统一打印计数，不允许只打日志）。

### 6.10 执行清单（贴进 PR 描述）

```
[ ] A1 发布写入           rows=1 ok=true
[ ] A2 跨设备打开         sectors=N title=T error=null pageerror=0
[ ] A3 结果写入            Δ=1 label∈prizes
[ ] A4 跨设备读回         rows≥1 label 匹配 时间<5min 无 javascript:
[ ] A5 写失败可见         banner=present pageerror=0
[ ] A6 注入不执行         __xss=undefined img/svg=0 字面量可见
[ ] A7 入口与死链         dead=0 git=clean
[ ] A8 旧链回归           旧 slug 可玩 pageerror=0
[ ] A9 验收可复现         全绿 PASS 8 / FAIL 0
[ ] 手工：子路径部署下跑一次 A2（见 R5），确认 share URL 未硬编码根路径
```

---

## 7. 成功指标与度量方式

V1 不设 DAU / 留存 / 转化。理由：无流量来源、无埋点、无账号体系，这三个指标今天无法被测量，写出来只会变成装饰。V1 只测「闭环是否成立」和「兜底是否被消灭」。

| # | 指标 | 定义式 | 采集方式 | 基线（实测） | V1 目标 |
|---|---|---|---|---|---|
| K1 | 跨设备打开成功率 | A2 PASS 次数 ÷ 运行次数 | `npm run accept`（跑 10 次） | **0%**（`browser-share-service.js:10` 只读本机） | 100%（10/10） |
| K2 | 结果落库一致率 | `result_label ∈ 配置奖项名集合` 的行数 ÷ `game_results` 总行数 | `node scripts/acceptance/results-audit.mjs`：用 anon key 分页拉全表，再逐行比对所属 `config_id` 的 `config_payload.prizes` 名称集合（**不能写成 SQL join**：`config_payload` 是 jsonb，且 V1 不给 anon 建函数） | **不可测**（表不存在） | 100%（样本 ≥50 行） |
| K3 | 静默失败数 | 写失败但页面无可见提示的次数 | A5 + 代码审计（禁止空 `catch`） | **≥2**（`reporter.js:33-36` 只 warn；`play.html:226` 空 catch） | 0 |
| K4 | 本地兜底渲染次数 | 页面渲染出「数据来自 localStorage」的路径数 | 代码审计 + A2/A4 断言 | 51 个页面写本机榜；`play-v2` 兜底文案 | 0（本机数据仅允许出现在明确标注「仅本机」的区块） |
| K5 | 死链数 | `check-links` 报告的本地 404 数 | `node scripts/check-links.mjs` | **1**（`personality-test.html:567`） | 0 |
| K6 | 关键页运行时错误数 | 5 页（`index`/`create-v2`/`play-v2`/`player-history`/`leaderboard`）的 `pageerror` 总数 | `npm run accept` 内断言 | 未测（无页面级错误断言） | 0 |
| K7 | catalog 可发现率 | 从入口页可达的 catalog 条目数 ÷ 38 | `check-links` + 入口页断言 | **0/38**（当前终端）；HEAD 为 9/38 | 38/38（若 S1 进 V1）；否则 9/38 并在本文登记缺口 |
| K8 | P0 未关闭数 | 审计 §6 P0 清单中未修复项数 | 审计文档对照 | **8** | ≤4（关闭 P0-4/6/7/8；P0-3 部分关闭：新表策略正确、旧表冻结） |

**反向指标（防指标造假）**：

- **K9 兜底渲染新增数必须为 0**：不允许为了「看起来能玩」而保留静默回落。V1 的方向是消灭兜底，不是包装它。
- **K10 本机榜与「可信」措辞混用 0 次**：`leaderboard.html` 若展示本机数据，页面必须出现「本机记录」字样；任何页面不得用「排行榜/全站/可信」描述本机数据。
- **K11 手工验收替代 0 次**：验收清单里的每一条都必须有脚本。人工只用于 UI 观感，不用于判定通过。

---

## 8. 风险、依赖与开放问题

### 8.1 风险

| ID | 风险 | 触发条件 | 影响 | 缓解 |
|---|---|---|---|---|
| R1 | 验收跑不起来（已发生） | `playwright@1.61.1` 要求 `chromium_headless_shell-1228`，本机缓存只有 `-1248` | A2/A4/A5/A6/A9 全部 `BLOCKED`；V1 无法判定 | `npx playwright install chromium` 后锁版本；CI 与本地同 pin；把「浏览器可启动」做成 A9 的第一条断言 |
| R2 | 线上 schema 与 SQL 文件漂移 | 审计 §2.1：仅用文件回放无法重建线上库 | 迁移可能在线上失败或静默不生效 | 迁移只做新增（`create table if not exists` / `create policy`）；上线前 `supabase db dump` 存档；A1 为端到端验证 |
| R3 | 匿名写口被滥用（两张表） | `game_results` 对 anon 开放 insert；`user_configs` 若加匿名发布策略，则变成公开投递箱 | 垃圾数据、结果不可信、存储成本 | 列级 grant 收紧；A3 做一致性校验；增量阈值（同一 `config_id` 5 分钟 > 50 行 → 记异常，人工看）；发布侧限制 `config_payload` 体积（≤32KB）与奖项数（2–12）；对外措辞限定为「可读」；下一迭代 S3 收口到 Edge Function + 限速 |
| R4 | 合并未提交改动即上线 | `index.html:21` 引用未跟踪的 `player-history.html` | main 死链，违反「`main` 只保持可部署状态」 | 提交顺序固定：被引用文件先提交；A7 的 `git status` 断言作为门禁 |
| R5 | 自定义域名 vs Pages 子路径 | `CNAME = games.jydigtal.com`；子路径部署时根绝对路径全 404（`wheelcut/index.html` 即此问题） | 分享 URL 在子路径下失效 | share URL 只由 `location.origin + location.pathname` 派生（可参考 `leaderboard.js:9-17` 从 `script[src]` 反推 base 的写法）；A2 在子路径下补跑一次 |
| R6 | `.worktrees` 副本污染本地检查 | `check-project.mjs:6` 的 ignored 不含 `.worktrees` | 「277 文件通过」≠ 维护面通过 | M5 顺带给 ignored 加 `.worktrees`、`wheelcut`；报告里分别打印「实际文件数/被检查文件数」 |
| R7 | 一个迭代做不完 | Must 7.5 人日 + 缓冲 9 人日，无余量 | 半成品上线比不做更糟 | 固定削减顺序（§4.3）；M1/M2/M3/M5 不可裁 |
| R8 | 旧链与新链并存导致「两个真相」 | 51 个页面仍写本机榜，`leaderboard.html` 展示本机数据 | 用户看到「榜」但换个设备就没了，仍会觉得被骗 | M4 内容面：所有本机数据区块显式标注「仅本机」；N3 明确不做全站榜直到有身份与反作弊 |

### 8.2 依赖

| ID | 依赖 | 需要什么 | 谁提供 | 风险 |
|---|---|---|---|---|
| D1 | 线上 Supabase 项目 | 可执行迁移；anon key 有效（`supabase.js:7-8` 已硬编码，无需新配） | 你（Dashboard 权限） | 中：R2 |
| D2 | Playwright 浏览器 | 与 `package.json` 版本一致的 chromium | 本地 `npx playwright install` | 高：R1（已发生） |
| D3 | 部署环境 | GitHub Pages + 自定义域可访问，用于真实跨设备验证 | 你 | 低：两个 context 可替代大部分验证 |
| D4 | `SERVICE_ROLE` 仅本地 | fixture 脚本与迁移用，不得入库（`AGENTS.md` 禁止提交密钥） | 你 | 低：只在本地 `.env` |
| D5 | 旧链 fixture slug | 线上已有旧格式 `is_published` 行，或本地用 service_role 造一条 | 你 | 低：A8 可降级为人工确认 |
| D6 | 入口形态决策（Q1） | 一句话决策 + 是否做目录页 | 你 | 中：阻塞 M4 与 S1 |

### 8.3 开放问题（需要你拍板）

| # | 问题 | 选项 | 我的推荐与理由 | 截止 |
|---|---|---|---|---|
| Q1 | 玩家入口是终端、大厅，还是双层？ | A 保留终端（现状）／B 回退大厅（HEAD）／C 双层：`/` 为终端 + `games.html` 为 catalog 目录 | **C**。终端与 product voice（「玩家不可编辑」「分享链接直达」）一致，且服务 P1 用户；但只有终端会让 38 条 catalog 与 51 个计分页面变成死资产，与 AGENTS.md「保持旧版 HTML 游戏可用」冲突。双层成本 ≈ 一个静态页（S1），收益是「不丢资产」 | 迭代第 1 天 |
| Q2 | 匿名发布怎么写？ | A 给 `user_configs` 加匿名 insert 策略（列级 grant）／B 新增 Edge Function `publish-config` | **A**。少一个部署面、少一类新风险（现有两个 Edge Function 都无鉴权，审计 P0-1/P0-2）；代价是匿名发布的配置无 owner、不可编辑、可被刷。S3 在下一迭代收口到 B | 迭代第 1 天 |
| Q3 | 「结果」对外承诺到什么程度？ | A 只承诺「可读」（记录存在）／B 承诺「可信」（不可伪造） | **A**。B 需要服务端复算 + 身份，成本远超 V1；A 需要把信任边界写进注释与文案。K2 的一致性校验是 A 的可观测补偿 | 迭代第 1 天 |
| Q4 | 旧链路（`builder-v2 → play.html`）V1 是否同步收敛？ | A 只读兼容、不动／B 与 V2 合流到同一适配器 | **A**。合流是审计 §9.2「迭代 1」的活，V1 做会炸开 51 个页面；但 A8 必须保证它不被顺手改坏 | 迭代第 1 天 |
| Q5 | Godot 承诺去留？ | A 保留在路线图／B 移出 AGENTS.md 与路线图／C 给出文件级证据期限 | **C→B**：给一个期限（迭代 3 前），到期仍无 `project.godot` + 可玩片段，就把「当前重点 1、2」从 AGENTS.md 移除。保留空承诺的代价是每次评审都要重新讨论同一件事 | 迭代第 3 天 |
| Q6 | `admin.html` 怎么办？ | A 移出部署路径／B 加登录门 | **A**。它是静态样机（`admin.html:1339-1361`），没有真实数据可保护；加门禁等于给样机做安全工程 | 迭代第 5 天 |
| Q7 | `game_results` 与 `play_sessions` 并存可接受吗？ | A 接受，V1 只写新表，旧表冻结／B 合并成一张 | **A**。合并要重做 `play_sessions` 的 RLS 与语义（它绑 `campaign_id`+`player_id`，且匿名读不到自己写的行），风险与工作量都超 V1 | 迭代第 1 天 |
| Q8 | 分享 URL 要不要带 `game` 参数？ | A 带（`play-v2.html?game=wheel&config=ref`，现状）／B 只带 `config`，`game` 由服务端记录推导 | **B（V1 先 A，下一迭代 B）**。现状 A 的问题是 URL 里有冗余真相源，`game` 与配置可能不一致；但 B 需要 `resolve` 先返回 `game_type` 才能路由。V1 保持 A，并在 `resolve` 校验 `game_type` 一致 | 下一迭代 |
| Q9 | 分享页的 `og:*` 元信息与失效兜底文案 | A 不做，纯文本链接／B 由服务端生成 meta（需 Edge Function）／C 客户端静态 meta + 更人话的失效文案 | **C**。链接在 IM 里预览成一张白卡片会直接压低点击率；客户端写死一条通用 `og:title`（如「一个朋友分享的游戏」）成本近零，动态标题留到 S3。失效文案必须同时改（当前那句写给开发者），因为它是用户唯一会看到的失败界面 | 迭代第 3 天 |


### 8.4 交付检查单（DoD）

- [ ] 入口形态已决策并写入文档（Q1 定稿，回写 §8.3）
- [ ] `platform/sharing/supabase-share-service.js` 存在，且被 `create-v2.html`、`play-v2.html` 引用
- [ ] `publish` 返回绝对 URL，`new URL(url).origin === location.origin`
- [ ] `game_results` 迁移已上线，列级 grant 生效（用 anon key 试写 `id` 列应失败）
- [ ] `play-v2.html` 抽奖后写入一条结果，失败时有可见提示（A5）
- [ ] `player-history.html` 支持 `?config=`，服务端区块与本机区块视觉与文案分离
- [ ] `runtime/dom-safe.js` 存在，5 个渲染点全部收口（A6 全绿）
- [ ] `npm run accept` 输出 `PASS 8 / FAIL 0`；`npm run check && test:architecture && test:platform && test:games && check:boundaries` 全绿
- [ ] `node scripts/check-links.mjs` → `dead links: 0`
- [ ] `git status --porcelain` 为空（发布分支 tip）
- [ ] CI 接线：`check` → 4 个 npm script → `playwright install`（带版本 pin）→ `test:smoke` → `accept`
- [ ] 文档：入口决策、`game_results` 信任边界、「仅本机」标注口径，各有一句话记录
- [ ] `og:title` 已存在（Q9-C），失效兜底文案已改成玩家能懂的一句话
- [ ] 未做项已登记：Godot（Q5）、全站榜、账号历史、反作弊、发奖（§5）

---

## 附：本文与审计报告的分工

审计报告回答「哪里坏了、按什么顺序修」。本文回答「V1 承诺什么、怎么判定做到了」。两者冲突时：**范围以本文为准，技术事实以审计报告为准**；若审计的某条 P0 不在本文 Must 里，是因为它不阻塞 V1 命题（如 P0-1 的 `create-client-user` 无人调用、P0-2 的 `ai-config` 不在玩家路径上），而不是因为它不重要——它们在 §5 与 K8 里有明确归属与时点。
