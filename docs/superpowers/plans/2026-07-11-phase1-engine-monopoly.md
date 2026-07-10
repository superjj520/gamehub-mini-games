# Phase 1：引擎 + 大富翁样板 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 搭建 GameHub 2.0 通用游戏引擎，实现 9 种 Block 核心模块，将大富翁重构为 Block 驱动，交付画布编辑器和 AI 配置助手，实现用户创建→编辑→分享→游玩的完整闭环。

**架构：** 1 个通用引擎 (engine.js) + 9 个 Block 核心模块 (runtime/core/) + 1 个游戏逻辑文件 (runtime/games/monopoly.js) + 1 个创作工坊页面 (builder-v2.html) + 1 个玩家页面 (play.html) + 2 个 Supabase 数据表 (user_configs, 改造 play_sessions)。

**技术栈：** 原生 JS（无构建工具）、Supabase（PostgreSQL + Auth）、Canvas 渲染、HTML/CSS 原生组件。

## 全局约束

- 所有代码使用原生 JavaScript，ES6+ 语法
- 不引入任何构建工具或框架
- 使用现有 Supabase 客户端 (`supabase.js`) 和认证系统 (`auth-player.js`)
- CSS 使用 CSS 变量复用现有主题系统 (`themes.js`)
- 遵循不可变数据模式：所有状态更新返回新对象，不修改原对象
- 所有新文件放在 `runtime/` 目录下
- 旧文件保留不动（monopoly.html、builder.html 作为参考）

---

## 文件结构总览

```
gamehub-mini-games/
├── runtime/                          ← 新建目录
│   ├── engine.js                     ← 通用引擎：加载配置、调度Block、事件总线
│   ├── block-registry.js             ← Block 类型注册表 + 默认配置
│   ├── core/
│   │   ├── grid.js                   ← 棋盘渲染器
│   │   ├── collection.js             ← 卡堆/奖池抽选器
│   │   ├── rule.js                   ← 数值规则引擎
│   │   ├── piece.js                  ← 实体控制器
│   │   ├── building.js               ← 建筑系统
│   │   ├── store.js                  ← 商店交易器
│   │   ├── effect.js                 ← 效果触发器
│   │   ├── player.js                 ← 玩家管理器
│   │   └── theme.js                  ← 主题渲染器
│   └── games/
│       └── monopoly.js               ← 大富翁专用逻辑
├── builder-v2.html                   ← 新建：创作工坊（三栏编辑器）
├── play.html                         ← 新建：玩家页面（加载配置→渲染游戏）
├── db/
│   └── migration-v2.sql              ← 新建：数据库迁移脚本
└── supabase/
    └── functions/
        └── ai-config/                ← 新建：AI 配置助手 Edge Function
            └── index.ts
```

---

### Task 1: 数据库迁移

**文件：**
- 创建：`db/migration-v2.sql`

**接口：**
- 产出：`user_configs` 表、`play_sessions` 表新增 `config_id` 字段

- [ ] **Step 1: 编写迁移 SQL**

```sql
-- GameHub 2.0 数据库迁移
-- 执行方式：在 Supabase SQL Editor 中运行

-- 1. 创建 user_configs 表
create table if not exists user_configs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid references players(id) on delete cascade,
  game_type     text not null,
  title         text not null,
  blocks        jsonb not null default '[]',
  is_public     boolean default false,
  is_published  boolean default false,
  share_slug    text unique,
  fork_from     uuid references user_configs(id),
  plays_count   integer default 0,
  version       integer default 1,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- 2. 为 play_sessions 添加 config_id
alter table play_sessions
  add column if not exists config_id uuid references user_configs(id) on delete set null;

-- 3. 索引
create index if not exists idx_user_configs_user_id on user_configs(user_id);
create index if not exists idx_user_configs_game_type on user_configs(game_type);
create index if not exists idx_user_configs_share_slug on user_configs(share_slug);
create index if not exists idx_user_configs_plays on user_configs(plays_count desc);
create index if not exists idx_user_configs_public on user_configs(is_public, is_published);
create index if not exists idx_play_sessions_config on play_sessions(config_id);

-- 4. RLS 策略
alter table user_configs enable row level security;

create policy "所有人可读已发布的配置" on user_configs
  for select using (is_published = true);

create policy "用户管理自己的配置" on user_configs
  for all using (
    auth.role() = 'service_role'
    or user_id in (select id from players where email = auth.email())
  );

-- 5. share_slug 生成函数
create or replace function generate_share_slug()
returns text as $$
declare
  chars text := 'abcdefghijklmnopqrstuvwxyz0123456789';
  result text := '';
  i int;
begin
  for i in 1..8 loop
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  end loop;
  return result;
end;
$$ language plpgsql volatile;
```

- [ ] **Step 2: 在 Supabase SQL Editor 中执行迁移**

打开 Supabase Dashboard → SQL Editor → 粘贴上述 SQL → 点击 Run。
验证：在 Database → Tables 中确认 `user_configs` 表已创建。

- [ ] **Step 3: 提交**

```bash
git add db/migration-v2.sql
git commit -m "feat: GameHub 2.0 数据库迁移 — user_configs 表 + play_sessions 扩展"
```

---

### Task 2: Block 类型注册表

**文件：**
- 创建：`runtime/block-registry.js`

**接口：**
- 产出：
  - `BlockRegistry.TYPES` — 9 种 Block 类型枚举
  - `BlockRegistry.getDefaults(gameType)` — 获取某游戏的默认 Block 列表 + 默认配置
  - `BlockRegistry.getSchema(blockType)` — 获取某 Block 类型的编辑 Schema（字段定义）

- [ ] **Step 1: 编写 Block 注册表**

