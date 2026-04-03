## 后端（FastAPI）

### 作用
- 提供账号体系（无注册）、聊天、附件上传/问答、历史会话、管理后台（网页）能力
- **OpenAI / DeepSeek / Brave** 等第三方 Key 可在管理后台配置：浏览器侧明文输入（建议 HTTPS），服务端使用 **`FIELD_ENCRYPTION_FERNET_KEY`**（Fernet）**加密写入数据库**，调用外部 API 时在**进程内解密**；家庭助手 App **从不接收**这些 Key。
- 若未配置后台 Key，仍可回退到 `.env` 中的 `OPENAI_API_KEY` / `DEEPSEEK_API_KEY`（见 `app/services/runtime_settings.py`）。

### 字段加密主密钥（保存后台 API Key 所必需）
在 `backend/.env` 中设置一行（**勿用普通口令冒充**，须为 Fernet 密钥）：

```bash
# 在已激活 venv、已 pip install -r requirements.txt 的前提下：
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

将输出整行粘贴为 `FIELD_ENCRYPTION_FERNET_KEY=...`，**重启后端**后再在后台保存各 API Key。

### 本地运行（无 Docker）
1. 准备 PostgreSQL，并创建数据库/用户（示例见 `.env.example` 的 `DATABASE_URL`）
2. 安装依赖

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

3. 初始化数据库（Alembic）

```bash
export DATABASE_URL="postgresql+psycopg://family_ai:family_ai_password@localhost:5432/family_ai"
alembic upgrade head
```

4. 启动（会在首次启动时自动创建管理员账号：`ADMIN_USERNAME` / `ADMIN_PASSWORD`）

```bash
uvicorn app.main:app --reload --port 8000
```

5. 管理后台
- 打开 `http://localhost:8000/admin/login`
- 若用 **HTTP**（本机、`http://IP:8000`）访问而后台「进不去 / 登录又跳回登录页」：请确认 `SESSION_COOKIE_SECURE=false`（代码默认已为 `false`）。仅在全站 **HTTPS** 时改为 `true`。
- 若点开 **Brave** 等后台页出现 JSON `INTERNAL_ERROR` 或迁移提示页：在 `backend` 目录执行 `alembic upgrade head`（Docker 镜像启动时会自动执行；若代码未更新到含 `0003_brave_realtime` 的迁移，需先拉代码再重建镜像）。

### 环境变量
- 见 `.env.example`

### 公网部署（Docker 一键栈）
- 见仓库根目录 **`docker/README-SERVER.md`**（域名 HTTPS、`.env`、Caddy 反代、发版脚本 `scripts/deploy-server-docker.sh`）。

### 公网部署注意（第一版最小集）
- 必须通过反向代理提供 HTTPS（例如 Nginx/Caddy），域名例如 `app.nasclaw.com`
- `.env` 中设置：
  - `ENVIRONMENT="production"`
  - `PUBLIC_BASE_URL="https://app.nasclaw.com"`
  - `CORS_ALLOW_ORIGINS="https://app.nasclaw.com"`
  - `SESSION_COOKIE_SECURE=true`
- 生产环境建议使用 `STORAGE_DRIVER="supabase"`，并填写：
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`（只在服务端）
  - `SUPABASE_BUCKET`（如 `family-ai-attachments`）

