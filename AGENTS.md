# GameHub 协作说明

## 项目定位

GameHub 是一个以静态网页小游戏为基础、逐步加入 Godot 旗舰游戏和 Supabase 后端的游戏平台。

## 技术边界

- 现有大厅、管理后台和普通小游戏继续使用原生 HTML、CSS、JavaScript。
- Godot 用于大转盘、大富翁、飞行棋、消消乐等需要更强动画、音效和粒子效果的游戏。
- Supabase 负责认证、配置、排行榜、游戏结果和 Edge Functions。
- 不要为了普通页面引入大型前端框架或构建链。

## 协作约定

- 所有注释、文档和提交信息使用中文。
- `main` 只保持可部署状态。
- 新功能使用独立分支，提交保持小而明确。
- 前端和 Godot 改动必须保留现有 Supabase 接口兼容性。
- 不要提交密钥、`.env`、Supabase 临时文件、Godot `.godot` 缓存和本地截图。
- 修改线上路径时，必须同时检查 GitHub Pages 子路径和自定义域名。

## 当前重点

1. 以大转盘作为 Godot 品质标杆。
2. 建立 Godot 与 `GameHubBridge` 的前后端通信层。
3. 保持旧版 HTML 游戏可用，逐个迁移旗舰游戏。
4. 每次提交至少通过 JavaScript 语法检查和关键页面冒烟测试。