```javascript
/**
 * Block 类型注册表 — 定义 9 种通用 Block 类型和每个游戏的默认配置
 * 依赖：无（纯数据模块）
 */

const BlockRegistry = (() => {

  // ─── Block 类型定义 ───
  const TYPES = {
    GRID:       'grid',
    COLLECTION: 'collection',
    RULE:       'rule',
    PIECE:      'piece',
    BUILDING:   'building',
    STORE:      'store',
    EFFECT:     'effect',
    PLAYER:     'player',
    THEME:      'theme',
  };

  // ─── 每种 Block 类型的编辑 Schema（用于自动生成配置面板） ───
  const SCHEMAS = {
    grid: {
      label: '棋盘',
      icon: '🗺️',
      fields: [
        { key: 'rows',    label: '行数',   type: 'number', min: 5, max: 15, default: 7 },
        { key: 'cols',    label: '列数',   type: 'number', min: 5, max: 15, default: 7 },
        { key: 'cells',   label: '格子列表', type: 'cell-list' },
      ],
    },
    collection: {
      label: '卡堆/奖池',
      icon: '🎲',
      fields: [
        { key: 'drawMode', label: '抽选模式', type: 'select', options: ['random', 'weighted', 'sequential'], default: 'random' },
        { key: 'cards',    label: '条目列表',  type: 'card-list' },
      ],
    },
    rule: {
      label: '规则',
      icon: '📐',
      fields: [
        { key: 'variables', label: '变量定义', type: 'variable-list' },
      ],
    },
    piece: {
      label: '棋子/实体',
      icon: '🧩',
      fields: [
        { key: 'pieces', label: '棋子列表', type: 'piece-list' },
      ],
    },
    building: {
      label: '建筑',
      icon: '🏗️',
      fields: [
        { key: 'buildings', label: '建筑类型', type: 'building-list' },
      ],
    },
    store: {
      label: '商店',
      icon: '🏪',
      fields: [
        { key: 'currency', label: '货币类型', type: 'text', default: 'gold' },
        { key: 'items',    label: '商品列表', type: 'store-item-list' },
      ],
    },
    effect: {
      label: '效果/事件',
      icon: '⚡',
      fields: [
        { key: 'effects', label: '效果列表', type: 'effect-list' },
      ],
    },
    player: {
      label: '玩家设置',
      icon: '👥',
      fields: [
        { key: 'minPlayers',  label: '最少玩家',  type: 'number', min: 1, max: 10, default: 2 },
        { key: 'maxPlayers',  label: '最多玩家',  type: 'number', min: 1, max: 10, default: 4 },
        { key: 'initialGold', label: '初始金币',  type: 'number', min: 0, max: 99999, default: 1500 },
      ],
    },
    theme: {
      label: '主题',
      icon: '🎨',
      fields: [
        { key: 'preset',  label: '预设主题', type: 'select', options: ['经典都市', '赛博朋克', '童话王国', '暗金', '暗紫', '暗绿', '暗蓝'], default: '暗紫' },
        { key: 'accent',  label: '强调色',   type: 'color', default: '#7C3AED' },
        { key: 'accent2', label: '辅助色',   type: 'color', default: '#EC4899' },
        { key: 'gold',    label: '金色',     type: 'color', default: '#F5C842' },
      ],
    },
  };

  // ─── 大富翁默认 Block 配置 ───
  const MONOPOLY_DEFAULTS = [
    {
      id: 'blk_board',
      type: 'grid',
      label: '棋盘',
      config: {
        rows: 7, cols: 7,
        cells: [
          { index: 0,  type: 'start',    name: '起点',     icon: '🚩', effect: { gold: 200 } },
          { index: 1,  type: 'property', name: '奶茶铺',   icon: '🧋', price: 200,  rent: [50, 100, 200] },
          { index: 2,  type: 'chance',   name: '机会',     icon: '❓', effect: { draw: 'chance' } },
          { index: 3,  type: 'property', name: '服装店',   icon: '👗', price: 300,  rent: [80, 160, 320] },
          { index: 4,  type: 'jail',     name: '监禁',     icon: '🚔', effect: { skip: 1 } },
          { index: 5,  type: 'property', name: '美妆店',   icon: '💄', price: 250,  rent: [60, 120, 240] },
          { index: 6,  type: 'destiny',  name: '命运',     icon: '🔮', effect: { draw: 'destiny' } },
          { index: 7,  type: 'property', name: '数码店',   icon: '📱', price: 350,  rent: [90, 180, 360] },
          { index: 8,  type: 'shop',     name: '商铺街',   icon: '🏪', effect: { shop_reward: true } },
          { index: 9,  type: 'property', name: '咖啡馆',   icon: '☕', price: 200,  rent: [50, 100, 200] },
          { index: 10, type: 'chance',   name: '机会',     icon: '❓', effect: { draw: 'chance' } },
          { index: 11, type: 'property', name: '餐饮店',   icon: '🍜', price: 400,  rent: [100, 200, 400] },
          { index: 12, type: 'event',    name: '幸运日',   icon: '🌈', effect: { gold: 100 } },
          { index: 13, type: 'property', name: '游戏馆',   icon: '🎮', price: 280,  rent: [70, 140, 280] },
          { index: 14, type: 'destiny',  name: '命运',     icon: '🔮', effect: { draw: 'destiny' } },
          { index: 15, type: 'property', name: '健身房',   icon: '🏋️', price: 320,  rent: [80, 160, 320] },
          { index: 16, type: 'chance',   name: '机会',     icon: '❓', effect: { draw: 'chance' } },
          { index: 17, type: 'property', name: '珠宝店',   icon: '💎', price: 500,  rent: [150, 300, 500] },
          { index: 18, type: 'event',    name: '税务',     icon: '💰', effect: { gold: -100 } },
          { index: 19, type: 'property', name: '黄金城',   icon: '👑', price: 600,  rent: [200, 400, 600] },
          { index: 20, type: 'chance',   name: '机会',     icon: '❓', effect: { draw: 'chance' } },
          { index: 21, type: 'property', name: '银行',     icon: '🏦', price: 450,  rent: [120, 240, 480] },
          { index: 22, type: 'destiny',  name: '命运',     icon: '🔮', effect: { draw: 'destiny' } },
          { index: 23, type: 'property', name: '庄园',     icon: '🏰', price: 700,  rent: [250, 500, 700] },
        ],
      },
    },
    {
      id: 'blk_chance',
      type: 'collection',
      label: '机会卡',
      config: {
        drawMode: 'random',
        cards: [
          { id: 'c1', title: '获得 50 金币 🎉',  effect: { gold: 50 } },
          { id: 'c2', title: '前进 3 格 ➡️',      effect: { move: 3 } },
          { id: 'c3', title: '后退 2 格 ⬅️',      effect: { move: -2 } },
          { id: 'c4', title: '获得优惠券 🎫',     effect: { gold: 30, prize: '优惠券' } },
          { id: 'c5', title: '停一回合 ⏸️',       effect: { skip: 1 } },
        ],
      },
    },
    {
      id: 'blk_destiny',
      type: 'collection',
      label: '命运卡',
      config: {
        drawMode: 'random',
        cards: [
          { id: 'd1', title: '获得 100 金币 💰',   effect: { gold: 100 } },
          { id: 'd2', title: '领取神秘礼盒 🎁',     effect: { gold: 60, prize: '神秘礼盒' } },
          { id: 'd3', title: '与对手交换位置 🔄',   effect: { swap: true } },
          { id: 'd4', title: '获得抽奖机会 🎰',     effect: { gold: 80, lucky_draw: true } },
        ],
      },
    },
    {
      id: 'blk_store',
      type: 'store',
      label: '建筑商店',
      config: {
        currency: 'gold',
        items: [
          { id: 'apt',  name: '公寓', cost: 200,  effect: { rent_multiplier: 2, icon: '🏠' } },
          { id: 'mall', name: '商场', cost: 500,  effect: { rent_multiplier: 5, icon: '🏬' } },
          { id: 'hotel',name: '酒店', cost: 1000, effect: { rent_multiplier: 10, icon: '🏨' } },
        ],
      },
    },
    {
      id: 'blk_effects',
      type: 'effect',
      label: '事件效果',
      config: {
        effects: [
          { id: 'e1', trigger: 'land_on', cellType: 'start',    action: 'add_gold',     value: 200 },
          { id: 'e2', trigger: 'land_on', cellType: 'jail',     action: 'skip_turns',   value: 1 },
          { id: 'e3', trigger: 'land_on', cellType: 'shop',     action: 'shop_reward',  value: 0 },
          { id: 'e4', trigger: 'land_on', cellType: 'event',    action: 'luck_bonus',   value: 100 },
          { id: 'e5', trigger: 'land_on', cellType: 'tax',      action: 'deduct_gold',  value: -100 },
          { id: 'e6', trigger: 'pass_start',                    action: 'add_gold',     value: 200 },
        ],
      },
    },
    {
      id: 'blk_rules',
      type: 'rule',
      label: '游戏规则',
      config: {
        variables: [
          { key: 'initialGold',    label: '初始金币',      value: 1500, min: 100,  max: 10000 },
          { key: 'startBonus',     label: '经过起点奖励',   value: 200,  min: 0,    max: 1000  },
          { key: 'bankruptLimit',  label: '破产线',         value: 0,    min: -500, max: 500   },
          { key: 'maxLaps',        label: '获胜圈数',       value: 5,    min: 1,    max: 20    },
          { key: 'diceMin',        label: '骰子最小值',      value: 1,    min: 1,    max: 3     },
          { key: 'diceMax',        label: '骰子最大值',      value: 6,    min: 4,    max: 12    },
        ],
      },
    },
    {
      id: 'blk_players',
      type: 'player',
      label: '玩家设置',
      config: {
        minPlayers: 2,
        maxPlayers: 4,
        players: [
          { id: 'p1', name: '玩家 A', emoji: '🧑', isAI: false, color: '#7C3AED' },
          { id: 'p2', name: '玩家 B', emoji: '🤖', isAI: true,  color: '#EC4899' },
        ],
      },
    },
    {
      id: 'blk_theme',
      type: 'theme',
      label: '视觉主题',
      config: {
        preset: '暗紫',
        accent:  '#7C3AED',
        accent2: '#EC4899',
        gold:    '#F5C842',
      },
    },
  ];

  // ─── 获取默认配置 ───
  function getDefaults(gameType) {
    const defaults = {
      monopoly: JSON.parse(JSON.stringify(MONOPOLY_DEFAULTS)),
    };
    return defaults[gameType] || [];
  }

  // ─── 获取 Block 编辑 Schema ───
  function getSchema(blockType) {
    return SCHEMAS[blockType] || null;
  }

  // ─── 创建新 Block 实例 ───
  function createBlock(type, overrides = {}) {
    const schema = SCHEMAS[type];
    if (!schema) return null;

    const id = 'blk_' + Math.random().toString(36).slice(2, 8);
    const config = {};

    // 从 schema 字段中提取默认值
    for (const field of (schema.fields || [])) {
      if (field.default !== undefined) {
        config[field.key] = field.default;
      }
    }

    return {
      id,
      type,
      label: schema.label,
      config: { ...config, ...overrides },
    };
  }

  return { TYPES, SCHEMAS, getDefaults, getSchema, createBlock };
})();
```

- [ ] **Step 2: 验证 Block 注册表**

在浏览器 Console 中测试（在任意项目 HTML 页面引入 `block-registry.js` 后）：

```javascript
// 测试获取大富翁默认配置
const defaults = BlockRegistry.getDefaults('monopoly');
console.assert(defaults.length === 8, '大富翁应有 8 个默认 Block');
console.assert(defaults[0].type === 'grid', '第一个 Block 应为棋盘');
console.assert(defaults[1].type === 'collection', '第二个 Block 应为卡堆');

// 测试创建 Block
const block = BlockRegistry.createBlock('grid', { rows: 10 });
console.assert(block.type === 'grid', '新 Block 类型应为 grid');
console.assert(block.config.rows === 10, '新 Block 行数应为 10');
console.assert(block.id.startsWith('blk_'), 'Block ID 应以 blk_ 开头');

// 测试 Schema
const schema = BlockRegistry.getSchema('grid');
console.assert(schema.label === '棋盘', 'grid schema 标签应为棋盘');
console.assert(schema.fields.length >= 2, 'grid schema 至少应有 2 个字段');
```

- [ ] **Step 3: 提交**

```bash
git add runtime/block-registry.js
git commit -m "feat: Block 类型注册表 — 9 种 Block 定义 + 大富翁默认配置 + 编辑 Schema"
```

---

### Task 3: 核心模块 — theme.js

**文件：**
- 创建：`runtime/core/theme.js`

**接口：**
- 产出：`ThemeRenderer.apply(config)` — 将主题配置应用到 document，返回 CSS 变量字符串
- 产出：`ThemeRenderer.getPresets()` — 获取所有预设主题

- [ ] **Step 1: 编写 theme.js**

```javascript
/**
 * 主题渲染器 — 将 Theme Block 配置应用到页面
 * 依赖：无
 */

const ThemeRenderer = (() => {

  const PRESETS = {
    '暗紫': { accent: '#7C3AED', accent2: '#EC4899', bg: '#0D0720', deep: '#1A0A2E', card: 'rgba(124,58,237,0.07)', gold: '#F5C842', text: '#F0EAF8', muted: 'rgba(240,234,248,0.5)' },
    '暗金': { accent: '#D97706', accent2: '#F59E0B', bg: '#0C0A00', deep: '#1A1200', card: 'rgba(251,191,36,0.07)', gold: '#FDE68A', text: '#FEF9EC', muted: 'rgba(254,249,236,0.5)' },
    '暗绿': { accent: '#059669', accent2: '#10B981', bg: '#020F0A', deep: '#041A10', card: 'rgba(16,185,129,0.07)', gold: '#6EE7B7', text: '#ECFDF5', muted: 'rgba(236,253,245,0.5)' },
    '暗蓝': { accent: '#2563EB', accent2: '#3B82F6', bg: '#020817', deep: '#0A1628', card: 'rgba(59,130,246,0.07)', gold: '#93C5FD', text: '#EFF6FF', muted: 'rgba(239,246,255,0.5)' },
    '经典都市': { accent: '#6366F1', accent2: '#EC4899', bg: '#0F0F23', deep: '#1A1A2E', card: 'rgba(99,102,241,0.08)', gold: '#F59E0B', text: '#E2E8F0', muted: 'rgba(226,232,240,0.5)' },
    '赛博朋克': { accent: '#06B6D4', accent2: '#F43F5E', bg: '#0A0A0A', deep: '#111111', card: 'rgba(6,182,212,0.08)', gold: '#FBBF24', text: '#E0F2FE', muted: 'rgba(224,242,254,0.5)' },
    '童话王国': { accent: '#EC4899', accent2: '#8B5CF6', bg: '#1A0A2E', deep: '#2D1B4E', card: 'rgba(236,72,153,0.08)', gold: '#FDE047', text: '#FCE7F3', muted: 'rgba(252,231,243,0.5)' },
  };

  /**
   * 应用主题配置
   * @param {object} config — Theme Block 的 config 对象
   *   { preset: string, accent: string, accent2: string, gold: string }
   */
  function apply(config = {}) {
    const preset = PRESETS[config.preset] || PRESETS['暗紫'];

    const vars = {
      '--accent':  config.accent  || preset.accent,
      '--accent2': config.accent2 || preset.accent2,
      '--gold':    config.gold    || preset.gold,
      '--bg':      preset.bg,
      '--deep':    preset.deep,
      '--card':    preset.card,
      '--text':    preset.text,
      '--muted':   preset.muted,
      '--border':  'rgba(255,255,255,0.1)',
    };

    // 应用到 :root
    const root = document.documentElement;
    for (const [key, value] of Object.entries(vars)) {
      root.style.setProperty(key, value);
    }

    return vars;
  }

  function getPresets() {
    return Object.keys(PRESETS);
  }

  return { apply, getPresets, PRESETS };
})();
```

