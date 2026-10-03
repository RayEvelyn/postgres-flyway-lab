#!/usr/bin/env bash
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run via passwordless sudo on a dedicated lab guest.' >&2; exit 2; }
[[ $# == 1 && -d $1 ]] || exit 2
source_dir=$1
# shellcheck source=/dev/null
source /etc/os-release
[[ $ID == ubuntu && $VERSION_ID == 24.04 ]] || { echo 'Ubuntu24.04 required.' >&2; exit 2; }
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y docker.io docker-compose-v2 openssl
systemctl enable --now docker
install -d -m 0755 /opt/homelab/postgres-flyway/{sql,scripts}
target=/opt/homelab/postgres-flyway/compose.yaml
[[ ! -f $target ]] || cp -p "$target" "$target.bak.$(date +%s)"
install -m 0644 "$source_dir/compose.yaml" "$target"
# Previously applied migrations may not be rewritten or silently deleted.
python3 - "$source_dir/sql" /opt/homelab/postgres-flyway/sql <<'MIGRATION_CHECK'
import pathlib,sys
source,dest=map(pathlib.Path,sys.argv[1:])
for old in dest.glob('*.sql'):
 new=source/old.name
 if not new.exists() or new.read_bytes()!=old.read_bytes():
  raise SystemExit('Existing migration changed or missing: '+old.name)
MIGRATION_CHECK
for file in "$source_dir"/sql/*.sql; do install -m 0644 "$file" /opt/homelab/postgres-flyway/sql/; done
for file in setup.sh flyway.sh verify.sh; do install -m 0755 "$source_dir/scripts/$file" /opt/homelab/postgres-flyway/scripts/; done
cd /opt/homelab/postgres-flyway
./scripts/setup.sh
# Always preserve local password and data volume; no clean/down--volumes action.
docker compose up -d --wait database
./scripts/flyway.sh migrate
./scripts/flyway.sh validate
