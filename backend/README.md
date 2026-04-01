## 后端（FastAPI）

### 作用
- 提供账号体系（无注册）、聊天、附件上传/问答、历史会话、管理后台（网页）能力
- 所有模型 API Key 仅在后端环境变量中读取

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

### 环境变量
- 见 `.env.example`

### 公网部署注意（第一版最小集）
- 必须通过反向代理提供 HTTPS（例如 Nginx/Caddy），域名例如 `ai.nasclaw.com`
- `.env` 中设置：
  - `PUBLIC_BASE_URL="https://ai.nasclaw.com"`
  - `CORS_ALLOW_ORIGINS="https://ai.nasclaw.com"`
  - `SESSION_COOKIE_SECURE=true`
- 生产环境建议使用 `STORAGE_DRIVER="supabase"`，并填写：
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`（只在服务端）
  - `SUPABASE_BUCKET`（如 `family-ai-attachments`）

