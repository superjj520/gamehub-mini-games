/**
 * GameHub 数据库迁移助手
 * 运行方式：node db/migrate.mjs
 * 注意：需要 SUPABASE_SERVICE_ROLE_KEY 环境变量
 */

import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = 'https://ybyputkhtrejnqyblvdc.supabase.co'

// 优先用环境变量，否则交互式输入
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY
if (!SERVICE_KEY) {
  console.error('请设置 SUPABASE_SERVICE_ROLE_KEY 环境变量')
  console.error('获取方式：Supabase Dashboard → Settings → API → service_role key')
  process.exit(1)
}

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
})

const sql = `
-- clients RLS: 允许管理员邮箱管理
drop policy if exists "service_role 管理客户" on clients;
create policy "管理员管理客户" on clients
  for all using (
    auth.role() = 'service_role'
    or auth.jwt()->>'email' = 'superjj199901@gmail.com'
  );

-- players RLS: 玩家可管理自己
drop policy if exists "玩家数据开放写入" on players;
create policy "玩家管理自己" on players
  for all using (
    auth.role() = 'service_role'
    or email = auth.email()
  );

-- play_sessions: 客户可读自己活动的流水
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

-- campaign_stats: 允许玩家写入
drop policy if exists "写统计" on campaign_stats;
create policy "玩家写统计" on campaign_stats
  for all using (
    auth.role() = 'service_role'
    or true
  );
`

async function main() {
  console.log('正在执行数据库迁移...')

  // 通过 REST API 执行 SQL（使用 service_role 自动跳过 RLS）
  const { error } = await supabase.rpc('pg_ddl', { query: sql })

  if (error) {
    console.error('迁移失败:', error.message)
    console.log('\n请手动在 Supabase Dashboard → SQL Editor 执行:')
    console.log('db/migration-rls-fix.sql')
    process.exit(1)
  }

  console.log('迁移成功！')
}

main()
