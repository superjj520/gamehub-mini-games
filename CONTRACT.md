# GameHub 前后端接口契约

> Codex（前端 UI）与 Claude Code（后端引擎/API）的联动规范。
> 两端 Agent 以此文件为共同约定，各自独立开发，通过接口对接。

---

## 1. GameHubBridge — Godot ↔ JS 通信层

### Bridge 暴露给前端的 API

```js
// ─── 发送消息到 Godot ───
GameHubBridge.send(type, payload)  // → void

// ─── 监听 Godot 消息 ───
GameHubBridge.on(type, callback)   // → unsubscribe函数

// ─── 检查 Godot 是否就绪 ───
GameHubBridge.isReady()            // → boolean
```

### 消息类型定义

| type | 方向 | payload | 说明 |
|------|------|---------|------|
| `game:ready` | Godot→JS | `{ version: string }` | Godot 初始化完成 |
| `spin:result` | Godot→JS | `{ prize_index: number, prize_name: string, prize_icon: string }` | 转盘结果 |
| `spin:start` | JS→Godot | `{ config_id?: string }` | 触发转盘旋转 |
| `prize:claim` | JS→Godot | `{ prize_id: string, player_id: string }` | 领取奖品 |
| `config:sync` | JS→Godot | `{ prizes: Prize[], style: object }` | 同步转盘配置 |
| `auth:session` | JS→Godot | `{ player_id: string, token: string }` | 传递登录态 |

### Prize 类型

```ts
interface Prize {
  id: string;
  name: string;
  icon: string;       // emoji 或图标标识
  color: string;      // CSS 颜色值
  weight: number;     // 中奖权重 (0-100)
  type: 'coin' | 'coupon' | 'physical' | 'thanks';
}
```

---

## 2. Supabase 数据接口

### 前端调用模式

```js
// 前端通过 GameSupabase 模块访问后端数据（不直接调用 supabase client）
const result = await GameSupabase.fetchWheelConfig(campaignId);
const prizes = await GameSupabase.claimPrize(spinResult);
```

### 后端暴露的 Supabase 封装

```js
GameSupabase.fetchWheelConfig(campaignId)  // → { prizes: Prize[], style: object }
GameSupabase.claimPrize(spinResult)        // → { success: boolean, prize: Prize }
GameSupabase.getLeaderboard(gameId)        // → { entries: LeaderboardEntry[] }
GameSupabase.submitScore(gameId, score)    // → { rank: number }
```

---

## 3. 设计系统 Token（前端专用）

CSS 变量定义在 `design-system.css`，前端所有页面统一使用。

```css
--gold: #F5C842
--deep: #1A0A2E
--accent: #7C3AED
--accent2: #EC4899
--bg: #0D0720
--surface-1 / --surface-2 / --surface-3
--border-subtle / --border-default / --border-accent
--font-display / --font-body
--radius-sm / --radius-md / --radius-lg / --radius-full
```

---

## 4. 事件总线（后端引擎专用）

```js
// 游戏内部事件（runtime/engine.js 管理）
GameEngine.on('game:start', callback)
GameEngine.on('game:end', callback)
GameEngine.on('score:update', callback)
GameEngine.emit('effect:play', { type, target })
```

---

## 5. 文件边界

| Agent | 可修改范围 |
|-------|-----------|
| **Codex（前端）** | `*.html`、`design-system.css`、`mobile.css`、`wheelcut/`（Godot UI 导出） |
| **Claude Code（后端）** | `runtime/`、`supabase.js`、`auth-player.js`、`reporter.js`、`leaderboard.js`、`share.js`、`achievement.js`、`themes.js`、`sound.js`、`scripts/` |

**共用文件**（需协调）：`index.html`、`play.html`、`game-wrapper.html`——由 Claude Code 定义 API 签名后 Codex 进行 UI 实现。

---

*最后更新：启动双 Agent 协作时创建*
