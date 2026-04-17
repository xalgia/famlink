#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Usage: $0 <username> <password> [--admin]" >&2
  exit 1
fi

USERNAME="$1"
PASSWORD="$2"
ADMIN_FLAG="${3:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SYNAPSE_DIR="$ROOT_DIR/services/synapse"

if [ ! -f "$SYNAPSE_DIR/.env" ]; then
  cp "$SYNAPSE_DIR/.env.example" "$SYNAPSE_DIR/.env"
fi

REGISTER_ARGS=(
  register_new_matrix_user
  -u "$USERNAME"
  -p "$PASSWORD"
  -c /data/homeserver.yaml
)

if [ "$ADMIN_FLAG" = "--admin" ]; then
  REGISTER_ARGS+=("-a")
fi

REGISTER_ARGS+=("http://localhost:8008")

if docker compose version >/dev/null 2>&1; then
  docker compose --project-directory "$SYNAPSE_DIR" --env-file "$SYNAPSE_DIR/.env" -f "$SYNAPSE_DIR/compose.yml" exec synapse "${REGISTER_ARGS[@]}"
elif command -v docker-compose >/dev/null 2>&1; then
  docker-compose --project-directory "$SYNAPSE_DIR" --env-file "$SYNAPSE_DIR/.env" -f "$SYNAPSE_DIR/compose.yml" exec synapse "${REGISTER_ARGS[@]}"
else
  echo "Docker Compose is required to register a local Synapse user." >&2
  exit 1
fi
