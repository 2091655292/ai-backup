#!/bin/bash
# 启动前后端服务：先启动后端，再启动前端（前端带反向代理 /api -> 后端）
set -e

cd "$(dirname "$0")"

echo "启动后端服务 (端口 3001)..."
cd server
node index.js &
SERVER_PID=$!

echo "启动前端服务 (端口 5173)..."
cd ../client
npm run dev

cleanup() {
  kill $SERVER_PID 2>/dev/null || true
}
trap cleanup EXIT
