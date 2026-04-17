#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SYNAPSE_DIR="$ROOT_DIR/services/synapse"
DATA_DIR="$SYNAPSE_DIR/data"
CONFIG_FILE="$DATA_DIR/homeserver.yaml"

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose --project-directory "$SYNAPSE_DIR" --env-file "$SYNAPSE_DIR/.env" -f "$SYNAPSE_DIR/compose.yml" "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose --project-directory "$SYNAPSE_DIR" --env-file "$SYNAPSE_DIR/.env" -f "$SYNAPSE_DIR/compose.yml" "$@"
  else
    echo "Docker Compose is required to run local Synapse." >&2
    exit 1
  fi
}

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to run local Synapse." >&2
  exit 1
fi

if [ ! -f "$SYNAPSE_DIR/.env" ]; then
  cp "$SYNAPSE_DIR/.env.example" "$SYNAPSE_DIR/.env"
fi

mkdir -p "$DATA_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  compose run --rm synapse generate

  cat >> "$CONFIG_FILE" <<'YAML'

# FamLink local development only.
enable_registration: true
enable_registration_without_verification: true
registration_shared_secret: famlink-dev-registration-secret
YAML
fi

compose up -d

cat <<'TEXT'
Local Synapse is starting.

Homeserver: http://localhost:8008
Logs:       ./scripts/dev/matrix-logs.sh
Stop:       ./scripts/dev/matrix-stop.sh
TEXT
