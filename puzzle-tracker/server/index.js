import express from 'express';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { handleApiRequest } from '../functions/_shared/app.js';
import { createLocalStore } from './local-store.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const PORT = process.env.PORT || 3001;

app.use(express.json({ limit: '1mb' }));

const store = createLocalStore();

function toWebRequest(req) {
  const protocol = req.headers['x-forwarded-proto'] || 'http';
  const host = req.headers.host || 'localhost';
  const url = `${protocol}://${host}${req.originalUrl}`;
  const headers = new Headers();
  for (const [k, v] of Object.entries(req.headers)) {
    if (typeof v === 'string') headers.append(k, v);
  }
  const init = { method: req.method, headers };
  if (req.body !== undefined && req.body !== null && Object.keys(req.body).length > 0) {
    init.body = JSON.stringify(req.body);
  }
  return new Request(url, init);
}

async function bridge(req, res) {
  try {
    const webReq = toWebRequest(req);
    const webRes = await handleApiRequest(webReq, store, { env: process.env });
    res.status(webRes.status);
    webRes.headers.forEach((value, key) => res.setHeader(key, value));
    const body = await webRes.text();
    res.send(body);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '服务器内部错误' });
  }
}

app.use('/api', bridge);

const distDir = path.join(__dirname, '..', 'client', 'dist');
if (fs.existsSync(path.join(distDir, 'index.html'))) {
  app.use(express.static(distDir));
  app.use((req, res, next) => {
    if (req.method !== 'GET' || req.path.startsWith('/api')) return next();
    res.sendFile(path.join(distDir, 'index.html'));
  });
}

app.listen(PORT, () => {
  console.log(`Puzzle tracker local server listening on http://localhost:${PORT}`);
});
