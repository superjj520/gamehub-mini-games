-- ═══════════════════════════════════════════
-- GameHub 数据库 Schema（最终版）
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
  client_id   uuid references clients(id) on delete cascade,
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
  phone       text,
  email       text not null unique,
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

-- clients：管理员（通过 Edge Function + service_role）和管理后台登录用户可管理
drop policy if exists "service_role 管理客户" on clients;
create policy "管理员管理客户" on clients
  for all using (
    auth.role() = 'service_role'
    or auth.jwt()->>'email' = 'superjj199901@gmail.com'  -- 管理员邮箱
  );

-- campaigns：客户只能看/改自己的
drop policy if exists "客户读自己的活动" on campaigns;
drop policy if exists "客户改自己的活动" on campaigns;

create policy "客户读自己的活动" on campaigns
  for select using (
    auth.role() = 'service_role'
    or client_id in (select id from clients where email = auth.email())
  );

create policy "客户改自己的活动" on campaigns
  for all using (
    auth.role() = 'service_role'
    or client_id in (select id from clients where email = auth.email())
  );

-- players：已登录用户可 upsert（验证码验证通过后写入）
drop policy if exists "玩家数据开放写入" on players;
create policy "玩家管理自己" on players
  for all using (
    auth.role() = 'service_role'
    or email = auth.email()
  );

-- play_sessions：认证用户可以插入
drop policy if exists "玩家插入流水" on play_sessions;
drop policy if exists "玩家查自己的流水" on play_sessions;

create policy "玩家插入流水" on play_sessions
  for insert with check (true);

create policy "读流水" on play_sessions
  for select using (
    auth.role() = 'service_role'
    -- 玩家查自己
    or player_id in (select id from players where email = auth.email())
    -- 客户查自己活动的统计
    or campaign_id in (
      select c.id from campaigns c
      join clients cl on cl.id = c.client_id
      where cl.email = auth.email()
    )
  );

-- campaign_stats：客户端插入，客户读自己活动的统计
drop policy if exists "客户读统计" on campaign_stats;
drop policy if exists "写统计" on campaign_stats;

create policy "客户读统计" on campaign_stats
  for select using (
    auth.role() = 'service_role'
    or campaign_id in (
      select c.id from campaigns c
      join clients cl on cl.id = c.client_id
      where cl.email = auth.email()
    )
  );

create policy "玩家写统计" on campaign_stats
  for all using (
    auth.role() = 'service_role'
    or true  -- 允许任何认证用户 upsert（通过匿名键 + 登录session）
  );

-- ═══════════════════════════════════════════
-- 90天自动清理 play_sessions
-- 在 Supabase Dashboard → Database → Extensions 开启 pg_cron 后执行：
-- select cron.schedule('清理90天流水', '0 3 * * *',
--   $$ delete from play_sessions where played_at < now() - interval '90 days' $$
-- );
-- ═══════════════════════════════════════════
