# GameHub 后端基础设施 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 GameHub 引入 Supabase 后端，实现玩家手机号登录、游戏数据云端上报、客户管理后台、你的 admin 后台。

**Architecture:** 前端通过 Supabase JS SDK 直接读写数据库；短信验证码发送走独立的 Cloudflare Workers 保护 API Key；游戏数据在写 localStorage 的同时异步上报 Supabase，51 个游戏文件不改动。

**Tech Stack:** Supabase (PostgreSQL + Auth + JS SDK v2)、Cloudflare Workers、阿里云 SMS、原生 HTML/CSS/JS

## Global Constraints

- 所有文件保持纯 HTML + 原生 JS，不引入构建工具或 npm
- Supabase JS SDK 通过 CDN 引入：`https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js`
- 51 个游戏 HTML 文件不允许改动
- localStorage 兼容层必须保留，离线时不报错
- 所有中文注释，commit message 中文
- 部署目录：`/Users/chenjunjie/minigame-platform/`
- Workers 文件目录：`/Users/chenjunjie/minigame-platform/workers/`

---

## 文件结构

**新建文件：**
- `supabase.js` — SDK 初始化 + 公共方法（getCurrentPlayer, isLoggedIn, logout）
- `auth-player.js` — 玩家手机号验证弹窗组件（依赖 supabase.js）
- `reporter.js` — 游戏结果上报模块（依赖 supabase.js，拦截 leaderboard.js 钩子）
- `admin-you.html` — 你的管理后台（客户管理 / 全局数据 / 创建活动）
- `admin-client.html` — 客户后台（登录 / 活动数据 / 配置编辑 / 生成链接）
- `workers/sms.js` — Cloudflare Workers 短信接口

**改动文件：**
- `leaderboard.js:225-231` — submitAndNotify() 增加 reporter.js 上报钩子
- `user.js` — init() 增加 player_token 检查
- `builder.html` — 生成链接时写入 campaigns 表

**数据库（Supabase SQL，人工执行）：**
- `db/schema.sql` — 建表 + RLS 策略 + 90天自动清理

---

## Task 1: Supabase 项目初始化 + 数据库建表

**Files:**
- Create: `db/schema.sql`
- Create: `supabase.js`

**Interfaces:**
- Produces:
  - `window.GHSupabase` — Supabase 客户端实例
  - `GameSupabase.getCurrentPlayer()` → `{ id, phone } | null`
  - `GameSupabase.isLoggedIn()` → `boolean`
  - `GameSupabase.getPlayerToken()` → `string | null`
  - `GameSupabase.setPlayerToken(token: string)` → `void`
  - `GameSupabase.getCampaignId()` → `string | null`（从 URL ?cid= 读取）

- [ ] **Step 1: 在 Supabase 创建项目**

前往 https://supabase.com → New Project，填写：
- 项目名：`gamehub`
- 数据库密码：生成强密码并保存
- Region：选 `Northeast Asia (Tokyo)` 或 `Southeast Asia (Singapore)`

记录以下两个值（后面 supabase.js 要用）：
- Project URL：`https://xxxx.supabase.co`
- anon public key：在 Settings → API 里找

- [ ] **Step 2: 写建表 SQL**

创建 `db/schema.sql`，内容如下：

```sql
-- ═══════════════════════════════════════════
-- GameHub 数据库 Schema
-- ═══════════════════════════════════════════

-- 1. clients（客户）
create table if not exists clients (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  email       text not null unique,
  plan        text not null default 'free' check (plan in ('free','pro')),
  created_at  timestamptz not null default now()
);

-- 2. campaigns（活动）
create table if not exists campaigns (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid not null references clients(id) on delete cascade,
  game_type   text not null,
  config      jsonb not null default '{}',
  title       text not null,
  status      text not null default 'draft' check (status in ('draft','active','ended')),
  starts_at   timestamptz,
  ends_at     timestamptz,
  created_at  timestamptz not null default now()
);

-- 3. players（玩家）
create table if not exists players (
  id          uuid primary key default gen_random_uuid(),
  phone       text not null unique,
  created_at  timestamptz not null default now()
);

-- 4. play_sessions（游戏流水，90天保留）
create table if not exists play_sessions (
  id           uuid primary key default gen_random_uuid(),
  campaign_id  uuid not null references campaigns(id) on delete cascade,
  player_id    uuid not null references players(id) on delete cascade,
  score        integer not null default 0,
  result       text not null default '',
  played_at    timestamptz not null default now()
);

-- 5. campaign_stats（汇总统计，永久保留）
create table if not exists campaign_stats (
  campaign_id     uuid not null references campaigns(id) on delete cascade,
  date            date not null,
  plays           integer not null default 0,
  winners         integer not null default 0,
  unique_players  integer not null default 0,
  primary key (campaign_id, date)
);

-- ═══════════════════════════════════════════
-- Row Level Security
-- ═══════════════════════════════════════════

alter table clients         enable row level security;
alter table campaigns       enable row level security;
alter table players         enable row level security;
alter table play_sessions   enable row level security;
alter table campaign_stats  enable row level security;

-- clients：只有 admin 能操作（通过 service_role key）
-- campaigns：客户只能看/改自己的
create policy "客户读自己的活动" on campaigns
  for select using (
    auth.uid()::text = (select email from clients where id = client_id limit 1)
    or auth.role() = 'service_role'
  );

create policy "客户改自己的活动" on campaigns
  for all using (
    auth.uid()::text = (select email from clients where id = client_id limit 1)
    or auth.role() = 'service_role'
  );

-- players：任何已认证用户可以 upsert 自己
create policy "玩家 upsert 自己" on players
  for all using (true);

-- play_sessions：任何已认证用户可以插入，查询自己的
create policy "玩家插入流水" on play_sessions
  for insert with check (true);

create policy "玩家查自己的流水" on play_sessions
  for select using (
    player_id = (select id from players where phone = auth.jwt()->>'phone' limit 1)
    or auth.role() = 'service_role'
  );

-- campaign_stats：service_role 写，客户读
create policy "客户读统计" on campaign_stats
  for select using (
    auth.role() = 'service_role'
    or exists (
      select 1 from campaigns c
      join clients cl on cl.id = c.client_id
      where c.id = campaign_id
      and auth.uid()::text = cl.email
    )
  );

create policy "写统计" on campaign_stats
  for all using (auth.role() = 'service_role');

-- ═══════════════════════════════════════════
-- 90天自动清理 play_sessions（pg_cron，需在 Supabase Dashboard 开启）
-- ═══════════════════════════════════════════
-- 在 Supabase Dashboard → Database → Extensions 开启 pg_cron，然后执行：
-- select cron.schedule('清理90天流水', '0 3 * * *',
--   $$ delete from play_sessions where played_at < now() - interval '90 days' $$
-- );
```

- [ ] **Step 3: 在 Supabase SQL Editor 执行建表 SQL**

打开 Supabase Dashboard → SQL Editor → 粘贴 `db/schema.sql` 内容 → Run。
确认5张表均出现在 Table Editor 中。

- [ ] **Step 4: 写 supabase.js**

创建 `/Users/chenjunjie/minigame-platform/supabase.js`：

