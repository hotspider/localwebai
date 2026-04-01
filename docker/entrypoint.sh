#!/usr/bin/env sh
set -e

echo "[backend] running migrations..."
alembic upgrade head

echo "[backend] starting server..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000