- [ ] **Step 2: 提交**

```bash
git add runtime/core/theme.js
git commit -m "feat: ThemeRenderer — 主题 Block 渲染器，7 种预设主题"
```

---

### Task 4: 核心模块 — rule.js

**文件：**
- 创建：`runtime/core/rule.js`

**接口：**
- 产出：`RuleEngine.init(variables)` — 初始化游戏全局变量，返回不可变状态对象
- 产出：`RuleEngine.get(state, key)` — 获取变量值
- 产出：`RuleEngine.set(state, key, value)` — 设置变量值（返回新状态）
- 产出：`RuleEngine.incr(state, key, delta)` — 增减变量值（返回新状态）

- [ ] **Step 1: 编写 rule.js**

```javascript
/**
 * 数值规则引擎 — 管理游戏全局变量
 * 依赖：无
 * 原则：所有操作返回新状态对象，不修改原状态（不可变性）
 */

const RuleEngine = (() => {

  /**
   * 从 Rule Block 配置初始化游戏状态
   * @param {Array} variables — Rule Block config.variables 数组
   *   [{ key: 'initialGold', value: 1500 }, ...]
   * @returns {object} 不可变状态 { values: { key: value }, history: [] }
   */
  function init(variables = []) {
    const values = {};
    for (const v of variables) {
      values[v.key] = v.value;
    }
    return {
      values: { ...values },
      history: [],
    };
  }

  function get(state, key) {
    return state.values[key];
  }

  function set(state, key, value) {
    if (state.values[key] === value) return state;
    const newValues = { ...state.values, [key]: value };
    const newHistory = [...state.history, { key, from: state.values[key], to: value, ts: Date.now() }];
    return { values: newValues, history: newHistory.slice(-100) }; // 只保留最近 100 条
  }

  function incr(state, key, delta) {
    const current = state.values[key] || 0;
    return set(state, key, current + delta);
  }

  function getAll(state) {
    return { ...state.values };
  }

  return { init, get, set, incr, getAll };
})();
```

- [ ] **Step 2: 提交**

```bash
git add runtime/core/rule.js
git commit -m "feat: RuleEngine — 数值规则引擎，不可变状态管理"
```

---

### Task 5: 核心模块 — collection.js

**文件：**
- 创建：`runtime/core/collection.js`

**接口：**
- 产出：`CollectionManager.draw(config)` — 从卡堆/奖池中抽取一条（返回卡片对象）
- 产出：`CollectionManager.addCard(config, card)` — 添加卡片（返回新 config）
- 产出：`CollectionManager.removeCard(config, cardId)` — 删除卡片（返回新 config）

- [ ] **Step 1: 编写 collection.js**

```javascript
/**
 * 卡堆/奖池抽选器 — 支持随机均匀、按权重、顺序循环三种模式
 * 依赖：无
 */

const CollectionManager = (() => {

  /**
   * 抽选
   * @param {object} config — Collection Block 的 config
   *   { drawMode: 'random'|'weighted'|'sequential', cards: [...] }
   * @param {object} state — 可选，顺序模式下需要上次抽到的 index
   * @returns {{ card: object, state: object }} 抽到的卡片和更新后的状态
   */
  function draw(config, state = {}) {
    const { drawMode = 'random', cards = [] } = config;
    if (cards.length === 0) return { card: null, state };

    switch (drawMode) {
      case 'random':
        return drawRandom(cards, state);
      case 'weighted':
        return drawWeighted(cards, state);
      case 'sequential':
        return drawSequential(cards, state);
      default:
        return drawRandom(cards, state);
    }
  }

  function drawRandom(cards, state) {
    const index = Math.floor(Math.random() * cards.length);
    return { card: cards[index], state: { lastIndex: index } };
  }

  function drawWeighted(cards, state) {
    const totalWeight = cards.reduce((sum, c) => sum + (c.weight || 1), 0);
    let r = Math.random() * totalWeight;
    for (let i = 0; i < cards.length; i++) {
      r -= (cards[i].weight || 1);
      if (r <= 0) {
        return { card: cards[i], state: { lastIndex: i } };
      }
    }
    return { card: cards[cards.length - 1], state: { lastIndex: cards.length - 1 } };
  }

  function drawSequential(cards, state) {
    const lastIndex = (state.lastIndex != null) ? state.lastIndex : -1;
    const nextIndex = (lastIndex + 1) % cards.length;
    return { card: cards[nextIndex], state: { lastIndex: nextIndex } };
  }

  // ─── 不可变增删卡片 ───
  function addCard(config, card) {
    const newCard = { ...card, id: card.id || 'card_' + Math.random().toString(36).slice(2, 8) };
    return {
      ...config,
      cards: [...config.cards, newCard],
    };
  }

  function removeCard(config, cardId) {
    return {
      ...config,
      cards: config.cards.filter(c => c.id !== cardId),
    };
  }

  function updateCard(config, cardId, updates) {
    return {
      ...config,
      cards: config.cards.map(c => c.id === cardId ? { ...c, ...updates } : c),
    };
  }

  return { draw, addCard, removeCard, updateCard };
})();
```

- [ ] **Step 2: 提交**

```bash
git add runtime/core/collection.js
git commit -m "feat: CollectionManager — 卡堆/奖池抽选器，支持随机/权重/顺序三种模式"
```

---

### Task 6: 核心模块 — grid.js

**文件：**
- 创建：`runtime/core/grid.js`

**接口：**
- 产出：`GridRenderer.render(containerEl, config, callbacks)` — 渲染棋盘 DOM
- 产出：`GridRenderer.getCellPosition(gridEl, index, config)` — 获取网格坐标
- 产出：`GridRenderer.updateCell(containerEl, index, updates)` — 更新单个格子

- [ ] **Step 1: 编写 grid.js**

```javascript
/**
 * 棋盘渲染器 — 根据 Grid Block 配置渲染棋盘 DOM
 * 依赖：无
 */

const GridRenderer = (() => {

  /**
   * 渲染棋盘到指定容器
   * @param {HTMLElement} container — 容器元素
   * @param {object} config — Grid Block config { rows, cols, cells }
   * @param {object} callbacks — { onCellClick(index, cell) }
   * @returns {HTMLElement} 棋盘元素
   */
  function render(container, config, callbacks = {}) {
    const { rows = 7, cols = 7, cells = [] } = config;
    const board = document.createElement('div');
    board.className = 'gh-grid-board';
    board.style.cssText = `
      display: grid;
      grid-template-columns: repeat(${cols}, 1fr);
      grid-template-rows: repeat(${rows}, 1fr);
      gap: 2px;
      width: 100%;
      aspect-ratio: ${cols} / ${rows};
    `;

    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        const isBorder = (r === 0 || r === rows - 1 || c === 0 || c === cols - 1);

        if (isBorder) {
          // 计算边框格子的索引（顺时针从左上角开始）
          const index = borderCellIndex(r, c, rows, cols);
          const cellData = cells.find(cd => cd.index === index) || { name: '', icon: '', type: 'empty' };
          const cell = createCell(cellData, index, callbacks.onCellClick);
          board.appendChild(cell);
        } else {
          // 中间区域为空
          const empty = document.createElement('div');
          empty.style.cssText = 'background: transparent;';
          board.appendChild(empty);
        }
      }
    }

    container.innerHTML = '';
    container.appendChild(board);
    return board;
  }

  function borderCellIndex(r, c, rows, cols) {
    // 上边：从左到右
    if (r === 0) return c;
    // 右边：从上到下
    if (c === cols - 1) return (cols - 1) + r;
    // 下边：从右到左
    if (r === rows - 1) return (cols - 1) + (rows - 1) + (cols - 1 - c);
    // 左边：从下到上
    return (cols - 1) + (rows - 1) + (cols - 1) + (rows - 1 - r);
  }

  function createCell(cellData, index, onClick) {
    const cell = document.createElement('div');
    cell.className = 'gh-cell gh-cell-' + (cellData.type || 'empty');
    cell.dataset.index = index;
    cell.style.cssText = `
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      font-size: 10px;
      text-align: center;
      padding: 2px;
      border-radius: 4px;
      cursor: pointer;
      background: var(--card, rgba(255,255,255,0.05));
      border: 1px solid var(--border, rgba(255,255,255,0.1));
      transition: background 0.2s;
      min-height: 0;
      overflow: hidden;
    `;

    // 不同类型底色
    const typeColors = {
      start:    'rgba(34,197,94,0.15)',
      property: 'rgba(124,58,237,0.1)',
      chance:   'rgba(245,200,66,0.1)',
      destiny:  'rgba(236,72,153,0.1)',
      jail:     'rgba(239,68,68,0.1)',
      shop:     'rgba(59,130,246,0.1)',
      event:    'rgba(34,211,238,0.1)',
    };
    cell.style.background = typeColors[cellData.type] || 'var(--card)';

    cell.innerHTML = `
      <span style="font-size:16px;line-height:1">${cellData.icon || ''}</span>
      <span style="font-size:9px;margin-top:1px;line-height:1.1;color:var(--text)">${cellData.name || ''}</span>
    `;

    if (onClick) {
      cell.addEventListener('click', () => onClick(index, cellData));
    }

    return cell;
  }

  /**
   * 获取某个格子在棋盘上的像素坐标
   */
  function getCellPosition(boardEl, index) {
    const cell = boardEl.querySelector(`[data-index="${index}"]`);
    if (!cell) return { x: 0, y: 0 };
    const boardRect = boardEl.getBoundingClientRect();
    const cellRect = cell.getBoundingClientRect();
    return {
      x: cellRect.left - boardRect.left + cellRect.width / 2,
      y: cellRect.top - boardRect.top + cellRect.height / 2,
      width: cellRect.width,
      height: cellRect.height,
    };
  }

  function updateCell(boardEl, index, updates) {
    const cell = boardEl.querySelector(`[data-index="${index}"]`);
    if (!cell) return;
    if (updates.highlight) {
      cell.style.boxShadow = '0 0 8px var(--gold)';
      cell.style.borderColor = 'var(--gold)';
    } else {
      cell.style.boxShadow = '';
      cell.style.borderColor = 'var(--border)';
    }
  }

  function clearHighlights(boardEl) {
    boardEl.querySelectorAll('.gh-cell').forEach(cell => {
      cell.style.boxShadow = '';
      cell.style.borderColor = 'var(--border)';
    });
  }

  return { render, getCellPosition, updateCell, clearHighlights };
})();
```

