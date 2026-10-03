#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
case "${1:-}" in info|migrate|validate) ;; *) echo 'Usage: flyway.sh info|migrate|validate' >&2; exit 2;; esac
# Pass the verb as a positional parameter, not interpolated shell text.
docker compose run --rm --no-deps flyway \
  'export FLYWAY_PASSWORD="$(cat /run/secrets/db_password)"; exec flyway "$@"' flyway "$1"
