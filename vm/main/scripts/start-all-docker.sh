#!/bin/bash
set -euo pipefail

BASE_DIRECTORY="/opt/docker"

compose_files=$(find "$BASE_DIRECTORY" -maxdepth 1 -type f -name '*.yml' | sed 's|^|-f |')

docker compose $compose_files pull || true
docker compose $compose_files up -d
