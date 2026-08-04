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
    cache = {};
  }
  return cache;
}

export function createLocalStore() {
  const data = load();
  const save = () => {
    fs.writeFileSync(dataFile, JSON.stringify(data));
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
