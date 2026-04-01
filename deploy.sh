#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ ! -f docker/.env.prod ]]; then
  echo "error: missing docker/.env.prod (create it on the server, never commit it)" >&2
  exit 1
fi

echo "== git pull =="
git pull --ff-only origin main

echo "== sync env for compose (reads docker/.env) =="
cp docker/.env.prod docker/.env

echo "== docker compose =="
cd docker
docker compose build
docker compose up -d --remove-orphans
docker compose ps
