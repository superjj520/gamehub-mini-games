# GameHub 贡献指南

## 分支

- `main`：线上稳定分支。
- `feature/<名称>`：新功能。
- `fix/<名称>`：问题修复。
- `chore/<名称>`：工具、文档和配置调整。

## 提交

提交信息使用中文，并采用以下前缀：

- `feat:` 新功能
- `fix:` 修复问题
- `refactor:` 重构
- `test:` 测试
- `docs:` 文档
- `chore:` 工具或配置

## 提交前检查

```bash
npm run check
npm run test:smoke
```

涉及 Godot 导出或静态资源时，还要确认没有提交 `.godot/`、导出缓存、密钥和本地测试截图。

## 协作分工

- 前端、Godot 游戏表现和浏览器测试：Codex。
- Supabase、数据库迁移、Edge Functions 和部署脚本：Claude。
- 通过 Git 分支、提交记录和接口文档交接，不直接覆盖对方未提交的改动。
