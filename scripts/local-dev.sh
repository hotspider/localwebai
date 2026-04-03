#!/usr/bin/env bash
# 本地一键：Docker 启动 Postgres（若尚未运行）→ 迁移 → 启动 API（0.0.0.0:8000）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/docker"
docker compose up -d db
for i in {1..60}; do
  if docker compose exec -T db pg_isready -U family_ai -d family_ai >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

cd "$ROOT/backend"
if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
pip install -q -r requirements.txt
alembic upgrade head
exec uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