- [ ] **Step 2: 提交**

```bash
git add runtime/core/grid.js
git commit -m "feat: GridRenderer — 棋盘渲染器，支持任意行列 + 格类型区分 + 高亮"
```

---

### Task 7: 核心模块 — effect.js

**文件：**
- 创建：`runtime/core/effect.js`

**接口：**
- 产出：`EffectEngine.match(config, trigger, context)` — 匹配触发条件，返回匹配的效果列表
- 产出：`EffectEngine.execute(effect, context, ruleState)` — 执行效果，返回 { newRuleState, events }

- [ ] **Step 1: 编写 effect.js**

```javascript
/**
 * 效果触发器 — 条件和动作匹配 + 执行
 * 依赖：RuleEngine（可选，用于数值修改）
 */

const EffectEngine = (() => {

  /**
   * 匹配触发条件
   * @param {object} config — Effect Block config { effects: [...] }
   * @param {string} trigger — 触发类型 'land_on' | 'pass_start' | 'before_roll' | 'game_end'
   * @param {object} context — 上下文 { cellType, player, cellIndex }
   * @returns {Array} 匹配的效果列表
   */
  function match(config, trigger, context = {}) {
    const { effects = [] } = config;
    return effects.filter(e => {
      if (e.trigger !== trigger) return false;
      if (e.cellType && e.cellType !== context.cellType) return false;
      return true;
    });
  }

  /**
   * 执行效果
   * @param {object} effect — 效果定义 { action, value }
   * @param {object} context — { player, cellIndex, gameState }
   * @param {object} ruleState — RuleEngine 状态
   * @returns {{ events: Array<string>, ruleState: object }}
   */
  function execute(effect, context = {}, ruleState = null) {
    const events = [];

    switch (effect.action) {
      case 'add_gold':
        events.push(`💰 +${effect.value} 金币`);
        break;
      case 'deduct_gold':
        events.push(`💸 ${effect.value} 金币`);
        break;
      case 'move':
        events.push(`移动 ${effect.value > 0 ? '前进' : '后退'} ${Math.abs(effect.value)} 格`);
        break;
      case 'skip_turns':
        events.push(`⏸️ 暂停 ${effect.value} 回合`);
        break;
      case 'draw_card':
        events.push(`🃏 抽一张卡`);
        break;
      case 'swap_position':
        events.push(`🔄 交换位置`);
        break;
      case 'lucky_draw':
        events.push(`🎰 获得抽奖机会`);
        break;
      case 'shop_reward':
        events.push(`🏪 商铺奖励`);
        break;
      case 'luck_bonus':
        events.push(`🍀 幸运奖励 +${effect.value}`);
        break;
      default:
        events.push(`触发效果: ${effect.action}`);
    }

    return { events, ruleState };
  }

  return { match, execute };
})();
```

- [ ] **Step 2: 提交**

```bash
git add runtime/core/effect.js
git commit -m "feat: EffectEngine — 效果触发器，条件匹配 + 动作执行"
```

---

### Task 8: 核心模块 — player.js, store.js, building.js, piece.js

**文件：**
- 创建：`runtime/core/player.js`、`runtime/core/store.js`、`runtime/core/building.js`、`runtime/core/piece.js`

这些模块在 Phase 1（大富翁）中功能较轻，先写基础版本。

- [ ] **Step 1: 编写 player.js**

```javascript
/**
 * 玩家管理器
 * 依赖：无
 */

const PlayerManager = (() => {

  function createPlayers(config) {
    const { players = [] } = config;
    return players.map(p => ({
      id: p.id || 'p_' + Math.random().toString(36).slice(2, 6),
      name: p.name || '玩家',
      emoji: p.emoji || '🎮',
      isAI: p.isAI || false,
      color: p.color || '#7C3AED',
      position: 0,
      score: 0,
      gold: config.initialGold || 1500,
      laps: 0,
      skipNext: false,
      prizes: [],
      properties: [],
    }));
  }

  function getCurrentPlayer(players, currentIndex) {
    return players[currentIndex];
  }

  function movePlayer(player, steps, totalCells) {
    const newPos = (player.position + steps + totalCells) % totalCells;
    const lapsGained = Math.floor((player.position + steps) / totalCells);
    return {
      ...player,
      position: newPos,
      laps: player.laps + lapsGained,
    };
  }

  function addGold(player, amount) {
    return { ...player, gold: Math.max(0, player.gold + amount) };
  }

  function addPrize(player, prize) {
    return { ...player, prizes: [...player.prizes, prize] };
  }

  return { createPlayers, getCurrentPlayer, movePlayer, addGold, addPrize };
})();
```

- [ ] **Step 2: 编写 store.js**

```javascript
/**
 * 商店交易器
 * 依赖：无
 */

const StoreManager = (() => {

  function getItems(config) {
    return (config.items || []).map(item => ({ ...item }));
  }

  function canBuy(player, item, currencyKey = 'gold') {
    return player[currencyKey] >= (item.cost || 0);
  }

  function buy(player, item, currencyKey = 'gold') {
    return {
      ...player,
      [currencyKey]: player[currencyKey] - (item.cost || 0),
    };
  }

  return { getItems, canBuy, buy };
})();
```

- [ ] **Step 3: 编写 building.js**

```javascript
/**
 * 建筑系统 — 可建造/升级结构
 * 依赖：无
 */

const BuildingManager = (() => {

  function getBuildingTypes(config) {
    return (config.buildings || []).map(b => ({ ...b }));
  }

  function getLevel(building, level) {
    return {
      cost: building.cost * Math.pow(2, level - 1),
      rentMultiplier: building.effect?.rent_multiplier * level || 1,
    };
  }

  return { getBuildingTypes, getLevel };
})();
```

- [ ] **Step 4: 编写 piece.js**

```javascript
/**
 * 实体控制器 — 棋子定位和移动
 * 依赖：无
 */

const PieceController = (() => {

  function createPieceEl(player, index) {
    const el = document.createElement('div');
    el.id = 'gh-piece-' + index;
    el.className = 'gh-piece';
    el.style.cssText = `
      position: absolute;
      width: 22px; height: 22px;
      border-radius: 50%;
      background: ${player.color};
      border: 2px solid white;
      box-shadow: 0 2px 6px rgba(0,0,0,0.4);
      z-index: 10;
      transition: top 0.3s cubic-bezier(.4,1.3,.6,1), left 0.3s cubic-bezier(.4,1.3,.6,1);
      display: flex; align-items: center; justify-content: center;
      font-size: 12px;
    `;
    el.textContent = player.emoji;
    return el;
  }

  function placePiece(pieceEl, position, offsetX = 0, offsetY = 0) {
    pieceEl.style.top = (position.y - 11 + offsetY) + 'px';
    pieceEl.style.left = (position.x - 11 + offsetX) + 'px';
  }

  function animatePiece(pieceEl, targetPos, duration = 300, offsetX = 0, offsetY = 0) {
    return new Promise(resolve => {
      pieceEl.style.transition = `top ${duration}ms cubic-bezier(.4,1.3,.6,1), left ${duration}ms cubic-bezier(.4,1.3,.6,1)`;
      pieceEl.style.top = (targetPos.y - 11 + offsetY) + 'px';
      pieceEl.style.left = (targetPos.x - 11 + offsetX) + 'px';
      setTimeout(resolve, duration);
    });
  }

  return { createPieceEl, placePiece, animatePiece };
})();
```

- [ ] **Step 5: 提交**

```bash
git add runtime/core/player.js runtime/core/store.js runtime/core/building.js runtime/core/piece.js
git commit -m "feat: PlayerManager/StoreManager/BuildingManager/PieceController — 4 个核心模块基础版"
```

---

### Task 9: 通用引擎 engine.js

**文件：**
- 创建：`runtime/engine.js`

**接口：**
- 产出：`GameEngine.init(config, container)` — 初始化引擎，解析 Block，启动游戏
- 产出：`GameEngine.on(event, callback)` — 事件监听
- 产出：`GameEngine.emit(event, data)` — 触发事件

- [ ] **Step 1: 编写 engine.js**

