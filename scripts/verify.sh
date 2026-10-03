#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/flyway.sh migrate
./scripts/flyway.sh validate
count=$(docker compose exec -T database psql -U migration_owner -d homelab -Atc \
 'SELECT count(*) FROM flyway_schema_history WHERE success AND version IS NOT NULL')
[[ "$count" == 3 ]]
# Run twice: numbered migrations must not be re-applied.
./scripts/flyway.sh migrate
count2=$(docker compose exec -T database psql -U migration_owner -d homelab -Atc \
 'SELECT count(*) FROM flyway_schema_history WHERE success AND version IS NOT NULL')
[[ "$count2" == 3 ]]
docker compose exec -T database psql -U migration_owner -d homelab -v ON_ERROR_STOP=1 -c \
 "BEGIN; INSERT INTO projects(name) VALUES ('verification-only'); INSERT INTO deployments(project_id,image_digest) SELECT id,'sha256:example' FROM projects WHERE name='verification-only'; ROLLBACK;"
echo 'Verified migration ordering/history, validation, repeatability and relational inserts without retained sample rows.'
