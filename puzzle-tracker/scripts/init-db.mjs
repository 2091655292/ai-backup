import { neon } from '@neondatabase/serverless';

// 初始化 Vercel Postgres 数据表：npm run db:init
const connectionString =
  process.env.DATABASE_URL ||
  process.env.POSTGRES_URL ||
  process.env.DATABASE_URL_UNPOOLED;

if (!connectionString) {
  console.error('缺少数据库连接环境变量。请在 Vercel 项目安装 Neon Postgres 集成后执行 `vercel env pull .env.local`，或手动设置 DATABASE_URL。');
  process.exit(1);
}

try {
  const sql = neon(connectionString);
  await sql`CREATE TABLE IF NOT EXISTS app_kv (key TEXT PRIMARY KEY, value TEXT NOT NULL)`;
  console.log('数据库初始化完成：app_kv 表已就绪');
  process.exit(0);
} catch (err) {
  console.error('数据库初始化失败：', err.message);
  process.exit(1);
}