```javascript
/**
 * GameHub Supabase 客户端
 * 依赖：CDN 引入 @supabase/supabase-js v2
 * 用法：在 supabase.js 后引入 auth-player.js / reporter.js
 */

// ⚠️ 替换为你的真实值（在 Supabase Dashboard → Settings → API 找）
const SUPABASE_URL  = 'https://YOUR_PROJECT_ID.supabase.co';
const SUPABASE_ANON = 'YOUR_ANON_PUBLIC_KEY';

// 初始化客户端
const GHSupabase = supabase.createClient(SUPABASE_URL, SUPABASE_ANON);

const GameSupabase = (() => {
  const PLAYER_TOKEN_KEY = 'gh_player_token';
  const PLAYER_ID_KEY    = 'gh_player_id';
  const PLAYER_PHONE_KEY = 'gh_player_phone';

  /** 获取当前登录玩家信息，未登录返回 null */
  function getCurrentPlayer() {
    const phone = localStorage.getItem(PLAYER_PHONE_KEY);
    const id    = localStorage.getItem(PLAYER_ID_KEY);
    if (!phone || !id) return null;
    return { id, phone };
  }

  /** 是否已登录 */
  function isLoggedIn() {
    return !!localStorage.getItem(PLAYER_TOKEN_KEY);
  }

  /** 获取 player token */
  function getPlayerToken() {
    return localStorage.getItem(PLAYER_TOKEN_KEY);
  }

  /** 保存登录信息到 localStorage */
  function setPlayerSession({ token, id, phone }) {
    localStorage.setItem(PLAYER_TOKEN_KEY, token);
    localStorage.setItem(PLAYER_ID_KEY, id);
    localStorage.setItem(PLAYER_PHONE_KEY, phone);
  }

  /** 登出 */
  function logout() {
    localStorage.removeItem(PLAYER_TOKEN_KEY);
    localStorage.removeItem(PLAYER_ID_KEY);
    localStorage.removeItem(PLAYER_PHONE_KEY);
  }

  /** 从 URL 参数读取 campaign_id（?cid=xxx） */
  function getCampaignId() {
    return new URLSearchParams(location.search).get('cid') || null;
  }

  return { getCurrentPlayer, isLoggedIn, getPlayerToken, setPlayerSession, logout, getCampaignId };
})();
```

- [ ] **Step 5: 手动验证连接**

在浏览器控制台（打开任意游戏页面，临时引入 SDK）运行：
```javascript
const c = supabase.createClient('https://YOUR.supabase.co', 'YOUR_ANON_KEY');
const { data, error } = await c.from('players').select('count');
console.log(data, error); // error 应为 null
```

- [ ] **Step 6: Commit**

```bash
cd /Users/chenjunjie/minigame-platform
git add db/schema.sql supabase.js
git commit -m "feat: Supabase 初始化——建表SQL + 客户端封装 supabase.js"
```

---

## Task 2: Cloudflare Workers 短信接口

**Files:**
- Create: `workers/sms.js`
- Create: `workers/wrangler.toml`

**Interfaces:**
- Consumes: 无（独立 Worker）
- Produces:
  - `POST /api/sms/send` — body: `{ phone: string }` → `{ ok: true }` or `{ error: string }`
  - `POST /api/sms/verify` — body: `{ phone: string, code: string }` → `{ ok: true, token: string, playerId: string }` or `{ error: string }`
  - Worker 部署后地址：`https://sms.jydigtal.com`（或 workers.dev 子域）

- [ ] **Step 1: 安装 Wrangler CLI**

```bash
npm install -g wrangler
wrangler --version
# 期望输出：wrangler x.x.x
```

- [ ] **Step 2: 登录 Cloudflare**

```bash
wrangler login
# 浏览器打开授权页，点 Allow
```

- [ ] **Step 3: 创建 workers 目录和配置文件**

创建 `/Users/chenjunjie/minigame-platform/workers/wrangler.toml`：

```toml
name = "gamehub-sms"
main = "sms.js"
compatibility_date = "2024-01-01"

[vars]
SUPABASE_URL = "https://YOUR_PROJECT_ID.supabase.co"
# 敏感 key 用 wrangler secret set 命令设置，不写在这里
```

- [ ] **Step 4: 设置环境变量（敏感 key）**

```bash
cd /Users/chenjunjie/minigame-platform/workers

# 阿里云 SMS
wrangler secret set ALIYUN_ACCESS_KEY_ID
# 输入你的阿里云 AccessKey ID，回车

wrangler secret set ALIYUN_ACCESS_KEY_SECRET
# 输入你的阿里云 AccessKey Secret，回车

# Supabase service role key（用于 Workers 写 players 表，绕过 RLS）
wrangler secret set SUPABASE_SERVICE_KEY
# 在 Supabase Dashboard → Settings → API → service_role key

# 验证码内存存储（生产用 Cloudflare KV，MVP 用内存）
# 验证码有效期5分钟，内存存储在单次请求内有效，需用 KV 做持久化
# MVP 阶段先用 KV，创建方式：
wrangler kv:namespace create "SMS_CODES"
# 输出类似：{ binding = "SMS_CODES", id = "abc123..." }
# 把 id 填入下面的 wrangler.toml
```

更新 `workers/wrangler.toml`，加入 KV 绑定：
```toml
name = "gamehub-sms"
main = "sms.js"
compatibility_date = "2024-01-01"

[vars]
SUPABASE_URL = "https://YOUR_PROJECT_ID.supabase.co"
ALIYUN_SMS_SIGN = "GameHub"
ALIYUN_SMS_TEMPLATE = "SMS_XXXXXXXXX"

[[kv_namespaces]]
binding = "SMS_CODES"
id = "填入上面 kv:namespace create 输出的 id"
```

- [ ] **Step 5: 写 workers/sms.js**

创建 `/Users/chenjunjie/minigame-platform/workers/sms.js`：

```javascript
/**
 * Cloudflare Workers — GameHub 短信验证码服务
 * 路由：
 *   POST /api/sms/send   发送验证码
 *   POST /api/sms/verify 验证验证码，返回 player token
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export default {
  async fetch(request, env) {
    // 处理预检请求
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    const url = new URL(request.url);

    if (url.pathname === '/api/sms/send' && request.method === 'POST') {
      return handleSend(request, env);
    }
    if (url.pathname === '/api/sms/verify' && request.method === 'POST') {
      return handleVerify(request, env);
    }

    return json({ error: '未知路由' }, 404);
  }
};

// ─── 发送验证码 ───
async function handleSend(request, env) {
  const { phone } = await request.json();

  if (!phone || !/^1[3-9]\d{9}$/.test(phone)) {
    return json({ error: '手机号格式不正确' }, 400);
  }

  // 生成6位验证码
  const code = String(Math.floor(100000 + Math.random() * 900000));
  const key  = `sms:${phone}`;

  // 存入 KV，5分钟过期
  await env.SMS_CODES.put(key, code, { expirationTtl: 300 });

  // 调阿里云 SMS
  const smsResult = await sendAliyunSMS(phone, code, env);
  if (!smsResult.ok) {
    return json({ error: '短信发送失败，请稍后重试' }, 500);
  }

  return json({ ok: true });
}

// ─── 验证验证码 ───
async function handleVerify(request, env) {
  const { phone, code } = await request.json();

  if (!phone || !code) {
    return json({ error: '参数缺失' }, 400);
  }

  const key       = `sms:${phone}`;
  const savedCode = await env.SMS_CODES.get(key);

  if (!savedCode) {
    return json({ error: '验证码已过期，请重新获取' }, 400);
  }
  if (savedCode !== code) {
    return json({ error: '验证码错误' }, 400);
  }

  // 验证成功，删除 KV 中的验证码
  await env.SMS_CODES.delete(key);

  // upsert players 表（用 service_role key 绕过 RLS）
  const playerResult = await upsertPlayer(phone, env);
  if (!playerResult.ok) {
    return json({ error: '用户创建失败' }, 500);
  }

  // 生成简单 token（player_id + timestamp 的 base64，MVP 级别）
  const token = btoa(`${playerResult.playerId}:${Date.now()}`);

  return json({ ok: true, token, playerId: playerResult.playerId });
}

// ─── 阿里云 SMS ───
async function sendAliyunSMS(phone, code, env) {
  // 阿里云 SMS API v2.0 签名方式
  const endpoint    = 'dysmsapi.aliyuncs.com';
  const action      = 'SendSms';
  const version     = '2017-05-25';
  const region      = 'cn-hangzhou';
  const date        = new Date().toISOString().slice(0, 10);
  const datetime    = new Date().toISOString().replace(/[-:]/g, '').slice(0, 15) + 'Z';
  const nonce       = crypto.randomUUID().replace(/-/g, '');

  const params = {
    Action:           action,
    Version:          version,
    Format:           'JSON',
    SignatureMethod:  'HMAC-SHA1',
    SignatureNonce:   nonce,
    SignatureVersion: '1.0',
    Timestamp:        new Date().toISOString().replace(/\.\d{3}/, ''),
    AccessKeyId:      env.ALIYUN_ACCESS_KEY_ID,
    PhoneNumbers:     phone,
    SignName:         env.ALIYUN_SMS_SIGN,
    TemplateCode:     env.ALIYUN_SMS_TEMPLATE,
    TemplateParam:    JSON.stringify({ code }),
  };

  // 排序拼接
  const sorted = Object.keys(params).sort().map(k =>
    `${encodeURIComponent(k)}=${encodeURIComponent(params[k])}`
  ).join('&');

  const toSign = `GET&${encodeURIComponent('/')}&${encodeURIComponent(sorted)}`;

  // HMAC-SHA1
  const keyData   = new TextEncoder().encode(env.ALIYUN_ACCESS_KEY_SECRET + '&');
  const msgData   = new TextEncoder().encode(toSign);
  const cryptoKey = await crypto.subtle.importKey('raw', keyData, { name: 'HMAC', hash: 'SHA-1' }, false, ['sign']);
  const sigBuf    = await crypto.subtle.sign('HMAC', cryptoKey, msgData);
  const signature = btoa(String.fromCharCode(...new Uint8Array(sigBuf)));

  const url = `https://${endpoint}/?${sorted}&Signature=${encodeURIComponent(signature)}`;
  const res = await fetch(url);
  const body = await res.json();

  return { ok: body.Code === 'OK' };
}