```javascript
/**
 * GameHub 通用游戏引擎
 * 依赖：所有 runtime/core/*.js（按需加载）+ BlockRegistry
 *
 * 流程：
 *   1. 加载用户配置（blocks JSON）
 *   2. 按 block type 分发到对应核心模块处理
 *   3. 启动游戏专用逻辑（games/xxx.js）
 *   4. 事件总线协调各模块通讯
 */

const GameEngine = (() => {

  let _config = null;
  let _container = null;
  let _listeners = {};
  let _gameModule = null;
  let _ruleState = null;
  let _blockResults = {}; // 每个 block 的处理结果

  // ─── 事件总线 ───
  function on(event, callback) {
    if (!_listeners[event]) _listeners[event] = [];
    _listeners[event].push(callback);
  }

  function off(event, callback) {
    if (!_listeners[event]) return;
    _listeners[event] = _listeners[event].filter(fn => fn !== callback);
  }

  function emit(event, data) {
    (_listeners[event] || []).forEach(fn => {
      try { fn(data); } catch (e) { console.warn('[Engine] 事件处理错误:', event, e); }
    });
  }

  // ─── 初始化 ───
  /**
   * @param {object} config — user_configs 中的完整配置（包含 blocks 数组）
   * @param {HTMLElement} container — 游戏渲染容器
   * @param {object} gameModule — 游戏专用逻辑模块（如 MonopolyGame）
   */
  async function init(config, container, gameModule) {
    _config = config;
    _container = container;
    _gameModule = gameModule;
    _blockResults = {};

    // 1. 按顺序处理每个 Block
    for (const block of (config.blocks || [])) {
      const result = await processBlock(block, container);
      _blockResults[block.id] = result;
      emit('block:processed', { block, result });
    }

    // 2. 初始化规则状态
    const ruleBlock = config.blocks.find(b => b.type === 'rule');
    if (ruleBlock && typeof RuleEngine !== 'undefined') {
      _ruleState = RuleEngine.init(ruleBlock.config.variables || []);
    }

    // 3. 应用主题
    const themeBlock = config.blocks.find(b => b.type === 'theme');
    if (themeBlock && typeof ThemeRenderer !== 'undefined') {
      ThemeRenderer.apply(themeBlock.config);
    }

    // 4. 创建玩家
    const playerBlock = config.blocks.find(b => b.type === 'player');
    let players = [];
    if (playerBlock && typeof PlayerManager !== 'undefined') {
      players = PlayerManager.createPlayers(playerBlock.config);
    }

    // 5. 通知游戏模块启动
    emit('engine:ready', {
      config,
      container,
      blockResults: _blockResults,
      ruleState: _ruleState,
      players,
    });

    // 6. 调用游戏模块的启动函数
    if (gameModule && gameModule.start) {
      await gameModule.start({
        config,
        container,
        blockResults: _blockResults,
        ruleState: _ruleState,
        players,
        engine: { on, emit, getBlockResult, getRuleState, updateRuleState },
      });
    }

    return { players, ruleState: _ruleState };
  }

  // ─── Block 处理分发 ───
  async function processBlock(block, container) {
    const { type, config, id, label } = block;

    switch (type) {
      case 'grid':
        if (typeof GridRenderer !== 'undefined') {
          const gridContainer = document.createElement('div');
          gridContainer.id = 'gh-grid-' + id;
          container.appendChild(gridContainer);
          const board = GridRenderer.render(gridContainer, config);
          return { element: gridContainer, board };
        }
        break;

      case 'collection':
        if (typeof CollectionManager !== 'undefined') {
          return { manager: CollectionManager, config };
        }
        break;

      case 'store':
        if (typeof StoreManager !== 'undefined') {
          return { manager: StoreManager, config };
        }
        break;

      case 'effect':
        if (typeof EffectEngine !== 'undefined') {
          return { engine: EffectEngine, config };
        }
        break;

      case 'building':
        if (typeof BuildingManager !== 'undefined') {
          return { manager: BuildingManager, config };
        }
        break;

      // rule / player / theme 在 init 中统一处理
      case 'rule':
      case 'player':
      case 'theme':
        return { config };

      default:
        return { config };
    }

    return { config };
  }

  // ─── 辅助 ───
  function getBlockResult(blockId) {
    return _blockResults[blockId] || null;
  }

  function getRuleState() {
    return _ruleState;
  }

  function updateRuleState(newState) {
    _ruleState = newState;
    emit('rule:changed', newState);
  }

  function getConfig() {
    return _config;
  }

  return { init, on, off, emit, getBlockResult, getRuleState, updateRuleState, getConfig };
})();
```

- [ ] **Step 2: 提交**

```bash
git add runtime/engine.js
git commit -m "feat: GameEngine — 通用游戏引擎，Block 分发 + 事件总线 + 生命周期"
```

---

### Task 10: 大富翁游戏逻辑 (monopoly.js)

**文件：**
- 创建：`runtime/games/monopoly.js`

**接口：**
- 产出：`MonopolyGame.start(ctx)` — 启动大富翁游戏
- 消费：`GameEngine.init()` 传入的 context（players, ruleState, blockResults, engine）

- [ ] **Step 1: 编写 monopoly.js**

