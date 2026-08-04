import { handleApiRequest } from '../_shared/app.js';
import { createKvStore } from '../_shared/store.js';

function jsonError(message, status) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'content-type': 'application/json; charset=UTF-8', 'access-control-allow-origin': '*' },
  });
}

export async function onRequest({ request, env }) {
  try {
    const store = createKvStore(env.PUZZLE_KV);
    if (!store.bound) {
      return jsonError('KV 命名空间未绑定：请在 EdgeOne Makers 控制台创建 KV 命名空间并绑定到本项目，绑定变量名填 PUZZLE_KV', 503);
    }
    return await handleApiRequest(request, store, { env });
  } catch (err) {
    console.error('EdgeOne function error:', err && err.stack ? err.stack : err);
    return jsonError(`边缘函数执行异常：${err && err.message ? err.message : err}`, 500);
  }
}
