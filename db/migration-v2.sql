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

drop policy if exists "所有人可读已发布的配置" on user_configs;
create policy "所有人可读已发布的配置" on user_configs
  for select using (is_published = true);

drop policy if exists "用户管理自己的配置" on user_configs;
create policy "用户管理自己的配置" on user_configs
  for all using (
    auth.role() = 'service_role'
    or user_id in (select id from players where email = auth.email())
  );
