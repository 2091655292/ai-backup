# 话费折拼图记录工具

面向中国移动「8 折充值话费折」活动的拼图收集记录工具，支持多张电话卡独立记录三套拼图的收集情况，用于管理重复拼图片的赠送。

## 功能

- **多卡管理**：为每个手机号添加独立卡片，互不干扰
- **三种拼图网格**：
  - 拼图一：4 片，2×2 正方形
  - 拼图二：6 片，左 3 右 3
  - 拼图三：9 片，3×3 九宫格
- **重复片管理**：每片可记录数量，自动统计「多余可赠送」的片，并在网格角标和赠送清单中展示
- **集齐状态**：自动计算每套拼图完成进度（x/4、x/6、x/9）
- **账号同步**：注册账号后数据保存在云端，多设备可同步

## 技术栈

- 前端：Vue 3 + Vite（构建产物 `client/dist`）
- 后端：EdgeOne Pages Functions（`functions/` 目录，边缘 Serverless）
- 存储：**EdgeOne KV 存储**（Makers 原生数据库，命名空间绑定）
- 认证：PBKDF2 密码哈希 + JWT（基于 Web Crypto，零第三方依赖，前后端共享同一份代码）

## 目录结构

```
.
├── functions/            # EdgeOne Pages Functions 后端
│   ├── api/[[default]].js    # /api/* 入口
│   └── _shared/              # 共享业务逻辑（crypto / store / app）
├── client/               # Vue 3 前端（构建到 client/dist）
├── server/               # 本地开发后端（复用 functions/_shared 逻辑）
│   └── local-store.js        # 本地文件持久化 KV（server/data/kv.json）
├── edgeone.json          # EdgeOne Makers 平台配置
└── start.sh              # 本地开发一键启动
```

## 本地开发

```bash
# 安装依赖
cd server && npm install
cd ../client && npm install

# 启动（后端 3001，前端 5173 并代理 /api 到后端）
./start.sh
```

本地后端与云端 EdgeOne 函数共用同一份业务代码（`functions/_shared/app.js`），仅存储实现不同：本地用文件 KV（`server/data/kv.json`），云端用 EdgeOne KV。

## 部署到 EdgeOne Makers（原 EdgeOne Pages）

EdgeOne Makers 是腾讯云边缘全栈平台：静态资源全球托管，`/functions` 目录自动转为边缘 Serverless API，**KV 存储**作为原生数据库（控制台开通后创建命名空间并绑定项目即可，无需自建数据库）。

### 步骤一：推送代码到 GitHub

将本仓库推送到你的 GitHub 仓库（建议 main 分支）。

### 步骤二：在 Makers 控制台创建项目

1. 打开 EdgeOne Makers 控制台，选择「导入 Git 仓库」，关联并选择你的仓库
2. 项目设置使用根目录下已提供的 `edgeone.json`（自动识别，无需手动填），关键配置：
   - 构建命令：`npm run build`（前端 Vite 构建）
   - 输出目录：`client/dist`
   - Node 版本：22.11.0
   - SPA 路由：`/*` → `/index.html`（已配置，`/api/*` 交给函数）

### 步骤三：开通并绑定 KV 命名空间（原生数据库）

1. 在 Makers 控制台找到 **KV 存储**，开通后创建一个命名空间（如 `puzzle-kv`）
2. 进入项目的「设置 → 环境变量 / 绑定」，将 KV 命名空间**绑定到项目**，绑定变量名填 **`PUZZLE_KV`**（代码中的绑定名）

### 步骤四：配置环境变量

在项目设置中添加环境变量：

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `JWT_SECRET` | JWT 签名密钥，用于登录态，务必设置成强随机值 | `openssl rand -hex 32` 生成 |

### 步骤五：触发部署

推送代码或点击控制台「部署」，构建完成后通过预览域名访问即可。之后每次 git push 自动重新部署。

## API 概览

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/auth/register | 注册 |
| POST | /api/auth/login | 登录 |
| GET | /api/auth/me | 当前用户 |
| GET | /api/cards | 卡片列表（含拼图汇总） |
| POST | /api/cards | 添加卡片 |
| PATCH | /api/cards/:id | 修改卡片 |
| DELETE | /api/cards/:id | 删除卡片 |
| PUT | /api/cards/:id/pieces/:puzzle/:slot | 设置某片数量 |

## 自建服务器部署（可选）

如不用 EdgeOne，也可单进程部署到自己的服务器（Node 22.5+）：

```bash
cd client && npm install && npm run build
cd ../server && npm install --omit=dev
PORT=3000 node index.js     # 自动托管 client/dist 静态文件 + /api 接口
```

数据存储于 `server/data/kv.json`，备份该文件即可。
