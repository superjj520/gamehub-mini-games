## 工作边界

你只负责**前端（HTML/CSS/视觉）**。不要修改以下后端文件：

- `runtime/` 目录下所有 .js 文件
- `supabase.js`, `auth-player.js`, `reporter.js`, `leaderboard.js`, `achievement.js`, `user.js`
- `share.js`, `sound.js`, `themes.js`, `invite.js`
- `scripts/` 目录

## 设计标准

- 所有页面使用 `design-system.css` 的 CSS 变量
- 深色主题：背景 `#0D0720`，文字 `#F0EAF8`
- 统一导航栏：logo + 首页/排行榜/商城/个人中心
- 每个页面引入 `runtime/bridge.js`

## 接口契约

与后端通信通过 `CONTRACT.md` 定义的 API：
- GameHubBridge.send(type, payload)
- GameHubBridge.on(type, callback)
- GameSupabase.getCurrentPlayer() 等

## 协作约定

- 所有注释、文档和提交信息使用中文
- 不引入大型前端框架或构建链
- 保持原有 JS 逻辑不变，只升级视觉