```javascript
/**
 * 大富翁游戏逻辑 — 回合制、掷骰子、棋盘移动、卡牌抽取、建筑
 * 依赖：GameEngine, GridRenderer, CollectionManager, EffectEngine, StoreManager, PieceController, RuleEngine, PlayerManager
 */

const MonopolyGame = (() => {

  let ctx = null;
  let state = null;

  function start(gameCtx) {
    ctx = gameCtx;
    const { players, ruleState, blockResults, engine } = ctx;

    // 初始化游戏状态
    state = {
      players: players.map(p => ({ ...p })),
      currentPlayer: 0,
      round: 1,
      gameOver: false,
      winner: null,
    };

    // 获取棋盘
    const gridResult = Object.values(blockResults).find(r => r.board);
    const boardEl = gridResult?.board;
    const gridContainer = gridResult?.element;

    // 在棋盘上放置棋子
    if (gridContainer && typeof PieceController !== 'undefined') {
      state.pieceEls = [];
      players.forEach((p, i) => {
        const pieceEl = PieceController.createPieceEl(p, i);
        gridContainer.appendChild(pieceEl);
        state.pieceEls.push(pieceEl);
      });
      placeAllPieces();
    }

    // 注册事件监听
    engine.on('roll:dice', handleRollDice);
    engine.on('buy:property', handleBuyProperty);
    engine.on('build:building', handleBuildBuilding);
    engine.on('draw:card', handleDrawCard);

    renderUI();
    emitStatus(`🎲 ${players[0].name} 的回合，请掷骰子`);
  }

  // ─── 掷骰子 ───
  function handleRollDice(data) {
    if (state.gameOver) return;
    const pi = state.currentPlayer;
    const player = state.players[pi];

    if (player.skipNext) {
      player.skipNext = false;
      emitStatus(`${player.emoji} ${player.name} 本回合被跳过`);
      setTimeout(() => nextTurn(), 1200);
      return;
    }

    const ruleCfg = getRuleConfig();
    const diceMin = ruleCfg?.diceMin || 1;
    const diceMax = ruleCfg?.diceMax || 6;
    const steps = Math.floor(Math.random() * (diceMax - diceMin + 1)) + diceMin;

    emitStatus(`🎲 ${player.name} 掷出 ${steps} 点`);

    // 获取棋盘配置
    const gridBlock = ctx.config.blocks.find(b => b.type === 'grid');
    const totalCells = gridBlock?.config?.cells?.length || 24;

    const fromPos = player.position;
    const newPlayer = { ...player };
    newPlayer.position = (fromPos + steps) % totalCells;
    if (fromPos + steps >= totalCells) {
      newPlayer.laps += Math.floor((fromPos + steps) / totalCells);
    }

    // 检查是否经过起点
    if (fromPos + steps >= totalCells) {
      const startBonus = ruleCfg?.startBonus || 200;
      newPlayer.gold += startBonus;
      emitStatus(`🚩 ${player.name} 经过起点 +${startBonus} 金币`);
    }

    // 动画移动
    animateMove(pi, fromPos, steps, () => {
      // 更新状态
      state.players[pi] = newPlayer;

      // 落地格子效果
      const cellData = gridBlock.config.cells.find(c => c.index === newPlayer.position);
      if (cellData) {
        handleLandOnCell(pi, cellData);
      }

      // 检查胜利条件
      const maxLaps = ruleCfg?.maxLaps || 5;
      if (newPlayer.laps >= maxLaps) {
        state.gameOver = true;
        state.winner = newPlayer;
        emitStatus(`🏆 ${newPlayer.name} 获得胜利！`);
        return;
      }

      // AI 自动行动
      if (state.players[state.currentPlayer].isAI && !state.gameOver) {
        setTimeout(() => handleRollDice({}), 1500);
      }
    });
  }

  function handleLandOnCell(pi, cellData) {
    const player = state.players[pi];
    const effectResult = ctx.blockResults;
    const effectConfig = ctx.config.blocks.find(b => b.type === 'effect');

    if (!effectConfig || typeof EffectEngine === 'undefined') return;

    const effects = EffectEngine.match(effectConfig.config, 'land_on', {
      cellType: cellData.type,
      cellIndex: cellData.index,
    });

    for (const effect of effects) {
      switch (effect.action) {
        case 'add_gold':
          state.players[pi] = { ...state.players[pi], gold: state.players[pi].gold + effect.value };
          emitStatus(`💰 ${player.name} +${effect.value} 金币`);
          break;
        case 'deduct_gold':
          state.players[pi] = { ...state.players[pi], gold: Math.max(0, state.players[pi].gold + effect.value) };
          emitStatus(`💸 ${player.name} ${effect.value} 金币`);
          break;
        case 'skip_turns':
          state.players[pi] = { ...state.players[pi], skipNext: true };
          emitStatus(`⏸️ ${player.name} 下回合暂停`);
          break;
        case 'draw_card':
          emitStatus(`🃏 ${player.name} 抽到 ${cellData.type === 'chance' ? '机会' : '命运'}卡`);
          handleDrawCard({ playerIndex: pi, deckType: cellData.type });
          break;
        case 'shop_reward':
          emitStatus(`🏪 ${player.name} 获得商铺奖励`);
          break;
      }
    }

    // 检查地产是否可购买
    if (cellData.type === 'property' && cellData.price) {
      emitStatus(`🏠 ${cellData.name} — 购买价 ${cellData.price} 金币`);
    }
  }

  // ─── 卡牌抽取 ───
  function handleDrawCard({ playerIndex, deckType }) {
    const deckBlock = ctx.config.blocks.find(b =>
      b.type === 'collection' && b.label.includes(deckType === 'chance' ? '机会' : '命运')
    );
    if (!deckBlock) return;

    const result = CollectionManager.draw(deckBlock.config);
    if (!result.card) return;

    const card = result.card;
    emitStatus(`🃏 ${card.title}`);

    if (card.effect?.gold) {
      state.players[playerIndex] = {
        ...state.players[playerIndex],
        gold: Math.max(0, state.players[playerIndex].gold + card.effect.gold),
      };
    }
    if (card.effect?.move) {
      const gridBlock = ctx.config.blocks.find(b => b.type === 'grid');
      const totalCells = gridBlock?.config?.cells?.length || 24;
      const player = state.players[playerIndex];
      const newPos = (player.position + card.effect.move + totalCells) % totalCells;
      animateMove(playerIndex, player.position, card.effect.move, () => {
        state.players[playerIndex] = { ...state.players[playerIndex], position: newPos };
      });
      return; // 动画结束后由回调处理
    }
    if (card.effect?.skip) {
      state.players[playerIndex] = { ...state.players[playerIndex], skipNext: true };
    }
    if (card.effect?.swap) {
      const other = 1 - playerIndex;
      const temp = state.players[playerIndex].position;
      state.players[playerIndex] = { ...state.players[playerIndex], position: state.players[other].position };
      state.players[other] = { ...state.players[other], position: temp };
      placeAllPieces();
      emitStatus(`🔄 交换位置！`);
    }
  }

  // ─── 购买地产 ───
  function handleBuyProperty(data) {
    const pi = state.currentPlayer;
    const player = state.players[pi];
    const gridBlock = ctx.config.blocks.find(b => b.type === 'grid');
    const cellData = gridBlock.config.cells.find(c => c.index === player.position);

    if (!cellData || cellData.type !== 'property') return;
    if (player.gold < cellData.price) {
      emitStatus(`❌ 金币不足，无法购买 ${cellData.name}`);
      return;
    }

    state.players[pi] = {
      ...player,
      gold: player.gold - cellData.price,
      properties: [...player.properties, cellData.index],
    };
    emitStatus(`🏠 ${player.name} 购买了 ${cellData.name}！`);
  }

  // ─── 建造建筑 ───
  function handleBuildBuilding(data) {
    const pi = state.currentPlayer;
    const player = state.players[pi];
    const storeBlock = ctx.config.blocks.find(b => b.type === 'store');
    if (!storeBlock) return;

    const item = storeBlock.config.items.find(i => i.id === data.itemId);
    if (!item) return;
    if (player.gold < item.cost) {
      emitStatus(`❌ 金币不足，无法建造 ${item.name}`);
      return;
    }

    state.players[pi] = {
      ...player,
      gold: player.gold - item.cost,
    };
    emitStatus(`🏗️ ${player.name} 建造了 ${item.name}！`);
  }

  // ─── 回合切换 ───
  function nextTurn() {
    state.currentPlayer = (state.currentPlayer + 1) % state.players.length;
    if (state.currentPlayer === 0) state.round++;
    renderUI();

    if (state.players[state.currentPlayer].isAI) {
      setTimeout(() => handleRollDice({}), 1500);
    } else {
      emitStatus(`🎲 ${state.players[state.currentPlayer].name} 的回合，请掷骰子`);
    }
  }

  // ─── 动画 ───
  function animateMove(playerIdx, fromPos, steps, callback) {
    if (!state.pieceEls) { callback(); return; }

    const gridBlock = ctx.config.blocks.find(b => b.type === 'grid');
    const result = Object.values(ctx.blockResults).find(r => r.board);
    if (!result?.board) { callback(); return; }

    let current = fromPos;
    const totalCells = gridBlock?.config?.cells?.length || 24;
    const idx = 0;
    const pieceEl = state.pieceEls[playerIdx];

    function moveStep() {
      if (idx >= steps) {
        // 清除所有高亮
        if (typeof GridRenderer !== 'undefined') {
          GridRenderer.clearHighlights(result.board);
        }
        callback();
        return;
      }

      current = (current + 1) % totalCells;
      const pos = GridRenderer.getCellPosition(result.board, current);

      if (typeof GridRenderer !== 'undefined') {
        GridRenderer.clearHighlights(result.board);
        GridRenderer.updateCell(result.board, current, { highlight: true });
      }

      if (typeof PieceController !== 'undefined') {
        const offsetY = playerIdx * 6 - 3;
        const offsetX = playerIdx * 10 - 5;
        PieceController.animatePiece(pieceEl, pos, 300, offsetX, offsetY).then(() => {
          idx++;
          moveStep();
        });
      } else {
        idx++;
        moveStep();
      }
    }

    moveStep();
  }

  function placeAllPieces() {
    if (!state.pieceEls) return;
    const result = Object.values(ctx.blockResults).find(r => r.board);
    if (!result?.board) return;

    state.players.forEach((p, i) => {
      const pos = GridRenderer.getCellPosition(result.board, p.position);
      const offsetY = i * 6 - 3;
      const offsetX = i * 10 - 5;
      PieceController.placePiece(state.pieceEls[i], pos, offsetX, offsetY);
    });
  }

  // ─── UI ───
  function renderUI() {
    // 由引擎通知外部 UI 更新
    ctx.engine.emit('monopoly:state', state);
  }

  function emitStatus(msg) {
    ctx.engine.emit('monopoly:status', msg);
  }

  function getRuleConfig() {
    const ruleBlock = ctx.config.blocks.find(b => b.type === 'rule');
    if (!ruleBlock) return {};
    const vars = {};
    (ruleBlock.config.variables || []).forEach(v => { vars[v.key] = v.value; });
    return vars;
  }

  function getState() {
    return state;
  }

  return {
    start,
    getState,
    // 对外暴露的操作接口（供按钮绑定）
    rollDice: () => ctx.engine.emit('roll:dice', {}),
    buyProperty: () => ctx.engine.emit('buy:property', {}),
    buildBuilding: (itemId) => ctx.engine.emit('build:building', { itemId }),
    drawCard: (deckType) => ctx.engine.emit('draw:card', { playerIndex: state?.currentPlayer || 0, deckType }),
  };
})();
```

- [ ] **Step 2: 提交**

```bash
git add runtime/games/monopoly.js
git commit -m "feat: MonopolyGame — Block 驱动的大富翁游戏逻辑"
```

---

### Task 11: 玩家游玩页面 (play.html)

**文件：**
- 创建：`play.html`

**接口：**
- 消费：URL 参数 `?config=share_slug` → 从 Supabase 加载配置 → engine.js 渲染 → monopoly.js 启动

- [ ] **Step 1: 编写 play.html**

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>GameHub · 游玩</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  :root {
    --gold: #F5C842; --bg: #0D0720; --accent: #7C3AED; --accent2: #EC4899;
    --deep: #1A0A2E; --card: rgba(255,255,255,0.05); --border: rgba(255,255,255,0.1);
    --text: #F0EAF8; --muted: rgba(240,234,248,0.5);
  }
  body {
    font-family: -apple-system, 'PingFang SC', 'Microsoft YaHei', sans-serif;
    background: var(--bg); color: var(--text);
    min-height: 100vh; display: flex; flex-direction: column;
  }
  .topbar {
    display: flex; align-items: center; justify-content: space-between;
    padding: 0 20px; height: 52px; border-bottom: 1px solid var(--border);
    background: rgba(13,7,32,0.97); flex-shrink: 0;
  }
  .topbar-title { font-size: 15px; font-weight: 700; }
  .topbar-status { font-size: 13px; color: var(--muted); }
  .game-area {
    flex: 1; display: flex; gap: 0; min-height: 0;
  }
  .game-board {
    flex: 1; padding: 20px; display: flex;
    align-items: center; justify-content: center; overflow: auto;
  }
  .game-board-inner {
    width: 100%; max-width: 600px;
  }
  .game-panel {
    width: 320px; border-left: 1px solid var(--border);
    padding: 16px; overflow-y: auto; background: rgba(255,255,255,0.02);
  }
  .panel-section { margin-bottom: 20px; }
  .panel-title { font-size: 12px; font-weight: 700; color: var(--muted); margin-bottom: 8px; text-transform: uppercase; letter-spacing: 1px; }
  .player-card {
    background: var(--card); border: 1px solid var(--border); border-radius: 10px;
    padding: 12px; margin-bottom: 8px;
  }
  .player-card.active { border-color: var(--gold); }
  .player-name { font-size: 14px; font-weight: 700; margin-bottom: 4px; }
  .player-stats { font-size: 12px; color: var(--muted); display: flex; gap: 12px; }
  .btn {
    padding: 12px 20px; border-radius: 10px; border: none;
    font-size: 15px; font-weight: 700; cursor: pointer; font-family: inherit;
    transition: opacity 0.2s; width: 100%;
  }
  .btn:hover { opacity: 0.85; }
  .btn:disabled { opacity: 0.4; cursor: not-allowed; }
  .btn-primary { background: linear-gradient(135deg, var(--accent), var(--accent2)); color: white; }
  .btn-secondary { background: var(--card); border: 1px solid var(--border); color: var(--text); margin-top: 6px; }
  .status-bar {
    padding: 12px 20px; border-top: 1px solid var(--border);
    background: rgba(255,255,255,0.02); font-size: 14px; flex-shrink: 0;
  }
  .loading {
    display: flex; align-items: center; justify-content: center;
    height: 100vh; font-size: 18px; color: var(--muted);
  }
  @media (max-width: 768px) {
    .game-area { flex-direction: column; }
    .game-panel { width: 100%; border-left: none; border-top: 1px solid var(--border); max-height: 40vh; }
  }
</style>
</head>
<body>

<div id="loading" class="loading">🎮 加载游戏配置中…</div>

<div id="app" style="display:none;flex-direction:column;min-height:100vh">
  <!-- 顶栏 -->
  <div class="topbar">
    <div class="topbar-title" id="gameTitle">—</div>
    <div class="topbar-status">GameHub 2.0</div>
  </div>

  <!-- 游戏区 -->
  <div class="game-area">
    <div class="game-board">
      <div class="game-board-inner" id="boardContainer"></div>
    </div>
    <div class="game-panel" id="sidePanel">
      <div class="panel-section">
        <div class="panel-title">玩家</div>
        <div id="playerList"></div>
      </div>
      <div class="panel-section">
        <button class="btn btn-primary" id="btnRoll" onclick="handleRoll()">🎲 掷骰子</button>
        <button class="btn btn-secondary" id="btnBuy" onclick="handleBuy()">🏠 购买地产</button>
      </div>
    </div>
  </div>

  <!-- 状态栏 -->
  <div class="status-bar" id="statusBar">准备开始…</div>
