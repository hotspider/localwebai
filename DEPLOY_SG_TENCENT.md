## 公网部署（新加坡腾讯云）- 第一版

目标：在公网域名 `app.nasclaw.com` 提供服务（HTTPS），但账号体系仍仅家庭内部管理员创建。

---

## 1. 服务器准备
- 系统：Ubuntu 22.04/24.04（推荐）
- 需要开放端口：
  - 80/443（对公网）
  - 22（SSH）
- 不要对公网开放 PostgreSQL 5432（仅本机/内网）

---

## 2. 域名与证书
1. DNS：将 `app.nasclaw.com` A 记录指向服务器公网 IP
2. HTTPS：建议用 Caddy（最简单）或 Nginx + certbot

---

## 3. Supabase Storage
1. 创建 Supabase 项目
2. 创建 bucket：`family-ai-attachments`
3. 在后端环境变量中配置（仅后端保存）：
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `SUPABASE_BUCKET=family-ai-attachments`

说明：客户端上传附件时会 PUT 到后端；后端再用 service role 上传到 Supabase，确保 Key 永不出现在客户端。

---

## 4. PostgreSQL
两种方式任选其一（第一版优先简单可维护）：

### 方式 A：Docker 跑 PostgreSQL（推荐）
安装 Docker（服务器一般可直连 Docker Hub，若受限则改用国内镜像源）。

示例（仅 DB）：

```bash
docker run -d --name family-ai-db \
  -e POSTGRES_DB=family_ai \
  -e POSTGRES_USER=family_ai \
  -e POSTGRES_PASSWORD='CHANGE_ME_DB_PASSWORD' \
  -p 127.0.0.1:5432:5432 \
  -v family_ai_db:/var/lib/postgresql/data \
  postgres:15
```

### 方式 B：本机安装 PostgreSQL
按系统包管理器安装并限制仅本机监听。

---

## 5. 后端部署（推荐：venv + systemd）
### 5.1 拉代码
```bash
git clone <你的仓库地址> family_ai_assistant
cd family_ai_assistant/backend
```

### 5.2 安装依赖
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 5.3 配置环境变量
复制并修改：
```bash
cp .env.example .env
```

关键字段（必须修改）：
- `DATABASE_URL`：指向本机 postgres（建议 `localhost:5432`）
- `JWT_SECRET`：长随机串
- `ADMIN_PASSWORD`：管理员初始密码
- `OPENAI_API_KEY`、`DEEPSEEK_API_KEY`：按需填
- `STORAGE_DRIVER="supabase"` 并填 Supabase 三项
- `PUBLIC_BASE_URL="https://app.nasclaw.com"`
- `CORS_ALLOW_ORIGINS="https://app.nasclaw.com"`
- `SESSION_COOKIE_SECURE=true`

### 5.4 初始化数据库
```bash
source .venv/bin/activate
alembic upgrade head
```

### 5.5 启动（systemd 示例）
创建服务文件 `/etc/systemd/system/family-ai-backend.service`：

```ini
[Unit]
Description=Family AI Backend
After=network.target

[Service]
WorkingDirectory=/opt/family_ai_assistant/backend
EnvironmentFile=/opt/family_ai_assistant/backend/.env
ExecStart=/opt/family_ai_assistant/backend/.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
Restart=always
User=www-data
Group=www-data

[Install]
WantedBy=multi-user.target
```

启用并启动：
```bash
sudo systemctl daemon-reload
sudo systemctl enable family-ai-backend
sudo systemctl start family-ai-backend
```

---

## 6. 反向代理（Caddy 推荐）
安装 Caddy 后创建 `/etc/caddy/Caddyfile`：

```caddy
app.nasclaw.com {
  encode gzip
  reverse_proxy 127.0.0.1:8000
}
```

重载：
```bash
sudo systemctl reload caddy
```

---

## 7. 管理后台与 App
- 管理后台（公网）：`https://app.nasclaw.com/admin/login`
- iOS App：
  - 开发期：`http://127.0.0.1:8000`
  - 上线：Release 默认见 `ios_app/lib/core/config/app_api_host.dart`（`https://app.nasclaw.com`），或构建时 `--dart-define=API_BASE_URL=...`。

