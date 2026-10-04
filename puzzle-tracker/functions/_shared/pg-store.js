import { neon } from '@neondatabase/serverless';

// Vercel Postgres（Neon 原生集成）适配器：单表 app_kv(key, value) 映射现有 KV 数据模型，
// 接口与 functions/_shared/store.js 一致（get/put/del + putIfAbsent）。
// Postgres 强一致 + 主键约束，注册用户名抢占是原子的。
// Neon 的 HTTP 驱动在 Edge Runtime 可用，标签模板直接返回行数组。
export function createPgStore() {
  const connectionString =
    process.env.DATABASE_URL ||
    process.env.POSTGRES_URL ||
    process.env.DATABASE_URL_UNPOOLED;
  const sql = neon(connectionString);
  let ready = null;
  const ensureTable = () => {
    if (!ready) {
      ready = sql`CREATE TABLE IF NOT EXISTS app_kv (key TEXT PRIMARY KEY, value TEXT NOT NULL)`;
    }
    return ready;
  };

  return {
    bound: true,
    get: async (key) => {
      await ensureTable();
      const rows = await sql`SELECT value FROM app_kv WHERE key = ${key}`;
      return rows.length ? rows[0].value : null;
    },
    put: async (key, value) => {
      await ensureTable();
      await sql`INSERT INTO app_kv (key, value) VALUES (${key}, ${String(value)})
        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`;
    },
    del: async (key) => {
      await ensureTable();
      await sql`DELETE FROM app_kv WHERE key = ${key}`;
    },
    putIfAbsent: async (key, value) => {
      await ensureTable();
      const rows = await sql`INSERT INTO app_kv (key, value) VALUES (${key}, ${String(value)})
        ON CONFLICT (key) DO NOTHING RETURNING key`;
      return rows.length > 0;
    },
  };
}