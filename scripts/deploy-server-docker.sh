#!/usr/bin/env bash
# 将仓库同步到服务器并重建 Docker 后端（不覆盖远程 docker/.env、backend/.env）
set -euo pipefail

REMOTE="${DEPLOY_REMOTE:-ubuntu@43.160.235.149}"
REMOTE_DIR="${DEPLOY_REMOTE_DIR:-~/family_ai_assistant}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH_OPTS="${DEPLOY_SSH_OPTS:- -o StrictHostKeyChecking=accept-new}"

if [[ "$REMOTE_DIR" == /Users/* ]]; then
  echo "ERROR: DEPLOY_REMOTE_DIR 不能是本机 macOS 路径：$REMOTE_DIR" >&2
  echo "原因：你在终端执行 export DEPLOY_REMOTE_DIR=~/family_ai_assistant 时，~ 被本地展开成了 /Users/..." >&2
  echo "请改用以下任一写法（推荐第 1 个）：" >&2
  echo "  1) export DEPLOY_REMOTE_DIR=/home/ubuntu/family_ai_assistant" >&2
  echo "  2) export DEPLOY_REMOTE_DIR='~/family_ai_assistant'   # 注意要带引号，避免本地展开" >&2
  exit 2
fi

echo "==> rsync 代码到 $REMOTE:$REMOTE_DIR"
rsync -avz --delete \
  -e "ssh $SSH_OPTS" \
  --exclude '.git' \
  --exclude 'backend/.venv' \
  --exclude 'backend/.env' \
  --exclude 'docker/.env' \
  --exclude 'ios_app/build' \
  --exclude 'ios_app/.dart_tool' \
  --exclude '**/.DS_Store' \
  --exclude '**/__pycache__' \
  --exclude 'backend/.data' \
  "$ROOT/" "$REMOTE:$REMOTE_DIR/"

echo "==> 远程构建并启动 Docker"
ssh $SSH_OPTS "$REMOTE" "cd $REMOTE_DIR/docker && docker compose up -d --build"

echo "==> 完成。请在服务器执行: curl -s http://127.0.0.1:8000/healthz"
echo "    注意：rsync 排除了远程 docker/.env；首次或换域名时请对照仓库 docker/.env.example 核对"
echo "    ENVIRONMENT、PUBLIC_BASE_URL、CORS_ALLOW_ORIGINS、SESSION_COOKIE_SECURE。"
