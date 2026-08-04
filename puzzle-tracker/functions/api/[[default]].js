import { handleApiRequest } from '../_shared/app.js';
import { createKvStore } from '../_shared/store.js';

function jsonError(message, status) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'content-type': 'application/json; charset=UTF-8', 'access-control-allow-origin': '*' },
  });
}

function resolveKvBinding(env) {
  if (env && env.PUZZLE_KV) return env.PUZZLE_KV;
  if (typeof globalThis !== 'undefined' && globalThis.PUZZLE_KV) return globalThis.PUZZLE_KV;
  return undefined;
}

export async function onRequest({ request, env }) {
  try {
    const kv = resolveKvBinding(env);
    if (!kv) {
      return jsonError('KV 命名空间未绑定：请在 EdgeOne Makers 控制台的 KV 存储中「绑定命名空间」，变量名称填 PUZZLE_KV，并重新部署', 503);
    }
    const store = createKvStore(kv);
    return await handleApiRequest(request, store, { env });
  } catch (err) {
    console.error('EdgeOne function error:', err && err.stack ? err.stack : err);
    return jsonError(`边缘函数执行异常：${err && err.message ? err.message : err}`, 500);
  }
}
