#!/bin/bash
# GameHub 2.0 一键部署脚本
# 先执行: supabase login
set -e

PROJECT="ybyputkhtrejnqyblvdc"

echo "🚀 GameHub 2.0 部署"
echo ""

# 1. 数据库迁移
echo "📋 Step 1: SQL 迁移"
supabase db push --linked --project-ref "$PROJECT" 2>/dev/null || {
  echo "通过 CLI 执行需要先 link 项目。改用直接提交方式..."
  PGPASSWORD=$(supabase db password --project-ref "$PROJECT" 2>/dev/null) || true
  if [ -n "$PGPASSWORD" ]; then
    psql "postgresql://postgres@db.${PROJECT}.supabase.co:5432/postgres" -f db/migration-v2.sql
    echo "✅ 迁移完成"
  else
    echo "⚠️  请在 Supabase Dashboard 中手动执行 db/migration-v2.sql"
  fi
}

# 2. AI 助手部署
echo ""
echo "📋 Step 2: AI 助手 (DeepSeek)"
read -p "DeepSeek API Key (直接回车跳过): " DEEPSEEK_KEY
if [ -n "$DEEPSEEK_KEY" ]; then
  cd supabase/functions
  supabase functions deploy ai-config --no-verify-jwt
  supabase secrets set DEEPSEEK_API_KEY="$DEEPSEEK_KEY"
  cd ../..
  echo "✅ 部署完成"
else
  echo "⏭️  跳过"
fi

echo ""
echo "🎉 完成！访问 https://gamehub.io 查看"
