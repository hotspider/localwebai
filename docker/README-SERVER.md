# 服务器生产部署（Docker + HTTPS 域名）

假定公网唯一域名 **`https://app.nasclaw.com`**（管理后台与 API 同源），HTTPS 反代到本机 **`127.0.0.1:8000`**（与 iOS Release 默认 `kProductionShipApiBaseUrl` 一致）。

## 1. 服务器上准备

- 安装 **Docker** 与 **Docker Compose v2**
- 开放 **80 / 443**（Caddy 或 Nginx 申请证书）
- **不要**把 Postgres `5432` 暴露到公网（本 compose 仅绑定容器网络即可）

## 2. 首次：代码与环境变量

```bash
cd ~
git clone git@github.com:hotspider/localwebai.git family_ai_assistant   # 或你的仓库地址
cd family_ai_assistant/docker
cp .env.example .env
nano .env   # 必改项见下
```

**`.env` 必改（勿提交 Git）：**

| 变量 | 说明 |
|------|------|
| `JWT_SECRET` | 长随机串 |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | 管理员登录 |
| `FIELD_ENCRYPTION_FERNET_KEY` | Fernet 密钥；与后台保存的加密 Key 绑定，丢失无法解密 |
| `POSTGRES_PASSWORD` | 若改库密码，需同步改 `DATABASE_URL` 里密码 |
| `OPENAI_API_KEY` 等 | 或在部署后进 `/admin/settings` 用后台加密保存 |

**公网 HTTPS（推荐）：**

```env
ENVIRONMENT=production
PUBLIC_BASE_URL=https://app.nasclaw.com
CORS_ALLOW_ORIGINS=https://app.nasclaw.com
SESSION_COOKIE_SECURE=true
```

**若暂时只有 `http://IP:8000`、无证书：** 将 `PUBLIC_BASE_URL` / `CORS` 改成你的 http 地址，且 **`SESSION_COOKIE_SECURE=false`**，否则管理后台无法登录。

## 3. 启动栈

```bash
cd ~/family_ai_assistant/docker
docker compose up -d --build
docker compose logs -f backend   # 确认迁移与启动无报错
```

本机验收：`curl -s http://127.0.0.1:8000/healthz`（在服务器上执行应返回 `{"ok":true}`）。

## 4. HTTPS 反代（Caddy 示例）

在服务器安装 [Caddy](https://caddyserver.com/) 后，例如 `/etc/caddy/Caddyfile`：

```text
app.nasclaw.com {
    reverse_proxy 127.0.0.1:8000
}
```

`caddy reload` 后，外网访问 `https://app.nasclaw.com` 即转到 Docker 后端（含 `/admin` 与 `/api`）。

## 5. iOS 正式包

Release 默认请求 **`https://app.nasclaw.com`**（见 `ios_app/lib/core/config/app_api_host.dart`）。  
若临时改域名：

```bash
cd ios_app
flutter build ios --release --dart-define=API_BASE_URL=https://你的API域名
```

## 6. 更新发版

在开发机执行（需已配置 SSH 公钥登录服务器）：

```bash
./scripts/deploy-server-docker.sh
```

或手动：服务器上 `git pull` 后 `docker compose up -d --build`。
