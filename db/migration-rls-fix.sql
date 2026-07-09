-- ═══════════════════════════════════════════
-- GameHub 数据库迁移：修复 RLS 策略
-- 在 Supabase Dashboard → SQL Editor 执行
-- ═══════════════════════════════════════════

-- 1. clients：允许管理员（通过邮箱）管理
drop policy if exists "service_role 管理客户" on clients;
create policy "管理员管理客户" on clients
  for all using (
    auth.role() = 'service_role'
    or auth.jwt()->>'email' = 'superjj199901@gmail.com'
  );

-- 2. players：email 登录后玩家可管理自己
drop policy if exists "玩家数据开放写入" on players;
create policy "玩家管理自己" on players
  for all using (
    auth.role() = 'service_role'
    or email = auth.email()
  );

-- 3. play_sessions：客户可读自己活动的流水（修复 bug）
drop policy if exists "玩家查自己的流水" on play_sessions;
create policy "读流水" on play_sessions
  for select using (
    auth.role() = 'service_role'
    or player_id in (select id from players where email = auth.email())
    or campaign_id in (
      select c.id from campaigns c
      join clients cl on cl.id = c.client_id
      where cl.email = auth.email()
    )
  );

-- 4. campaign_stats：允许玩家写入统计（修复 bug）
drop policy if exists "写统计" on campaign_stats;
create policy "玩家写统计" on campaign_stats
  for all using (
    auth.role() = 'service_role'
    or true
  );
