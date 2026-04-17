#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SYNAPSE_DIR="$ROOT_DIR/services/synapse"

if [ ! -f "$SYNAPSE_DIR/.env" ]; then
  cp "$SYNAPSE_DIR/.env.example" "$SYNAPSE_DIR/.env"
fi

if docker compose version >/dev/null 2>&1; then
  docker compose --project-directory "$SYNAPSE_DIR" --env-file "$SYNAPSE_DIR/.env" -f "$SYNAPSE_DIR/compose.yml" logs -f synapse
elif command -v docker-compose >/dev/null 2>&1; then
  docker-compose --project-directory "$SYNAPSE_DIR" --env-file "$SYNAPSE_DIR/.env" -f "$SYNAPSE_DIR/compose.yml" logs -f synapse
else
  echo "Docker Compose is required to read local Synapse logs." >&2
  exit 1
fi