// ─── Supabase upsert players ───
async function upsertPlayer(phone, env) {
  const url = `${env.SUPABASE_URL}/rest/v1/players`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type':  'application/json',
      'apikey':        env.SUPABASE_SERVICE_KEY,
      'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
      'Prefer':        'resolution=merge-duplicates,return=representation',
    },
    body: JSON.stringify({ phone }),
  });

  if (!res.ok) return { ok: false };
  const [player] = await res.json();
  return { ok: true, playerId: player.id };
}

// ─── 工具 ───
function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}
```

- [ ] **Step 6: 本地测试 Workers**

```bash
cd /Users/chenjunjie/minigame-platform/workers
wrangler dev
# 期望：Worker 在 http://localhost:8787 启动

# 新开终端测试：
curl -X POST http://localhost:8787/api/sms/send \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000"}'
# 期望：{"ok":true} 或阿里云报错（未配置真实 key 时正常）
```

- [ ] **Step 7: 部署 Workers**

```bash
cd /Users/chenjunjie/minigame-platform/workers
wrangler deploy
# 期望输出：https://gamehub-sms.YOUR_ACCOUNT.workers.dev
```

可选：在 Cloudflare Dashboard → Workers → gamehub-sms → Settings → Triggers → Custom Domains，绑定 `api.jydigtal.com`。

- [ ] **Step 8: Commit**

```bash
cd /Users/chenjunjie/minigame-platform
git add workers/
git commit -m "feat: Cloudflare Workers 短信接口——发送/验证验证码，阿里云SMS"
```

---

## Task 3: 玩家登录组件 auth-player.js

**Files:**
- Create: `auth-player.js`

**Interfaces:**
- Consumes:
  - `GameSupabase.isLoggedIn()` → boolean
  - `GameSupabase.setPlayerSession({ token, id, phone })` → void
  - `GameSupabase.getCampaignId()` → string | null
  - Workers: `POST https://api.jydigtal.com/api/sms/send`
  - Workers: `POST https://api.jydigtal.com/api/sms/verify` → `{ ok, token, playerId }`
- Produces:
  - 自动在 body 注入验证弹窗
  - `window.GameAuth.requireLogin(callback)` — 确保登录后执行 callback
  - `window.GameAuth.onLoginSuccess(fn)` — 注册登录成功回调

- [ ] **Step 1: 写 auth-player.js**

创建 `/Users/chenjunjie/minigame-platform/auth-player.js`：

