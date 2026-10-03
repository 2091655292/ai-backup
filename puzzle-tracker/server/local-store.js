import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dataDir = process.env.PUZZLE_DATA_DIR || path.join(__dirname, 'data');
const dataFile = path.join(dataDir, 'kv.json');

if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

let cache = null;

function load() {
  if (cache) return cache;
  try {
    cache = JSON.parse(fs.readFileSync(dataFile, 'utf8'));
  } catch {
    // 文件缺失或损坏：损坏时保留一份 .bak 供人工恢复，避免静默丢数据
    try {
      fs.copyFileSync(dataFile, dataFile + '.bak');
    } catch {
      /* 文件不存在则跳过 */
    }
    cache = {};
  }
  return cache;
}

export function createLocalStore() {
  const data = load();
  const save = () => {
    // 先写临时文件再 rename，rename 在同一文件系统上是原子操作，
    // 即使写入中途进程崩溃也不会留下损坏的半截 JSON。
    const tmp = dataFile + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify(data));
    fs.renameSync(tmp, dataFile);
  };
  return {
    get: async (key) => (key in data ? data[key] : null),
    put: async (key, value) => {
      data[key] = String(value);
      save();
    },
    del: async (key) => {
      delete data[key];
      save();
    },
  };
}
