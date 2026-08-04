export function createKvStore(kv) {
  if (!kv) throw new Error('未绑定 KV 命名空间，请在项目设置中创建并绑定 PUZZLE_KV');
  return {
    get: (key) => kv.get(key, 'text'),
    put: (key, value) => kv.put(key, String(value)),
    del: (key) => kv.delete(key),
  };
}
