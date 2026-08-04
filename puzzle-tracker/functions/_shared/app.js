import { hashPassword, verifyPassword, signToken, verifyToken, hexEncode } from './crypto.js';

export const PUZZLE_SIZES = { 1: 4, 2: 6, 3: 9 };

const CORS_HEADERS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'access-control-allow-headers': 'Authorization, Content-Type',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json; charset=UTF-8', ...CORS_HEADERS },
  });
}

function fail(message, status = 400) {
  return json({ error: message }, status);
}

function getJwtSecret(env) {
  return (env && env.JWT_SECRET) || 'puzzle-tracker-dev-secret-change-me';
}

async function parseBody(request) {
  try {
    return await request.json();
  } catch {
    return {};
  }
}

async function kvGet(store, key) {
  return store.get(key);
}

async function kvPut(store, key, value) {
  return store.put(key, value);
}

async function kvDel(store, key) {
  return store.del(key);
}

async function nextSeq(store, key) {
  const cur = Number(await kvGet(store, key)) || 0;
  const next = cur + 1;
  await kvPut(store, key, String(next));
  return next;
}

async function getUserById(store, id) {
  const raw = await kvGet(store, `user_${id}`);
  return raw ? JSON.parse(raw) : null;
}

async function getUserByUsername(store, username) {
  const id = await kvGet(store, `un_${hexEncode(username)}`);
  if (!id) return null;
  return getUserById(store, id);
}

async function getCardsRecord(store, userId) {
  const raw = await kvGet(store, `cards_${userId}`);
  return raw ? JSON.parse(raw) : { seq: 0, list: [] };
}

async function getCard(store, userId, cardId) {
  const raw = await kvGet(store, `card_${userId}_${cardId}`);
  return raw ? JSON.parse(raw) : null;
}

function computePuzzleSummary(pieces) {
  const summary = {};
  for (const p of [1, 2, 3]) {
    const total = PUZZLE_SIZES[p];
    let owned = 0;
    let duplicate = 0;
    for (let s = 0; s < total; s++) {
      const c = pieces[`${p}:${s}`] || 0;
      if (c > 0) owned++;
      duplicate += Math.max(0, c - 1);
    }
    summary[p] = { total, owned, complete: owned >= total, duplicate };
  }
  return summary;
}

function publicUser(u) {
  return { id: u.id, username: u.username, nickname: u.nickname };
}

