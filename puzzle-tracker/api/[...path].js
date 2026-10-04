import { handleApiRequest } from '../functions/_shared/app.js';
import { createPgStore } from '../functions/_shared/pg-store.js';

export const config = { runtime: 'edge' };

function jsonError(message, status) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'content-type': 'application/json; charset=UTF-8', 'access-control-allow-origin': '*' },
  });
}

export default async function handler(request) {
  if (!process.env.DATABASE_URL && !process.env.POSTGRES_URL && !process.env.DATABASE_URL_UNPOOLED) {
    return jsonError('未配置数据库连接：请在 Vercel 项目中安装 Postgres（Neon）存储集成，连接串会自动注入为 DATABASE_URL', 503);
  }
  try {
    const store = createPgStore();
    return await handleApiRequest(request, store, { env: process.env });
  } catch (err) {
    console.error('Vercel function error:', err && err.stack ? err.stack : err);
    return jsonError(`函数执行异常：${err && err.message ? err.message : err}`, 500);
  }
}
