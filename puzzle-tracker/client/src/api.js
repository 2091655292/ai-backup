const TOKEN_KEY = 'puzzle_tracker_token';

export const puzzles = {
  1: { name: '拼图一', total: 4, cols: 2, rows: 2, desc: '2 × 2 正方形' },
  2: { name: '拼图二', total: 6, cols: 2, rows: 3, desc: '左 3 右 3' },
  3: { name: '拼图三', total: 9, cols: 3, rows: 3, desc: '3 × 3 九宫格' },
};

export function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token) {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
}

async function request(method, url, body) {
  const headers = { 'Content-Type': 'application/json' };
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`/api${url}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try {
    data = await res.json();
  } catch {
    /* empty body */
  }
  if (!res.ok) {
    if (res.status === 401 && url !== '/auth/me') {
      clearToken();
      window.location.reload();
    }
    const err = new Error(data?.error || `请求失败(${res.status})`);
    err.status = res.status;
    throw err;
  }
  return data;
}

export const api = {
  register: (body) => request('POST', '/auth/register', body),
  login: (body) => request('POST', '/auth/login', body),
  me: () => request('GET', '/auth/me'),
  listCards: () => request('GET', '/cards'),
  createCard: (body) => request('POST', '/cards', body),
  updateCard: (id, body) => request('PATCH', `/cards/${id}`, body),
  deleteCard: (id) => request('DELETE', `/cards/${id}`),
  syncData: (body) => request('PUT', '/data', body),
};
