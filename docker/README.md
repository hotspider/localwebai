# Docker 本地运行

## 启动

```bash
cd docker
cp .env.example .env   # 首次：编辑 .env
docker compose up -d --build
```

后端：<http://127.0.0.1:8000> · 管理后台：<http://127.0.0.1:8000/admin/login>

## 后台 Brave「测试成功」但 App 仍报未配置 Key

多为 **手机/App 连的后端** 与 **浏览器打开后台** 不是同一台，或 **容器未带上 `FIELD_ENCRYPTION_FERNET_KEY`**。

1. 看 App 报错里「当前 API」或 Debug 文案里的地址，须与浏览器访问后台的 **协议+主机+端口** 一致（例如都是 `http://127.0.0.1:8000`）。Release 包会连 `app_api_host.dart` 里的外网地址，与本地 Docker 不是同一套库。
2. 修改 `docker/.env` 后必须 **`docker compose up -d --force-recreate backend`**，否则容器进程里仍可能没有最新的 `FIELD_ENCRYPTION_FERNET_KEY`。
3. 查日志（发一条实时问题后执行）：

```bash
docker compose logs backend --tail 100 | grep brave_realtime
```

关注 `blob_len` / `fernet_env_set` / `decrypted_non_empty`；若 `blob_len>0` 且 `decrypted_non_empty=False`，为 **Fernet 不一致或未注入**。

## 拉镜像超时（`auth.docker.io` / `DeadlineExceeded` / `i/o timeout`）

多为 **访问 Docker Hub 不稳定**（国内常见）或 **IPv6 异常**。

### 做法 A：配置 Docker 镜像加速（推荐）

1. 打开 **Docker Desktop** → **Settings**（设置）→ **Docker Engine**
2. 在 JSON 里增加 `registry-mirrors`（以下仅为示例，请改用你当前可用的镜像文档）：

若你已有 `builder`、`experimental` 等配置，请**合并**进同一 JSON，不要只留 mirrors（示例）：

```json
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "experimental": false,
  "registry-mirrors": [
    "https://docker.m.daocloud.io"
  ]
}
```

若当前只有 mirrors，最小配置也可以是：

```json
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io"
  ]
}
```

3. **Apply & Restart**，再执行 `docker compose up -d --build`。

### 做法 B：在 `docker/.env` 里换基础镜像名

编辑与本目录 `docker-compose.yml` 同级的 **`.env`**，增加或取消注释（路径以镜像站说明为准，若失效请换源）：

```env
DOCKER_PYTHON_IMAGE=docker.m.daocloud.io/library/python:3.12-slim
DOCKER_POSTGRES_IMAGE=docker.m.daocloud.io/library/postgres:15
```

保存后重新：

```bash
docker compose build --no-cache
docker compose up -d
```

### 做法 C：代理 / 关闭有问题的 IPv6

- 若本机已开 **VPN / HTTP 代理**：在 Docker Desktop → **Resources** → **Proxies** 中配置。
- 或在系统网络设置里暂时 **关闭 IPv6** 再试拉取（部分环境 IPv6 访问 Hub 会卡死）。
