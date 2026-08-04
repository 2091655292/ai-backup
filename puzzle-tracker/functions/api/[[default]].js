import { handleApiRequest } from '../_shared/app.js';
import { createKvStore } from '../_shared/store.js';

export async function onRequest({ request, env }) {
  const store = createKvStore(env.PUZZLE_KV);
  return handleApiRequest(request, store, { env });
}