async function requireAuth(store, request, env, handler) {
  const header = request.headers.get('authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return fail('未登录', 401);
  const payload = await verifyToken(token, getJwtSecret(env));
  if (!payload) return fail('登录已过期，请重新登录', 401);
  const user = await getUserById(store, payload.sub);
  if (!user) return fail('登录已过期，请重新登录', 401);
  return handler(user);
}

async function register(request, store, env) {
  const { username, password, nickname } = await parseBody(request);
  const uname = String(username || '').trim();
  const pwd = String(password || '');
  if (!/^[A-Za-z0-9_\u4e00-\u9fa5]{2,30}$/.test(uname)) {
    return fail('用户名需为 2-30 位字母、数字、下划线或中文');
  }
  if (pwd.length < 4 || pwd.length > 72) return fail('密码长度需为 4-72 位');
  if (await getUserByUsername(store, uname)) return fail('用户名已被注册', 409);
  const passwordHash = await hashPassword(pwd);
  const id = await nextSeq(store, 'seq_user');
  const now = new Date().toISOString();
  const user = { id, username: uname, passwordHash, nickname: String(nickname || '').trim(), createdAt: now };
  await kvPut(store, `user_${id}`, JSON.stringify(user));
  await kvPut(store, `un_${hexEncode(uname)}`, String(id));
  await kvPut(store, `cards_${id}`, JSON.stringify({ seq: 0, list: [] }));
  const token = await signToken({ sub: id }, getJwtSecret(env));
  return json({ token, user: publicUser(user) }, 201);
}

async function login(request, store, env) {
  const { username, password } = await parseBody(request);
  const user = await getUserByUsername(store, String(username || '').trim());
  if (!user || !(await verifyPassword(String(password || ''), user.passwordHash))) {
    return fail('用户名或密码错误', 401);
  }
  const token = await signToken({ sub: user.id }, getJwtSecret(env));
  return json({ token, user: publicUser(user) });
}

async function listCards(store, user) {
  const rec = await getCardsRecord(store, user.id);
  const cards = [];
  for (const c of rec.list) {
    const data = await getCard(store, user.id, c.id);
    const pieces = data ? data.pieces : {};
    cards.push({
      id: c.id,
      name: c.name,
      note: c.note,
      created_at: c.createdAt,
      counts: pieces,
      puzzleSummary: computePuzzleSummary(pieces),
    });
  }
  cards.sort((a, b) => b.id - a.id);
  return json({ cards });
}

async function createCard(request, store, user) {
  const { name, note } = await parseBody(request);
  const cname = String(name || '').trim();
  if (!cname) return fail('卡片名称不能为空');
  if (cname.length > 30) return fail('卡片名称过长');
  const rec = await getCardsRecord(store, user.id);
  const id = rec.seq + 1;
  rec.seq = id;
  const now = new Date().toISOString();
  const item = { id, name: cname, note: String(note || '').trim(), createdAt: now };
  rec.list.push(item);
  await kvPut(store, `cards_${user.id}`, JSON.stringify(rec));
  await kvPut(store, `card_${user.id}_${id}`, JSON.stringify({ name: cname, note: item.note, createdAt: now, pieces: {} }));
  return json({
    card: { id, name: cname, note: item.note, created_at: now, counts: {}, puzzleSummary: computePuzzleSummary({}) },
  }, 201);
}

async function updateCard(request, store, user, cardId) {
  const rec = await getCardsRecord(store, user.id);
  const item = rec.list.find((c) => c.id === Number(cardId));
  if (!item) return fail('卡片不存在', 404);
  const data = (await getCard(store, user.id, item.id)) || { name: item.name, note: item.note, createdAt: item.createdAt, pieces: {} };
  const { name, note } = await parseBody(request);
  if (name !== undefined) item.name = String(name).trim().slice(0, 30);
  if (note !== undefined) data.note = String(note).trim().slice(0, 200);
  data.name = item.name;
  await kvPut(store, `cards_${user.id}`, JSON.stringify(rec));
  await kvPut(store, `card_${user.id}_${item.id}`, JSON.stringify(data));
  return json({ ok: true });
}

async function deleteCard(store, user, cardId) {
  const rec = await getCardsRecord(store, user.id);
  const idx = rec.list.findIndex((c) => c.id === Number(cardId));
  if (idx < 0) return fail('卡片不存在', 404);
  rec.list.splice(idx, 1);
  await kvPut(store, `cards_${user.id}`, JSON.stringify(rec));
  await kvDel(store, `card_${user.id}_${cardId}`);
  return json({ ok: true });
}

async function setPiece(request, store, user, cardId, puzzleStr, slotStr) {
  const rec = await getCardsRecord(store, user.id);
  const item = rec.list.find((c) => c.id === Number(cardId));
  if (!item) return fail('卡片不存在', 404);
  const puzzle = Number(puzzleStr);
  const slot = Number(slotStr);
  if (!PUZZLE_SIZES[puzzle] || slot < 0 || slot >= PUZZLE_SIZES[puzzle]) {
    return fail('拼图或位置参数无效');
  }
  let count = Number((await parseBody(request)).count);
  if (!Number.isInteger(count) || count < 0 || count > 99) return fail('数量需为 0-99 的整数');
  const data = (await getCard(store, user.id, item.id)) || { name: item.name, note: item.note, createdAt: item.createdAt, pieces: {} };
  data.pieces[`${puzzle}:${slot}`] = count;
  await kvPut(store, `card_${user.id}_${item.id}`, JSON.stringify(data));
  return json({ ok: true });
}

export async function handleApiRequest(request, store, { env } = {}) {
  const url = new URL(request.url);
  const path = url.pathname;
  const method = request.method;

  if (method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS_HEADERS });

  try {
    if (method === 'POST' && path === '/api/auth/register') return register(request, store, env);
    if (method === 'POST' && path === '/api/auth/login') return login(request, store, env);
    if (method === 'GET' && path === '/api/auth/me') {
      return requireAuth(store, request, env, (user) => json({ user: publicUser(user) }));
    }

    if (path === '/api/cards') {
      if (method === 'GET') return requireAuth(store, request, env, (user) => listCards(store, user));
      if (method === 'POST') return requireAuth(store, request, env, (user) => createCard(request, store, user));
    }

    let m = path.match(/^\/api\/cards\/(\d+)$/);
    if (m) {
      if (method === 'PATCH') return requireAuth(store, request, env, (user) => updateCard(request, store, user, m[1]));
      if (method === 'DELETE') return requireAuth(store, request, env, (user) => deleteCard(store, user, m[1]));
    }

    m = path.match(/^\/api\/cards\/(\d+)\/pieces\/(\d+)\/(\d+)$/);
    if (m && method === 'PUT') {
      return requireAuth(store, request, env, (user) => setPiece(request, store, user, m[1], m[2], m[3]));
    }

    return fail('接口不存在', 404);
  } catch (err) {
    console.error(err);
    return fail('服务器内部错误', 500);
  }
}
