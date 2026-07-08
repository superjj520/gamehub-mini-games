# GameHub 后端基础设施设计文档

**日期**：2026-07-08
**阶段**：第1步，共5步
**状态**：待实现

---

## 背景与目标

GameHub 当前是纯前端静态站点，数据存在用户浏览器 localStorage。为了对外卖服务（客户自助配置游戏活动 + 查看数据），需要引入后端基础设施。

本文档设计第1步：后端基础，包括 Supabase 接入、认证体系、数据库设计、前端改造范围。

---

## 架构方案

**方案C：Supabase 全托管 + 边界处 Cloudflare Workers**

- 前端直接调 Supabase JS SDK（认证、数据读写）
- 仅短信验证码发送走 Cloudflare Workers（保护阿里云 SMS Key 不暴露前端）
- 部署仍在 Cloudflare Pages，零服务器运维

```
玩家浏览器
  ├── 游戏逻辑 → localStorage（离线可用）
  ├── 数据上报 → Supabase（在线时同步）
  └── 手机验证 → Cloudflare Workers → 阿里云SMS → Supabase Auth

客户浏览器
  └── admin-client.html → Supabase Auth + DB

你的浏览器
  └── admin-you.html → Supabase Auth + DB（admin权限）
```

---

## 数据库表结构

### clients（客户）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | uuid | 主键 |
| name | text | 客户公司名 |
| email | text | 登录邮箱，唯一 |
| plan | text | 套餐：free / pro |
| created_at | timestamptz | 创建时间 |

### campaigns（活动）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | uuid | 主键 |
| client_id | uuid | → clients.id |
| game_type | text | wheel / scratch / quiz 等 |
| config | jsonb | 游戏配置（奖品/规则/皮肤） |
| title | text | 活动名称 |
| status | text | draft / active / ended |
| starts_at | timestamptz | 活动开始时间 |
| ends_at | timestamptz | 活动结束时间 |
| created_at | timestamptz | 创建时间 |

### players（玩家）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | uuid | 主键 |
| phone | text | 手机号，唯一 |
| created_at | timestamptz | 首次参与时间 |

### play_sessions（游戏流水，保留90天）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | uuid | 主键 |
| campaign_id | uuid | → campaigns.id |
| player_id | uuid | → players.id |
| score | int | 得分 |
| result | text | 中奖奖品名 / 未中 |
| played_at | timestamptz | 游戏时间 |

### campaign_stats（汇总统计，永久保留）
| 字段 | 类型 | 说明 |
|------|------|------|
| campaign_id | uuid | → campaigns.id |
| date | date | 按天汇总 |
| plays | int | 当日参与次数 |
| winners | int | 当日中奖次数 |
| unique_players | int | 当日独立玩家数 |

### Row Level Security 规则
- 客户只能读写自己的 campaigns / campaign_stats（client_id = auth.uid()）
- 玩家只能读写自己的 play_sessions（player_id = auth.uid()）
- Admin（你）绕过所有 RLS，看全部数据

---

## 认证流程

### 角色一：你（Admin）
- 直接用 Supabase Dashboard 登录管理
- 打开 admin-you.html 用邮箱密码登录（Supabase Auth，admin 角色）

### 角色二：客户
```
打开 admin-client.html
→ 输入邮箱 + 密码（由你创建账号后发给客户）
→ Supabase Auth 邮箱认证
→ 进入客户后台
   ├── 查看活动数据和中奖记录
   ├── 修改活动配置
   └── 生成新游戏链接
→ 客户可自行修改密码
```

### 角色三：玩家
```
打开游戏链接（如 wheel.html?c=xxx&cid=CAMPAIGN_ID）
→ auth-player.js 检查 localStorage 是否有已登录手机号
→ 无 → 弹出手机号输入框
   → 用户输入手机号
   → 调 Cloudflare Workers /api/sms/send
   → Workers 调阿里云 SMS 发验证码
   → 用户输入验证码 → Workers 验证
   → Supabase upsert players 表
   → 写 localStorage player_token
→ 有 → 直接进入游戏
→ 游戏结束 → reporter.js 上报 play_sessions
```

---

## 前端改造范围

### 新增文件（6个）

**supabase.js**
- Supabase JS SDK 初始化
- 公共方法：getCurrentPlayer(), isLoggedIn(), logout()
- 所有页面引入此文件

**auth-player.js**
- 玩家手机号验证弹窗组件
- 流程：输入手机号 → 发验证码 → 输入验证码 → 完成
- 自动注入到引入了 supabase.js 的游戏页面

**reporter.js**
- 游戏结果上报模块
- 拦截现有 `GameLeaderboard.submitAndNotify()` 调用
- 同时写 localStorage（离线兼容）+ Supabase play_sessions
- 自动聚合更新 campaign_stats（每日汇总）

**admin-client.html**
- 客户后台页面
- 功能：登录 / 活动列表 / 数据图表 / 配置编辑 / 生成链接

**admin-you.html**
- 你的管理后台
- 功能：客户管理 / 全局数据 / 创建活动 / 账号管理

**workers/sms.js**
- Cloudflare Workers 部署
- 路由：POST /api/sms/send（发验证码）、POST /api/sms/verify（验证）
- 阿里云 SMS Key 存在 Workers 环境变量，不暴露前端

### 改动现有文件（3个）

**user.js**
- 新增：页面加载时检查 localStorage player_token
- 已登录则跳过手机号验证弹窗

**leaderboard.js**
- 新增：submitAndNotify() 中调用 reporter.js 上报到 Supabase
- 保持原有 localStorage 逻辑不变（向后兼容）

**builder.html**
- 新增：生成链接时同步写入 campaigns 表
- 链接中附加 `&cid=CAMPAIGN_ID` 参数
- 需要客户登录状态才能保存配置

### 不改动（51个游戏文件 + 其他页面）
所有游戏 HTML 文件、index.html、shop.html、leaderboard.html 等保持原样。reporter.js 通过拦截 leaderboard.js 的上报钩子自动工作，无需修改游戏文件。

---

## 数据保留策略

| 数据类型 | 保留策略 | 原因 |
|---------|---------|------|
| clients / campaigns | 永久 | 核心业务数据 |
| campaign_stats | 永久 | 客户需要回看历史趋势 |
| play_sessions | 90天滚动删除 | 明细量大但价值低，Supabase 免费额度管理 |
| players | 永久 | 跨活动身份一致性 |

Supabase 免费套餐：500MB 存储，50万行。按千人级活动估算，90天流水约10万行，完全覆盖。

---

## 实现顺序（第1步内部）

1. Supabase 项目创建，建表，配置 RLS
2. Cloudflare Workers 部署（sms.js），接入阿里云SMS
3. supabase.js + auth-player.js 开发
4. reporter.js 开发，接入 leaderboard.js
5. admin-you.html 开发（你的后台）
6. admin-client.html 开发（客户后台）
7. builder.html 改造（写入 campaigns 表）

---

## 待确认事项

- 阿里云 SMS 签名和模板需提前申请（需企业资质或个人实名）
- Supabase 项目 URL 和 anon key 确定后填入 supabase.js
- Cloudflare Workers 路由域名（如 api.jydigtal.com）需在 Cloudflare 配置

---

*下一步：写实现计划（writing-plans）*