</div>

<!-- 依赖脚本 -->
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
<script src="supabase.js"></script>
<script src="runtime/block-registry.js"></script>
<script src="runtime/core/theme.js"></script>
<script src="runtime/core/rule.js"></script>
<script src="runtime/core/collection.js"></script>
<script src="runtime/core/grid.js"></script>
<script src="runtime/core/effect.js"></script>
<script src="runtime/core/player.js"></script>
<script src="runtime/core/store.js"></script>
<script src="runtime/core/building.js"></script>
<script src="runtime/core/piece.js"></script>
<script src="runtime/engine.js"></script>
<script src="runtime/games/monopoly.js"></script>

<script>
(async function main() {
  const params = new URLSearchParams(location.search);
  const slug = params.get('config');
  const configId = params.get('cid');

  if (!slug && !configId) {
    document.getElementById('loading').textContent = '❌ 缺少游戏配置参数 (?config=xxx)';
    return;
  }

  // 从 Supabase 加载配置
  let config;
  try {
    let query = GHSupabase.from('user_configs').select('*');
    if (slug) {
      query = query.eq('share_slug', slug);
    } else {
      query = query.eq('id', configId);
    }
    const { data, error } = await query.single();
    if (error) throw error;
    config = data;

    // 更新游玩次数
    await GHSupabase.from('user_configs').update({ plays_count: (data.plays_count || 0) + 1 }).eq('id', data.id);
  } catch (e) {
    document.getElementById('loading').textContent = '❌ 加载失败: ' + e.message;
    return;
  }

  // 显示界面
  document.getElementById('loading').style.display = 'none';
  document.getElementById('app').style.display = 'flex';
  document.getElementById('gameTitle').textContent = config.title || '大富翁';

  // 获取游戏模块
  const gameModule = (config.game_type === 'monopoly') ? MonopolyGame : null;
  if (!gameModule) {
    document.getElementById('statusBar').textContent = '❌ 不支持的游戏类型: ' + config.game_type;
    return;
  }

  // 启动引擎
  const container = document.getElementById('boardContainer');

  GameEngine.on('monopoly:state', (gameState) => {
    renderPlayers(gameState.players, gameState.currentPlayer);
    document.getElementById('btnRoll').disabled = gameState.gameOver;
  });

  GameEngine.on('monopoly:status', (msg) => {
    document.getElementById('statusBar').textContent = msg;
  });

  await GameEngine.init(config, container, gameModule);

  // 初始 UI
  const ctx = { config, container };
  renderPlayers(gameModule.getState().players, 0);
})();

function renderPlayers(players, currentIdx) {
  const html = players.map((p, i) => `
    <div class="player-card ${i === currentIdx ? 'active' : ''}">
      <div class="player-name">${p.emoji} ${p.name} ${p.isAI ? '🤖' : ''}</div>
      <div class="player-stats">
        <span>💰 ${p.gold}</span>
        <span>📍 格${p.position + 1}</span>
        <span>🔄 第${p.laps + 1}圈</span>
      </div>
    </div>
  `).join('');
  document.getElementById('playerList').innerHTML = html;
}

function handleRoll() {
  MonopolyGame.rollDice();
}
function handleBuy() {
  MonopolyGame.buyProperty();
}
</script>
</body>
</html>
```

- [ ] **Step 2: 提交**

```bash
git add play.html
git commit -m "feat: play.html — 玩家游玩页面，加载配置 + 引擎渲染 + 交互操作"
```

---

### Task 12: 创作工坊 (builder-v2.html)

**文件：**
- 创建：`builder-v2.html`

这是最复杂的页面——三栏画布编辑器。由于篇幅限制，这里只给出核心结构和关键逻辑。

- [ ] **Step 1: 编写 builder-v2.html 结构骨架**

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>GameHub · 创作工坊</title>
<style>
  /* 保持与现有项目一致的暗紫色主题和内联 CSS 风格 */
  /* 三栏布局：左侧 Block 列表(240px) + 中间预览(1fr) + 右侧属性(320px) */
  /* 底部 AI 栏(固定 60px) */
  /* 具体样式按设计文档 5.1 节实施 */
</style>
</head>
<body>
  <!-- 三栏布局骨架 -->
  <!-- 左侧：Block 列表 -->
  <!-- 中间：iframe 实时预览 -->
  <!-- 右侧：属性面板（根据选中的 Block 类型动态渲染表单） -->
  <!-- 底部：AI 助手输入栏 -->

<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
<script src="supabase.js"></script>
<script src="auth-player.js"></script>
<script src="runtime/block-registry.js"></script>
<script src="runtime/core/theme.js"></script>
<script src="runtime/core/rule.js"></script>
<script src="runtime/core/collection.js"></script>
<script src="runtime/core/grid.js"></script>
<script src="runtime/core/effect.js"></script>
<script src="runtime/core/player.js"></script>
<script src="runtime/core/store.js"></script>
<script src="runtime/core/building.js"></script>
<script src="runtime/core/piece.js"></script>
<script src="runtime/engine.js"></script>
<script src="runtime/games/monopoly.js"></script>

<script>
// ========= 创作工坊主逻辑 =========

let editorState = {
  gameType: 'monopoly',
  title: '未命名游戏',
  blocks: [],           // 当前编辑的 Block 数组
  selectedBlockId: null,// 当前选中 Block 的 ID
  isDirty: false,       // 是否有未保存的修改
  configId: null,       // 已保存的配置 ID（新建为空）
  shareSlug: null,      // 分享短码
};

// ─── 初始化 ───
async function init() {
  // 检查登录
  GameAuth.requireLogin(() => {
    // 检查 URL 参数：?edit=configId | ?fork=configId
    const params = new URLSearchParams(location.search);
    const editId = params.get('edit');
    const forkId = params.get('fork');

    if (editId) {
      loadConfig(editId);
    } else if (forkId) {
      forkConfig(forkId);
    } else {
      // 新建：加载默认配置
      editorState.blocks = BlockRegistry.getDefaults('monopoly');
      renderAll();
    }
  });
}

// ─── 加载配置 ───
async function loadConfig(configId) {
  const { data, error } = await GHSupabase
    .from('user_configs')
    .select('*')
    .eq('id', configId)
    .single();
  if (error) { alert('加载失败: ' + error.message); return; }
  editorState.blocks = data.blocks;
  editorState.title = data.title;
  editorState.configId = data.id;
  editorState.shareSlug = data.share_slug;
  renderAll();
}

// ─── Fork 配置 ───
async function forkConfig(configId) {
  const { data, error } = await GHSupabase
    .from('user_configs')
    .select('*')
    .eq('id', configId)
    .single();
  if (error) { alert('Fork 失败: ' + error.message); return; }
  editorState.blocks = JSON.parse(JSON.stringify(data.blocks));
  editorState.title = data.title + ' (Fork)';
  editorState.configId = null;
  editorState.shareSlug = null;
  renderAll();
}

// ─── Block 操作 ───
function addBlock(type) {
  const block = BlockRegistry.createBlock(type);
  editorState.blocks = [...editorState.blocks, block];
  editorState.selectedBlockId = block.id;
  editorState.isDirty = true;
  renderAll();
}

function removeBlock(blockId) {
  editorState.blocks = editorState.blocks.filter(b => b.id !== blockId);
  if (editorState.selectedBlockId === blockId) editorState.selectedBlockId = null;
  editorState.isDirty = true;
  renderAll();
}

function updateBlock(blockId, newConfig) {
  editorState.blocks = editorState.blocks.map(b =>
    b.id === blockId ? { ...b, config: { ...b.config, ...newConfig } } : b
  );
  editorState.isDirty = true;
}

function selectBlock(blockId) {
  editorState.selectedBlockId = blockId;
  renderPropertyPanel();
}

function reorderBlocks(fromIdx, toIdx) {
  const blocks = [...editorState.blocks];
  const [moved] = blocks.splice(fromIdx, 1);
  blocks.splice(toIdx, 0, moved);
  editorState.blocks = blocks;
  editorState.isDirty = true;
  renderAll();
}

// ─── 保存 ───
async function saveConfig() {
  const player = GameSupabase.getCurrentPlayer();
  if (!player) { alert('请先登录'); return; }

  const payload = {
    user_id: player.id,
    game_type: editorState.gameType,
    title: editorState.title,
    blocks: editorState.blocks,
    is_public: false,
  };

  let result;
  if (editorState.configId) {
    // 更新
    result = await GHSupabase
      .from('user_configs')
      .update({ ...payload, updated_at: new Date().toISOString() })
      .eq('id', editorState.configId)
      .select('*')
      .single();
  } else {
    // 新建
    result = await GHSupabase
      .from('user_configs')
      .insert(payload)
      .select('*')
      .single();
  }

  if (result.error) { alert('保存失败: ' + result.error.message); return; }

  editorState.configId = result.data.id;
  editorState.isDirty = false;
  showToast('✅ 已保存');
}

// ─── 发布（生成分享链接） ───
async function publishConfig() {
  if (!editorState.configId) await saveConfig();
  if (!editorState.configId) return;

  // 生成 share_slug
  const slug = Math.random().toString(36).slice(2, 10);

  const { error } = await GHSupabase
    .from('user_configs')
    .update({ is_published: true, share_slug: slug, updated_at: new Date().toISOString() })
    .eq('id', editorState.configId);

  if (error) { alert('发布失败: ' + error.message); return; }

  editorState.shareSlug = slug;
  const shareUrl = `${location.origin}/play.html?config=${slug}`;
  showToast(`🎉 已发布！\n${shareUrl}`);
  // 复制到剪贴板
  navigator.clipboard?.writeText(shareUrl);
}

// ─── 渲染 ───
function renderAll() {
  renderBlockList();
  renderPreview();
  renderPropertyPanel();
}

function renderBlockList() {
  // 渲染左侧 Block 列表
  // 每个 Block 显示：类型图标 + 标签名 + 拖拽手柄 + 删除按钮
  // 点击选中 → selectBlock(id)
}

function renderPreview() {
  // 在 iframe 中渲染游戏预览
  // iframe src = preview-frame.html?blocks=encodeURIComponent(JSON.stringify(blocks))
  // 避免跨域通信，使用 postMessage
}

function renderPropertyPanel() {
  // 渲染右侧属性面板
  // 根据 editorState.selectedBlockId 找到对应 Block
  // 根据 Block.type 获取 Schema → 动态渲染表单
  // 表单修改 → updateBlock(id, newConfig) → renderAll()
}

function showToast(msg) {
  // Toast 组件：底部弹出，3秒消失
}

// ─── AI 助手 ───
async function askAI(prompt) {
  // 调用 Supabase Edge Function
  const { data, error } = await GHSupabase.functions.invoke('ai-config', {
    body: {
      prompt,
      gameType: editorState.gameType,
      currentBlocks: editorState.blocks,
    },
  });
  if (error) { showToast('AI 请求失败: ' + error.message); return; }
  // data.patches: [{ blockId, config: {...} }, ...]  修改现有 Block
  // data.newBlocks: [{ type, config: {...} }, ...]     新增 Block
  // 应用 AI 生成的修改
  if (data.patches) {
    for (const patch of data.patches) {
      updateBlock(patch.blockId, patch.config);
    }
  }
  if (data.newBlocks) {
    for (const b of data.newBlocks) {
      const block = BlockRegistry.createBlock(b.type, b.config);
      editorState.blocks = [...editorState.blocks, block];
    }
  }
  editorState.isDirty = true;
  renderAll();
  showToast('🤖 AI 已修改配置');
}

// 启动
init();
</script>
</body>
</html>
```

