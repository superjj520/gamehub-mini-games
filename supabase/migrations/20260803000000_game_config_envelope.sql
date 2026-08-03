-- 版本化游戏配置：保留 blocks 兼容字段，新增统一配置载体。
alter table user_configs
  add column if not exists config_version integer not null default 1;

alter table user_configs
  add column if not exists config_payload jsonb;

update user_configs
  set config_payload = jsonb_build_object('blocks', coalesce(blocks, '[]'::jsonb))
  where config_payload is null;

comment on column user_configs.config_version is '玩法配置版本，用于迁移历史分享链接';
comment on column user_configs.config_payload is '版本化玩法配置；blocks 字段仅为旧页面兼容';