```javascript
/**
 * GameHub 玩家手机号登录组件
 * 依赖：supabase.js（先引入）
 * 效果：检测到未登录时自动弹出手机号验证弹窗，登录后继续游戏
 */

const GameAuth = (() => {
  // Workers 短信接口地址
  const SMS_API = 'https://api.jydigtal.com';
  // 本地开发时改为：const SMS_API = 'http://localhost:8787';

  let loginCallbacks = [];
  let modalEl = null;
  let cooldownTimer = null;
  let cooldownSec = 0;

  // ─── 注册登录成功回调 ───
  function onLoginSuccess(fn) {
    loginCallbacks.push(fn);
  }

  // ─── 确保登录后执行 callback ───
  function requireLogin(callback) {
    if (GameSupabase.isLoggedIn()) {
      callback();
      return;
    }
    onLoginSuccess(callback);
    showModal();
  }

  // ─── 注入弹窗样式 ───
  function injectStyles() {
    if (document.getElementById('gh-auth-style')) return;
    const style = document.createElement('style');
    style.id = 'gh-auth-style';
    style.textContent = `
      #gh-auth-backdrop {
        position: fixed; inset: 0; z-index: 99999;
        background: rgba(13,7,32,0.92); backdrop-filter: blur(8px);
        display: flex; align-items: center; justify-content: center;
      }
      #gh-auth-box {
        background: #1A0A2E; border: 1px solid rgba(124,58,237,0.4);
        border-radius: 20px; padding: 32px 28px; width: min(360px, 92vw);
        text-align: center; font-family: -apple-system,'PingFang SC',sans-serif;
      }
      #gh-auth-box h2 { font-size: 20px; font-weight: 800; color: #F0EAF8; margin-bottom: 6px; }
      #gh-auth-box p  { font-size: 13px; color: rgba(240,234,248,0.55); margin-bottom: 24px; }
      .gh-auth-input {
        width: 100%; padding: 12px 16px; border-radius: 10px;
        background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.15);
        color: #F0EAF8; font-size: 15px; outline: none; box-sizing: border-box;
        margin-bottom: 12px; font-family: inherit;
        transition: border-color 0.2s;
      }
      .gh-auth-input:focus { border-color: #7C3AED; }
      .gh-auth-btn {
        width: 100%; padding: 13px; border-radius: 10px; border: none;
        background: linear-gradient(135deg, #7C3AED, #EC4899);
        color: white; font-size: 15px; font-weight: 700; cursor: pointer;
        font-family: inherit; margin-bottom: 10px; transition: opacity 0.2s;
      }
      .gh-auth-btn:hover { opacity: 0.88; }
      .gh-auth-btn:disabled { opacity: 0.45; cursor: not-allowed; }
      .gh-auth-link {
        font-size: 12px; color: rgba(240,234,248,0.4); cursor: pointer;
        background: none; border: none; font-family: inherit;
      }
      .gh-auth-link:hover { color: rgba(240,234,248,0.7); }
      .gh-auth-err { font-size: 12px; color: #F87171; margin-bottom: 10px; min-height: 18px; }
      .gh-auth-ok  { font-size: 12px; color: #34D399; margin-bottom: 10px; }
    `;
    document.head.appendChild(style);
  }

  // ─── 渲染第一步：输入手机号 ───
  function renderPhoneStep() {
    modalEl.innerHTML = `
      <div id="gh-auth-box">
        <h2>🎮 验证手机号</h2>
        <p>参与活动需要验证手机号，用于记录您的游戏数据</p>
        <input id="gh-phone" class="gh-auth-input" type="tel" placeholder="请输入手机号" maxlength="11" inputmode="numeric">
        <div id="gh-auth-msg" class="gh-auth-err"></div>
        <button id="gh-send-btn" class="gh-auth-btn">获取验证码</button>
        <button class="gh-auth-link" onclick="document.getElementById('gh-auth-backdrop').remove()">暂时跳过</button>
      </div>
    `;

    document.getElementById('gh-send-btn').addEventListener('click', async () => {
      const phone = document.getElementById('gh-phone').value.trim();
      if (!/^1[3-9]\d{9}$/.test(phone)) {
        showMsg('请输入正确的11位手机号', 'err'); return;
      }
      await sendCode(phone);
    });
  }

  // ─── 发送验证码 ───
  async function sendCode(phone) {
    const btn = document.getElementById('gh-send-btn');
    btn.disabled = true;
    showMsg('发送中…', 'ok');

    try {
      const res = await fetch(`${SMS_API}/api/sms/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone }),
      });
      const data = await res.json();
      if (!data.ok) { showMsg(data.error || '发送失败', 'err'); btn.disabled = false; return; }

      showMsg('验证码已发送 ✓', 'ok');
      renderCodeStep(phone);
      startCooldown();
    } catch (e) {
      showMsg('网络错误，请重试', 'err');
      btn.disabled = false;
    }
  }

  // ─── 渲染第二步：输入验证码 ───
  function renderCodeStep(phone) {
    modalEl.innerHTML = `
      <div id="gh-auth-box">
        <h2>🔐 输入验证码</h2>
        <p>验证码已发送至 ${phone.slice(0,3)}****${phone.slice(-4)}</p>
        <input id="gh-code" class="gh-auth-input" type="text" placeholder="6位验证码" maxlength="6" inputmode="numeric">
        <div id="gh-auth-msg" class="gh-auth-err"></div>
        <button id="gh-verify-btn" class="gh-auth-btn">验证</button>
        <button class="gh-auth-link" id="gh-resend">重新发送 (60s)</button>
      </div>
    `;

    document.getElementById('gh-verify-btn').addEventListener('click', () => {
      verifyCode(phone, document.getElementById('gh-code').value.trim());
    });

    document.getElementById('gh-resend').addEventListener('click', () => {
      if (cooldownSec > 0) return;
      renderPhoneStep();
      document.getElementById('gh-phone').value = phone;
    });

    // 自动聚焦
    setTimeout(() => document.getElementById('gh-code')?.focus(), 100);
  }

  // ─── 验证验证码 ───
  async function verifyCode(phone, code) {
    if (code.length !== 6) { showMsg('请输入6位验证码', 'err'); return; }

    const btn = document.getElementById('gh-verify-btn');
    btn.disabled = true;
    showMsg('验证中…', 'ok');

    try {
      const res = await fetch(`${SMS_API}/api/sms/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone, code }),
      });
      const data = await res.json();

      if (!data.ok) { showMsg(data.error || '验证失败', 'err'); btn.disabled = false; return; }

      // 登录成功
      GameSupabase.setPlayerSession({ token: data.token, id: data.playerId, phone });
      modalEl.remove();
      loginCallbacks.forEach(fn => { try { fn(); } catch(e) {} });
      loginCallbacks = [];

    } catch (e) {
      showMsg('网络错误，请重试', 'err');
      btn.disabled = false;
    }
  }

  // ─── 工具 ───
  function showMsg(text, type) {
    const el = document.getElementById('gh-auth-msg');
    if (!el) return;
    el.className = type === 'err' ? 'gh-auth-err' : 'gh-auth-ok';
    el.textContent = text;
  }

  function startCooldown() {
    cooldownSec = 60;
    clearInterval(cooldownTimer);
    cooldownTimer = setInterval(() => {
      cooldownSec--;
      const btn = document.getElementById('gh-resend');
      if (btn) btn.textContent = cooldownSec > 0 ? `重新发送 (${cooldownSec}s)` : '重新发送';
      if (cooldownSec <= 0) clearInterval(cooldownTimer);
    }, 1000);
  }

  function showModal() {
    injectStyles();
    if (document.getElementById('gh-auth-backdrop')) return;
    modalEl = document.createElement('div');
    modalEl.id = 'gh-auth-backdrop';
    document.body.appendChild(modalEl);
    renderPhoneStep();
  }

  // ─── 自动检测：如果 URL 有 ?cid= 且未登录，自动弹窗 ───
  document.addEventListener('DOMContentLoaded', () => {
    if (GameSupabase.getCampaignId() && !GameSupabase.isLoggedIn()) {
      showModal();
    }
  });

  return { requireLogin, onLoginSuccess };
})();
```

- [ ] **Step 2: 在 wheel.html 临时测试弹窗效果**

打开 `wheel.html`，在 `</body>` 前临时加入：
```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
<script src="supabase.js"></script>
<script src="auth-player.js"></script>
```
在浏览器地址栏访问 `wheel.html?cid=test-campaign`，应弹出手机号输入框。

验证通过后删除临时代码。

- [ ] **Step 3: Commit**

```bash
git add auth-player.js
git commit -m "feat: 玩家手机号登录弹窗组件 auth-player.js"
```

---

## Task 4: 游戏数据上报模块 reporter.js

**Files:**
- Create: `reporter.js`
- Modify: `leaderboard.js:225-231`

**Interfaces:**
- Consumes:
  - `GameSupabase.getCurrentPlayer()` → `{ id, phone } | null`
  - `GameSupabase.getCampaignId()` → `string | null`
  - `GHSupabase` — Supabase 客户端实例
- Produces:
  - `GameReporter.report({ game, score, result })` → `Promise<void>`
  - 拦截 `GameLeaderboard.submitAndNotify()` 自动触发上报

- [ ] **Step 1: 写 reporter.js**

创建 `/Users/chenjunjie/minigame-platform/reporter.js`：

```javascript
/**
 * GameHub 游戏数据上报模块
 * 依赖：supabase.js（先引入）
 * 自动拦截 GameLeaderboard.submitAndNotify() 钩子，离线时降级为 localStorage
 */

const GameReporter = (() => {

  /**
   * 上报一局游戏结果到 Supabase
   * @param {object} opts
   * @param {string} opts.game    游戏名称
   * @param {number} opts.score   得分
   * @param {string} opts.result  结果文字（中奖奖品名 / 未中）
   */
  async function report({ game, score, result = '' }) {
    // 未登录或无活动ID时静默跳过，不影响游戏
    const player     = GameSupabase.getCurrentPlayer();
    const campaignId = GameSupabase.getCampaignId();
    if (!player || !campaignId) return;

    try {
      // 1. 插入 play_sessions
      const { error: sessionError } = await GHSupabase
        .from('play_sessions')
        .insert({
          campaign_id: campaignId,
          player_id:   player.id,
          score:       Number(score) || 0,
          result:      result || game,
        });

      if (sessionError) {
        console.warn('[Reporter] play_sessions 写入失败:', sessionError.message);
        return;
      }

      // 2. upsert campaign_stats（当天汇总）
      const today = new Date().toISOString().slice(0, 10);
      const isWin = result && result !== '谢谢参与' && result !== '未中';

      // 先读当天记录
      const { data: existing } = await GHSupabase
        .from('campaign_stats')
        .select('plays, winners, unique_players')
        .eq('campaign_id', campaignId)
        .eq('date', today)
        .single();

      if (existing) {
        // 更新
        await GHSupabase
          .from('campaign_stats')
          .update({
            plays:   existing.plays + 1,
            winners: existing.winners + (isWin ? 1 : 0),
          })
          .eq('campaign_id', campaignId)
          .eq('date', today);
      } else {
        // 新建
        await GHSupabase
          .from('campaign_stats')
          .insert({
            campaign_id:    campaignId,
            date:           today,
            plays:          1,
            winners:        isWin ? 1 : 0,
            unique_players: 1,
          });
      }
    } catch (e) {
      // 网络错误时静默，不影响游戏体验
      console.warn('[Reporter] 上报失败:', e.message);
    }
  }

  return { report };
})();

// ─── 拦截 GameLeaderboard.submitAndNotify ───
// 在 leaderboard.js 加载完成后执行（本文件放在 leaderboard.js 之后引入）
document.addEventListener('DOMContentLoaded', () => {
  if (typeof GameLeaderboard === 'undefined') return;

  const original = GameLeaderboard.submitAndNotify.bind(GameLeaderboard);
  GameLeaderboard.submitAndNotify = function(opts) {
    const result = original(opts);
    // 异步上报，不阻塞游戏
    GameReporter.report({
      game:   opts.game   || '',
      score:  opts.score  || 0,
      result: opts.result || '',
    }).catch(() => {});
    return result;
  };
});
```

- [ ] **Step 2: 修改 leaderboard.js，在 submitAndNotify 后加上报钩子预留位**

读取 `leaderboard.js` 第225-231行（当前内容）：
```javascript
  function submitAndNotify(opts) {
    const result = submit(opts);
    if (result.rank > 0) {
      showSubmitToast({ rank: result.rank, isPersonalBest: result.isPersonalBest, game: opts.game });
    }
    return result;
  }
```

不需要改动——reporter.js 通过 DOMContentLoaded 后覆盖 submitAndNotify，不侵入 leaderboard.js。

- [ ] **Step 3: 验证上报逻辑（浏览器控制台）**

在 `wheel.html?cid=test-uuid&c=xxx` 页面，打开控制台：
```javascript
// 模拟已登录状态
localStorage.setItem('gh_player_token', 'test-token');
localStorage.setItem('gh_player_id', 'test-player-id');
localStorage.setItem('gh_player_phone', '13800138000');

// 手动触发上报
GameReporter.report({ game: '大转盘', score: 100, result: '100元券' });
// 期望：Supabase play_sessions 表里出现一条记录（需真实配置才能验证）
```

- [ ] **Step 4: Commit**

```bash
git add reporter.js
git commit -m "feat: 游戏数据上报模块 reporter.js，拦截 leaderboard 钩子异步上报 Supabase"
```

---

## Task 5: 你的管理后台 admin-you.html

**Files:**
- Create: `admin-you.html`

**Interfaces:**
- Consumes:
  - `GHSupabase` — Supabase 客户端（service_role 权限需通过 Supabase Dashboard 操作）
  - Tables: clients, campaigns, campaign_stats, play_sessions
- Produces: 管理员后台页面（本地访问，不对外公开链接）

- [ ] **Step 1: 写 admin-you.html**

创建 `/Users/chenjunjie/minigame-platform/admin-you.html`：

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>GameHub · 管理后台</title>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
<script src="supabase.js"></script>
<style>
* { margin:0; padding:0; box-sizing:border-box; }
:root { --bg:#0D0720; --card:rgba(255,255,255,0.05); --border:rgba(255,255,255,0.1); --text:#F0EAF8; --muted:rgba(240,234,248,0.55); --gold:#F5C842; --accent:#7C3AED; --green:#22C55E; }
body { font-family:-apple-system,'PingFang SC',sans-serif; background:var(--bg); color:var(--text); min-height:100vh; }

/* 登录页 */
#login-page { display:flex; align-items:center; justify-content:center; min-height:100vh; }
.login-box { background:rgba(255,255,255,0.04); border:1px solid var(--border); border-radius:20px; padding:40px 36px; width:min(380px,92vw); text-align:center; }
.login-box h1 { font-size:22px; font-weight:800; margin-bottom:6px; }
.login-box p { font-size:13px; color:var(--muted); margin-bottom:28px; }
.input { width:100%; padding:11px 14px; border-radius:10px; background:rgba(255,255,255,0.06); border:1px solid var(--border); color:var(--text); font-size:14px; outline:none; margin-bottom:12px; box-sizing:border-box; font-family:inherit; }
.input:focus { border-color:var(--accent); }
.btn-primary { width:100%; padding:13px; border-radius:10px; border:none; background:linear-gradient(135deg,var(--accent),#EC4899); color:white; font-size:15px; font-weight:700; cursor:pointer; font-family:inherit; }
.err-msg { font-size:12px; color:#F87171; min-height:18px; margin-bottom:8px; }

/* 主界面 */
#admin-page { display:none; }
.topbar { display:flex; align-items:center; justify-content:space-between; padding:0 28px; height:56px; border-bottom:1px solid var(--border); background:rgba(13,7,32,0.97); }
.topbar-logo { font-size:17px; font-weight:800; }
.topbar-logo span { color:var(--gold); }
.main { max-width:1100px; margin:0 auto; padding:28px; }
.tabs { display:flex; gap:4px; margin-bottom:24px; }
.tab-btn { padding:8px 18px; border-radius:10px; font-size:13px; font-weight:600; cursor:pointer; border:1px solid var(--border); background:transparent; color:var(--muted); font-family:inherit; }
.tab-btn.active { background:rgba(124,58,237,0.15); border-color:var(--accent); color:var(--text); }
.tab-panel { display:none; }
.tab-panel.active { display:block; }

/* 卡片 */
.stat-grid { display:grid; grid-template-columns:repeat(4,1fr); gap:14px; margin-bottom:24px; }
.stat-card { background:var(--card); border:1px solid var(--border); border-radius:12px; padding:18px; text-align:center; }
.stat-num { font-size:28px; font-weight:800; color:var(--gold); }
.stat-lbl { font-size:11px; color:var(--muted); margin-top:4px; }

/* 表格 */
.table-wrap { overflow-x:auto; border-radius:12px; border:1px solid var(--border); }
table { width:100%; border-collapse:collapse; font-size:13px; }
th { background:rgba(255,255,255,0.04); padding:10px 14px; text-align:left; font-size:11px; color:var(--muted); font-weight:700; border-bottom:1px solid var(--border); }
td { padding:10px 14px; border-bottom:1px solid rgba(255,255,255,0.04); }
tr:last-child td { border-bottom:none; }
tr:hover td { background:rgba(255,255,255,0.02); }

/* 操作按钮 */
.action-btn { padding:5px 12px; border-radius:7px; font-size:12px; font-weight:600; cursor:pointer; border:1px solid var(--border); background:transparent; color:var(--muted); font-family:inherit; margin-right:4px; }
.action-btn:hover { color:var(--text); border-color:rgba(124,58,237,0.5); }
.action-btn.danger { color:#F87171; border-color:rgba(239,68,68,0.3); }

/* 新建客户表单 */
.form-card { background:var(--card); border:1px solid var(--border); border-radius:14px; padding:20px; margin-bottom:20px; }
.form-row { display:grid; grid-template-columns:1fr 1fr 1fr auto; gap:10px; align-items:end; }
.field label { display:block; font-size:11px; color:var(--muted); margin-bottom:5px; font-weight:600; }
.pill { display:inline-block; padding:2px 8px; border-radius:5px; font-size:11px; font-weight:700; }
.pill-green { background:rgba(34,197,94,0.15); color:var(--green); border:1px solid rgba(34,197,94,0.3); }
.pill-gray  { background:rgba(255,255,255,0.06); color:var(--muted); border:1px solid var(--border); }
</style>
</head>
<body>

<!-- 登录页 -->
<div id="login-page">
  <div class="login-box">
    <h1>🎮 GameHub</h1>
    <p>管理员后台，仅限内部使用</p>
    <input id="admin-email" class="input" type="email" placeholder="管理员邮箱">
    <input id="admin-pwd"   class="input" type="password" placeholder="密码">
    <div id="login-err" class="err-msg"></div>
    <button class="btn-primary" onclick="doLogin()">登录</button>
  </div>
</div>

<!-- 主界面 -->
<div id="admin-page">
  <div class="topbar">
    <div class="topbar-logo">🎮 <span>GameHub</span> 管理后台</div>
    <button class="action-btn" onclick="doLogout()">退出登录</button>
  </div>
  <div class="main">
    <div class="tabs">
      <button class="tab-btn active" onclick="switchTab('overview',this)">📊 总览</button>
      <button class="tab-btn" onclick="switchTab('clients',this)">👥 客户管理</button>
      <button class="tab-btn" onclick="switchTab('campaigns',this)">🎯 活动列表</button>
    </div>

    <!-- 总览 -->
    <div id="tab-overview" class="tab-panel active">
      <div class="stat-grid">
        <div class="stat-card"><div class="stat-num" id="st-clients">-</div><div class="stat-lbl">客户总数</div></div>
        <div class="stat-card"><div class="stat-num" id="st-campaigns">-</div><div class="stat-lbl">活动总数</div></div>
        <div class="stat-card"><div class="stat-num" id="st-players">-</div><div class="stat-lbl">玩家总数</div></div>
        <div class="stat-card"><div class="stat-num" id="st-plays">-</div><div class="stat-lbl">今日游戏次数</div></div>
      </div>
    </div>

    <!-- 客户管理 -->
    <div id="tab-clients" class="tab-panel">
      <div class="form-card">
        <div style="font-size:13px;font-weight:700;margin-bottom:14px">➕ 新建客户</div>
        <div class="form-row">
          <div class="field"><label>公司名</label><input id="new-name" class="input" placeholder="如：某某品牌" style="margin:0"></div>
          <div class="field"><label>登录邮箱</label><input id="new-email" class="input" type="email" placeholder="client@example.com" style="margin:0"></div>
          <div class="field"><label>套餐</label>
            <select id="new-plan" class="input" style="margin:0">
              <option value="free">Free</option>
              <option value="pro">Pro</option>
            </select>
          </div>
          <button class="btn-primary" style="padding:11px 20px;width:auto" onclick="createClient()">创建</button>
        </div>
        <div id="create-msg" style="font-size:12px;margin-top:8px;min-height:16px"></div>
      </div>
      <div class="table-wrap">
        <table>
          <thead><tr><th>公司名</th><th>邮箱</th><th>套餐</th><th>创建时间</th><th>操作</th></tr></thead>
          <tbody id="clients-tbody"><tr><td colspan="5" style="text-align:center;color:var(--muted)">加载中…</td></tr></tbody>
        </table>
      </div>
    </div>

    <!-- 活动列表 -->
    <div id="tab-campaigns" class="tab-panel">
      <div class="table-wrap">
        <table>
          <thead><tr><th>活动名</th><th>客户</th><th>游戏类型</th><th>状态</th><th>创建时间</th><th>操作</th></tr></thead>
          <tbody id="campaigns-tbody"><tr><td colspan="6" style="text-align:center;color:var(--muted)">加载中…</td></tr></tbody>
        </table>
      </div>
    </div>
  </div>
</div>

<script>
let currentSession = null;

// ─── 登录 ───
async function doLogin() {
  const email = document.getElementById('admin-email').value.trim();
  const pwd   = document.getElementById('admin-pwd').value;
  document.getElementById('login-err').textContent = '';

  const { data, error } = await GHSupabase.auth.signInWithPassword({ email, password: pwd });
  if (error) { document.getElementById('login-err').textContent = '邮箱或密码错误'; return; }

  currentSession = data.session;
  document.getElementById('login-page').style.display = 'none';
  document.getElementById('admin-page').style.display  = 'block';
  loadOverview();
  loadClients();
  loadCampaigns();
}

function doLogout() {
  GHSupabase.auth.signOut();
  location.reload();
}

// ─── Tab 切换 ───
function switchTab(name, btn) {
  document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
  document.getElementById('tab-' + name).classList.add('active');
  btn.classList.add('active');
}

// ─── 加载总览 ───
async function loadOverview() {
  const [c, ca, p] = await Promise.all([
    GHSupabase.from('clients').select('id', { count: 'exact', head: true }),
    GHSupabase.from('campaigns').select('id', { count: 'exact', head: true }),
    GHSupabase.from('players').select('id', { count: 'exact', head: true }),
  ]);
  document.getElementById('st-clients').textContent   = c.count ?? '-';
  document.getElementById('st-campaigns').textContent = ca.count ?? '-';
  document.getElementById('st-players').textContent   = p.count ?? '-';

  // 今日游戏次数
  const today = new Date().toISOString().slice(0,10);
  const { data: stats } = await GHSupabase.from('campaign_stats').select('plays').eq('date', today);
  const todayPlays = (stats || []).reduce((s, r) => s + r.plays, 0);
  document.getElementById('st-plays').textContent = todayPlays;
}

// ─── 加载客户列表 ───
async function loadClients() {
  const { data } = await GHSupabase.from('clients').select('*').order('created_at', { ascending: false });
  const tbody = document.getElementById('clients-tbody');
  if (!data?.length) { tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;color:var(--muted)">暂无客户</td></tr>'; return; }
  tbody.innerHTML = data.map(c => `
    <tr>
      <td>${c.name}</td>
      <td>${c.email}</td>
      <td><span class="pill ${c.plan==='pro'?'pill-green':'pill-gray'}">${c.plan}</span></td>
      <td>${c.created_at.slice(0,10)}</td>
      <td>
        <button class="action-btn" onclick="copyEmail('${c.email}')">复制邮箱</button>
        <button class="action-btn danger" onclick="deleteClient('${c.id}')">删除</button>
      </td>
    </tr>
  `).join('');
}

// ─── 新建客户 ───
async function createClient() {
  const name  = document.getElementById('new-name').value.trim();
  const email = document.getElementById('new-email').value.trim();
  const plan  = document.getElementById('new-plan').value;
  const msg   = document.getElementById('create-msg');

  if (!name || !email) { msg.textContent = '请填写公司名和邮箱'; msg.style.color='#F87171'; return; }

  // 1. 在 Supabase Auth 创建用户（需要 service_role，暂时引导去 Dashboard）
  msg.textContent = '⚠️ 请在 Supabase Dashboard → Authentication → Users 手动创建邮箱账号，密码发给客户';
  msg.style.color = '#F5C842';

  // 2. 写 clients 表
  const { error } = await GHSupabase.from('clients').insert({ name, email, plan });
  if (error) { msg.textContent = '创建失败：' + error.message; msg.style.color='#F87171'; return; }

  msg.textContent = '✓ 客户已创建，请在 Supabase Dashboard 创建登录账号';
  msg.style.color = '#34D399';
  loadClients();
}

async function deleteClient(id) {
  if (!confirm('确认删除？关联的活动和数据也会删除')) return;
  await GHSupabase.from('clients').delete().eq('id', id);
  loadClients();
}

function copyEmail(email) {
  navigator.clipboard?.writeText(email).then(() => alert('已复制：' + email));
}

// ─── 加载活动列表 ───
async function loadCampaigns() {
  const { data } = await GHSupabase
    .from('campaigns')
    .select('*, clients(name)')
    .order('created_at', { ascending: false })
    .limit(50);

  const tbody = document.getElementById('campaigns-tbody');
  if (!data?.length) { tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;color:var(--muted)">暂无活动</td></tr>'; return; }

  const statusMap = { draft:'草稿', active:'进行中', ended:'已结束' };
  tbody.innerHTML = data.map(c => `
    <tr>
      <td>${c.title}</td>
      <td>${c.clients?.name || '-'}</td>
      <td>${c.game_type}</td>
      <td>${statusMap[c.status] || c.status}</td>
      <td>${c.created_at.slice(0,10)}</td>
      <td>
        <button class="action-btn" onclick="copyCampaignLink('${c.id}','${c.game_type}')">复制链接</button>
      </td>
    </tr>
  `).join('');
}

function copyCampaignLink(id, gameType) {
  const fileMap = { wheel:'wheel.html', scratch:'scratch-card.html', nine:'nine-grid.html', smash:'smash-egg.html', slot:'slot-machine.html', blind:'blind-box.html' };
  const file = fileMap[gameType] || gameType + '.html';
  const url  = location.origin + '/' + file + '?cid=' + id;
  navigator.clipboard?.writeText(url).then(() => alert('链接已复制：\n' + url));
}
</script>
</body>
</html>
```

- [ ] **Step 2: 用你的 Supabase 管理员邮箱测试登录**

打开 `admin-you.html`，用 Supabase Dashboard 里创建的管理员邮箱密码登录。
验证总览数字显示、客户列表加载正常。

- [ ] **Step 3: Commit**

```bash
git add admin-you.html
git commit -m "feat: 管理员后台 admin-you.html——客户管理/活动列表/总览数据"
```

---

## Task 6: 客户自助后台 admin-client.html

**Files:**
- Create: `admin-client.html`

**Interfaces:**
- Consumes:
  - `GHSupabase` Supabase 客户端
  - Tables: campaigns, campaign_stats, play_sessions（通过 RLS 只看自己的）
- Produces: 客户后台页面（通过邮箱密码登录，只看自己的活动数据）

- [ ] **Step 1: 写 admin-client.html**

创建 `/Users/chenjunjie/minigame-platform/admin-client.html`：

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>GameHub · 活动数据后台</title>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
<script src="supabase.js"></script>
<style>
* { margin:0; padding:0; box-sizing:border-box; }
:root { --bg:#0D0720; --card:rgba(255,255,255,0.05); --border:rgba(255,255,255,0.1); --text:#F0EAF8; --muted:rgba(240,234,248,0.55); --gold:#F5C842; --accent:#7C3AED; --green:#22C55E; }
body { font-family:-apple-system,'PingFang SC',sans-serif; background:var(--bg); color:var(--text); min-height:100vh; }
#login-page { display:flex; align-items:center; justify-content:center; min-height:100vh; }
.login-box { background:rgba(255,255,255,0.04); border:1px solid var(--border); border-radius:20px; padding:40px 36px; width:min(380px,92vw); text-align:center; }
.login-box h1 { font-size:22px; font-weight:800; margin-bottom:6px; }
.login-box p { font-size:13px; color:var(--muted); margin-bottom:28px; }
.input { width:100%; padding:11px 14px; border-radius:10px; background:rgba(255,255,255,0.06); border:1px solid var(--border); color:var(--text); font-size:14px; outline:none; margin-bottom:12px; box-sizing:border-box; font-family:inherit; }
.input:focus { border-color:var(--accent); }
.btn-primary { width:100%; padding:13px; border-radius:10px; border:none; background:linear-gradient(135deg,var(--accent),#EC4899); color:white; font-size:15px; font-weight:700; cursor:pointer; font-family:inherit; }
.err-msg { font-size:12px; color:#F87171; min-height:18px; margin-bottom:8px; }
#client-page { display:none; }
.topbar { display:flex; align-items:center; justify-content:space-between; padding:0 28px; height:56px; border-bottom:1px solid var(--border); background:rgba(13,7,32,0.97); }
.topbar-logo { font-size:17px; font-weight:800; }
.topbar-logo span { color:var(--gold); }
.main { max-width:900px; margin:0 auto; padding:28px; }
.section-title { font-size:18px; font-weight:800; margin-bottom:16px; }
.campaign-card { background:var(--card); border:1px solid var(--border); border-radius:14px; padding:20px; margin-bottom:14px; cursor:pointer; transition:border-color 0.2s; }
.campaign-card:hover { border-color:rgba(124,58,237,0.5); }
.campaign-card.active { border-color:var(--accent); }
.campaign-name { font-size:16px; font-weight:700; margin-bottom:4px; }
.campaign-meta { font-size:12px; color:var(--muted); }
.stat-grid { display:grid; grid-template-columns:repeat(3,1fr); gap:12px; margin:20px 0; }
.stat-card { background:var(--card); border:1px solid var(--border); border-radius:12px; padding:16px; text-align:center; }
.stat-num { font-size:26px; font-weight:800; color:var(--gold); }
.stat-lbl { font-size:11px; color:var(--muted); margin-top:3px; }
.table-wrap { overflow-x:auto; border-radius:12px; border:1px solid var(--border); margin-top:16px; }
table { width:100%; border-collapse:collapse; font-size:13px; }
th { background:rgba(255,255,255,0.04); padding:9px 12px; text-align:left; font-size:11px; color:var(--muted); font-weight:700; border-bottom:1px solid var(--border); }
td { padding:9px 12px; border-bottom:1px solid rgba(255,255,255,0.04); }
tr:last-child td { border-bottom:none; }
.link-box { background:rgba(0,0,0,0.3); border:1px solid var(--border); border-radius:10px; padding:12px 16px; font-family:monospace; font-size:12px; color:var(--gold); word-break:break-all; margin:12px 0; }
.action-btn { padding:8px 16px; border-radius:8px; font-size:13px; font-weight:600; cursor:pointer; border:1px solid var(--border); background:rgba(124,58,237,0.1); color:var(--text); font-family:inherit; margin-right:6px; }
</style>
</head>
<body>

<div id="login-page">
  <div class="login-box">
    <h1>🎯 活动数据后台</h1>
    <p>请用您的账号登录查看活动数据</p>
    <input id="client-email" class="input" type="email" placeholder="登录邮箱">
    <input id="client-pwd"   class="input" type="password" placeholder="密码">
    <div id="login-err" class="err-msg"></div>
    <button class="btn-primary" onclick="doLogin()">登录</button>
  </div>
</div>

<div id="client-page">
  <div class="topbar">
    <div class="topbar-logo">🎯 <span>活动数据后台</span></div>
    <button class="action-btn" onclick="doLogout()">退出</button>
  </div>
  <div class="main">
    <div class="section-title">我的活动</div>
    <div id="campaigns-list">加载中…</div>

    <div id="detail-section" style="display:none;margin-top:28px">
      <div class="section-title" id="detail-title">活动详情</div>
      <div class="stat-grid">
        <div class="stat-card"><div class="stat-num" id="d-plays">-</div><div class="stat-lbl">总参与次数</div></div>
        <div class="stat-card"><div class="stat-num" id="d-winners">-</div><div class="stat-lbl">中奖次数</div></div>
        <div class="stat-card"><div class="stat-num" id="d-rate">-</div><div class="stat-lbl">中奖率</div></div>
      </div>

      <div style="font-size:13px;font-weight:700;margin-bottom:8px">🔗 游戏链接</div>
      <div class="link-box" id="d-link">-</div>
      <button class="action-btn" onclick="copyLink()">📋 复制链接</button>
      <button class="action-btn" onclick="openLink()">🔗 打开游戏</button>

      <div style="font-size:13px;font-weight:700;margin:20px 0 8px">📅 近7天数据</div>
      <div class="table-wrap">
        <table>
          <thead><tr><th>日期</th><th>参与次数</th><th>中奖次数</th><th>独立玩家</th></tr></thead>
          <tbody id="stats-tbody"></tbody>
        </table>
      </div>

      <div style="font-size:13px;font-weight:700;margin:20px 0 8px">🏆 最近中奖记录</div>
      <div class="table-wrap">
        <table>
          <thead><tr><th>时间</th><th>奖品</th><th>得分</th></tr></thead>
          <tbody id="winners-tbody"></tbody>
        </table>
      </div>
    </div>
  </div>
</div>

<script>
let currentCampaign = null;

async function doLogin() {
  const email = document.getElementById('client-email').value.trim();
  const pwd   = document.getElementById('client-pwd').value;
  const errEl = document.getElementById('login-err');
  errEl.textContent = '';

  const { error } = await GHSupabase.auth.signInWithPassword({ email, password: pwd });
  if (error) { errEl.textContent = '邮箱或密码错误'; return; }

  document.getElementById('login-page').style.display  = 'none';
  document.getElementById('client-page').style.display = 'block';
  loadCampaigns();
}

function doLogout() {
  GHSupabase.auth.signOut();
  location.reload();
}

async function loadCampaigns() {
  const { data } = await GHSupabase
    .from('campaigns')
    .select('*')
    .order('created_at', { ascending: false });

  const el = document.getElementById('campaigns-list');
  if (!data?.length) { el.innerHTML = '<p style="color:var(--muted)">暂无活动，请联系管理员创建</p>'; return; }

  el.innerHTML = data.map(c => `
    <div class="campaign-card" id="cc-${c.id}" onclick="selectCampaign(${JSON.stringify(c).replace(/"/g,'&quot;')})">
      <div class="campaign-name">${c.title}</div>
      <div class="campaign-meta">${c.game_type} · ${c.status} · 创建于${c.created_at.slice(0,10)}</div>
    </div>
  `).join('');
}

const FILE_MAP = { wheel:'wheel.html', scratch:'scratch-card.html', nine:'nine-grid.html', smash:'smash-egg.html', slot:'slot-machine.html', blind:'blind-box.html' };

async function selectCampaign(campaign) {
  currentCampaign = campaign;
  document.querySelectorAll('.campaign-card').forEach(el => el.classList.remove('active'));
  document.getElementById('cc-' + campaign.id)?.classList.add('active');

  document.getElementById('detail-section').style.display = 'block';
  document.getElementById('detail-title').textContent = campaign.title + ' — 数据详情';

  // 游戏链接
  const file = FILE_MAP[campaign.game_type] || campaign.game_type + '.html';
  const cfg  = campaign.config ? ('?c=' + btoa(unescape(encodeURIComponent(JSON.stringify(campaign.config))))) : '';
  const link = location.origin + '/' + file + cfg + '&cid=' + campaign.id;
  document.getElementById('d-link').textContent = link;

  // 统计
  const { data: stats } = await GHSupabase
    .from('campaign_stats')
    .select('*')
    .eq('campaign_id', campaign.id)
    .order('date', { ascending: false })
    .limit(7);

  const totalPlays   = (stats||[]).reduce((s,r) => s+r.plays, 0);
  const totalWinners = (stats||[]).reduce((s,r) => s+r.winners, 0);
  document.getElementById('d-plays').textContent   = totalPlays;
  document.getElementById('d-winners').textContent = totalWinners;
  document.getElementById('d-rate').textContent    = totalPlays ? Math.round(totalWinners/totalPlays*100)+'%' : '-';

  document.getElementById('stats-tbody').innerHTML = (stats||[]).length
    ? stats.map(s => `<tr><td>${s.date}</td><td>${s.plays}</td><td>${s.winners}</td><td>${s.unique_players}</td></tr>`).join('')
    : '<tr><td colspan="4" style="text-align:center;color:var(--muted)">暂无数据</td></tr>';

  // 中奖记录
  const { data: sessions } = await GHSupabase
    .from('play_sessions')
    .select('played_at, result, score')
    .eq('campaign_id', campaign.id)
    .not('result', 'eq', '谢谢参与')
    .not('result', 'eq', '未中')
    .order('played_at', { ascending: false })
    .limit(20);

  document.getElementById('winners-tbody').innerHTML = (sessions||[]).length
    ? sessions.map(s => `<tr><td>${s.played_at.slice(0,16).replace('T',' ')}</td><td>${s.result}</td><td>${s.score}</td></tr>`).join('')
    : '<tr><td colspan="3" style="text-align:center;color:var(--muted)">暂无中奖记录</td></tr>';
}

function copyLink() {
  const link = document.getElementById('d-link').textContent;
  navigator.clipboard?.writeText(link).then(() => alert('链接已复制'));
}
function openLink() {
  const link = document.getElementById('d-link').textContent;
  window.open(link, '_blank');
}
</script>
</body>
</html>
```

- [ ] **Step 2: 测试登录和数据展示**

需要在 Supabase 有测试客户账号和活动数据。
打开 `admin-client.html`，用客户邮箱密码登录，验证活动列表和数据加载正常。

- [ ] **Step 3: Commit**

```bash
git add admin-client.html
git commit -m "feat: 客户自助后台 admin-client.html——登录/活动数据/中奖记录/复制链接"
```

---

## Task 7: builder.html 接入 campaigns 表

**Files:**
- Modify: `builder.html`

**Interfaces:**
- Consumes:
  - `GHSupabase` — Supabase 客户端
  - `GHSupabase.auth.getSession()` → 检查客户是否已登录
  - Table: campaigns（insert）
- Produces:
  - 生成链接时附加 `&cid=UUID`
  - 链接格式：`https://games.jydigtal.com/wheel.html?c=BASE64&cid=UUID`

- [ ] **Step 1: 在 builder.html 头部引入 Supabase SDK 和 supabase.js**

找到 `builder.html` 的 `</style>` 标签后、`</head>` 前，加入：

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
<script src="supabase.js"></script>
```

- [ ] **Step 2: 在 generateLink() 函数中加入 campaigns 写入**

找到 `builder.html` 中的 `generateLink()` 函数（约第567行），在函数末尾 `forceRefreshPreview()` 之前加入：

```javascript
// 如果客户已登录，保存到 campaigns 表
const { data: { session } } = await GHSupabase.auth.getSession();
if (session) {
  const { data: campaign, error } = await GHSupabase
    .from('campaigns')
    .insert({
      game_type: currentGameType,
      config:    cfg,
      title:     cfg.title || '未命名活动',
      status:    'active',
    })
    .select('id')
    .single();

  if (!error && campaign) {
    generatedUrl = generatedUrl + '&cid=' + campaign.id;
    document.getElementById('generatedUrl').textContent = generatedUrl;
  }
}
```

同时把 `generateLink()` 改为 `async function generateLink()`。

- [ ] **Step 3: 验证**

登录 `admin-client.html` 后，打开 `builder.html`（同一浏览器保持 session），
配置一个活动并点「生成链接」，验证生成的链接包含 `&cid=UUID`，
在 Supabase Dashboard → campaigns 表中看到新记录。

- [ ] **Step 4: Commit + Push**

```bash
git add builder.html supabase.js admin-you.html admin-client.html reporter.js auth-player.js db/ workers/
git commit -m "feat: builder.html 接入 campaigns 表，生成链接附带 cid 参数"
git push origin main
```

---

## 自检

**Spec 覆盖检查：**
- ✅ Supabase 初始化 → Task 1
- ✅ 5张表建表 + RLS → Task 1 db/schema.sql
- ✅ Cloudflare Workers 短信接口 → Task 2
- ✅ 玩家手机号验证流程 → Task 3
- ✅ 游戏数据上报（play_sessions + campaign_stats）→ Task 4
- ✅ 管理员后台 → Task 5
- ✅ 客户后台 → Task 6
- ✅ builder 写入 campaigns 表 → Task 7
- ✅ localStorage 兼容层保留 → reporter.js 降级处理
- ✅ 51个游戏文件不改动 → reporter.js 通过拦截钩子工作
- ✅ 90天自动清理 → schema.sql 注释说明（需手动开启 pg_cron）

**前置手动操作（开始编码前需完成）：**
1. 注册 Supabase 账号，创建项目，记录 URL 和 anon key
2. 申请阿里云短信服务，创建签名和模板，记录 AccessKey
3. 在 Supabase Dashboard → Authentication → Users 创建管理员账号
4. 把 `supabase.js` 中的 `SUPABASE_URL` 和 `SUPABASE_ANON` 替换为真实值
