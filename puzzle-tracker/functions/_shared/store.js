export function createKvStore(kv) {
  if (!kv) {
    return {
      bound: false,
      get: async () => null,
      put: async () => {
        throw new Error('KV 命名空间未绑定（PUZZLE_KV）');
      },
      del: async () => {
        throw new Error('KV 命名空间未绑定（PUZZLE_KV）');
      },
      putIfAbsent: async () => {
        throw new Error('KV 命名空间未绑定（PUZZLE_KV）');
      },
    };
  }
  return {
    bound: true,
    get: (key) => kv.get(key, 'text'),
    put: (key, value) => kv.put(key, String(value)),
    del: (key) => kv.delete(key),
    // 边缘 KV 无原子写入能力，退化为先查后写
    putIfAbsent: async (key, value) => {
      if ((await kv.get(key, 'text')) != null) return false;
      await kv.put(key, String(value));
      return true;
    },
  };
}