由于 builder-v2.html 代码量较大（预计 ~800 行），具体样式和交互细节由实现工程师根据设计文档 5.1 节完成。

- [ ] **Step 2: 提交**

```bash
git add builder-v2.html
git commit -m "feat: builder-v2.html — 创作工坊三栏编辑器骨架 + Block 增删改 + 保存发布 + AI 接口"
```

---

### Task 13: AI 配置助手 Edge Function

**文件：**
- 创建：`supabase/functions/ai-config/index.ts`

- [ ] **Step 1: 编写 AI Edge Function**

```typescript
// supabase/functions/ai-config/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { prompt, gameType, currentBlocks } = await req.json();

    if (!prompt || !gameType) {
      return new Response(JSON.stringify({ error: '缺少 prompt 或 gameType' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 构建 AI 提示词
    const systemPrompt = `你是 GameHub 游戏配置助手。用户正在编辑一个 ${gameType} 游戏。
当前 Block 配置如下：
${JSON.stringify(currentBlocks, null, 2)}

用户说：「${prompt}」

请分析用户意图，返回 JSON 格式的修改方案：
{
  "explanation": "你的解释（中文）",
  "patches": [
    { "blockId": "blk_xxx", "config": { "key": "newValue" } }
  ],
  "newBlocks": [
    { "type": "collection", "config": { ... } }
  ]
}

规则：
1. 只修改现有 Block 的 config，不改变 block type
2. 如果用户要添加新内容（如新卡片、新建筑），用 newBlocks
3. 如果用户要改参数（如格数、金币），用 patches
4. 所有文案必须用中文，符合用户描述的主题风格
5. 只返回 JSON，不要其他内容`;

    // 调用 AI API（使用 Anthropic Messages API）
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': Deno.env.get('ANTHROPIC_API_KEY') || '',
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-5',
        max_tokens: 4096,
        system: systemPrompt,
        messages: [{ role: 'user', content: prompt }],
      }),
    });

    const aiResponse = await response.json();
    const content = aiResponse.content?.[0]?.text || '{"error": "AI 未返回内容"}';

    // 解析 AI 返回的 JSON
    let result;
    try {
      result = JSON.parse(content);
    } catch {
      // 尝试从文本中提取 JSON
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      result = jsonMatch ? JSON.parse(jsonMatch[0]) : { error: 'AI 返回格式异常', raw: content };
    }

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
```

- [ ] **Step 2: 部署 Edge Function**

```bash
cd supabase/functions
supabase functions deploy ai-config --no-verify-jwt
```

- [ ] **Step 3: 设置环境变量**

在 Supabase Dashboard → Settings → Edge Functions → 添加 `ANTHROPIC_API_KEY`。

- [ ] **Step 4: 提交**

```bash
git add supabase/functions/ai-config/index.ts
git commit -m "feat: AI 配置助手 Edge Function — 自然语言修改游戏 Block 配置"
```

---

### Task 14: 集成测试 — 完整流程验证

- [ ] **Step 1: 新建游戏流程**

1. 打开 `builder-v2.html`
2. 登录邮箱
3. 确认左侧 Block 列表显示 8 个默认 Block（棋盘、机会卡、命运卡、建筑商店、效果、规则、玩家、主题）
4. 点击「棋盘」Block → 右侧显示 Grid 编辑表单
5. 修改棋盘格数从 7×7 到 10×10 → 中间预览区棋盘变大
6. 点击「机会卡」Block → 右侧显示卡牌列表
7. 添加一张新卡牌「获得免费酒店」→ 卡牌列表多一项
8. 点击「保存」→ 提示保存成功
9. 点击「发布」→ 生成分享链接并复制

- [ ] **Step 2: 游玩流程**

1. 复制分享链接到新标签页打开
2. 确认顶栏显示游戏标题
3. 确认棋盘按配置渲染（如已改了 10×10）
4. 点击「掷骰子」按钮 → 棋子移动 → 状态栏更新
5. AI 玩家自动行动
6. 踩到机会格 → 弹出抽卡结果
7. 点击「购买地产」→ 金币减少 → 地产加入玩家资产

- [ ] **Step 3: Fork 流程**

1. 在 builder-v2.html 中用 `?fork=configId` 打开
2. 确认加载了源配置的所有 Block
3. 修改标题和棋盘 → 保存 → 确认不覆盖源配置

- [ ] **Step 4: 用 Playwright 编写自动化测试**

```javascript
// tests/phase1-e2e.spec.js
const { test, expect } = require('@playwright/test');

test('完整流程: 新建 → 编辑 → 保存 → 发布 → 游玩', async ({ page }) => {
  // 1. 打开工坊
  await page.goto('http://localhost:5500/builder-v2.html');
  // 2. 登录（模拟）
  // 3. 验证默认 Block
  // 4. 修改配置
  // 5. 保存
  // 6. 发布
  // 7. 打开游玩页
  // 8. 掷骰子
  // 9. 验证状态更新
});
```

- [ ] **Step 5: 提交**

```bash
git add tests/
git commit -m "test: Phase 1 端到端测试 — 创建→编辑→发布→游玩完整链路"
```

---

### Task 15: 收尾 — 更新旧文件索引

- [ ] **Step 1: 更新 index.html 导航**

在 index.html 顶部导航增加：
- 「🎨 创作工坊」链接 → `builder-v2.html`
- 保留旧 `builder.html` 链接加标记「(旧版)」

- [ ] **Step 2: 添加 runtime 加载说明**

在 `runtime/` 目录添加 `README.md`，说明每个文件的职责和加载顺序。

- [ ] **Step 3: 提交**

```bash
git add index.html runtime/README.md
git commit -m "chore: 更新导航链接和 runtime 说明文档"
```

---

## 附录：文件加载顺序

运行时页面需按以下顺序引入脚本：

```
1. Supabase SDK (CDN)
2. supabase.js          — Supabase 客户端
3. auth-player.js       — 认证
4. block-registry.js    — Block 类型定义
5. runtime/core/theme.js
6. runtime/core/rule.js
7. runtime/core/collection.js
8. runtime/core/grid.js
9. runtime/core/effect.js
10. runtime/core/player.js
11. runtime/core/store.js
12. runtime/core/building.js
13. runtime/core/piece.js
14. runtime/engine.js
15. runtime/games/monopoly.js  — 或对应的游戏模块
```

## 附录：API 接口速查

| 接口 | 方法 | 说明 |
|------|------|------|
| `BlockRegistry.getDefaults(gameType)` | 函数 | 获取默认 Block 列表 |
| `BlockRegistry.createBlock(type, overrides)` | 函数 | 创建新 Block 实例 |
| `BlockRegistry.getSchema(blockType)` | 函数 | 获取编辑 Schema |
| `ThemeRenderer.apply(config)` | 函数 | 应用主题 CSS 变量 |
| `RuleEngine.init(variables)` | 函数 | 初始化游戏变量状态 |
| `RuleEngine.get/set/incr(state, key, val)` | 函数 | 不可变操作变量 |
| `CollectionManager.draw(config, state)` | 函数 | 抽取卡牌 |
| `GridRenderer.render(container, config, cb)` | 函数 | 渲染棋盘 |
| `GridRenderer.getCellPosition(boardEl, index)` | 函数 | 获取格子坐标 |
| `GridRenderer.updateCell(boardEl, index, updates)` | 函数 | 更新格子样式 |
| `EffectEngine.match(config, trigger, ctx)` | 函数 | 匹配效果 |
| `EffectEngine.execute(effect, ctx, ruleState)` | 函数 | 执行效果 |
| `PlayerManager.createPlayers(config)` | 函数 | 创建玩家数组 |
| `StoreManager.getItems(config)` | 函数 | 获取商店商品 |
| `PieceController.createPieceEl(player, idx)` | 函数 | 创建棋子 DOM |
| `PieceController.animatePiece(el, pos, dur, ox, oy)` | 函数 | 动画移动棋子 |
| `GameEngine.init(config, container, gameMod)` | 函数 | 初始化引擎 |
| `GameEngine.on/emit(event, data)` | 函数 | 事件总线 |
| `MonopolyGame.start(ctx)` | 函数 | 启动大富翁 |
| `MonopolyGame.rollDice/buyProperty/buildBuilding()` | 函数 | 玩家操作 |
| `GHSupabase.from('user_configs')...` | Supabase | 配置 CRUD |
| `GHSupabase.functions.invoke('ai-config', {body})` | Supabase | AI 助手 |
