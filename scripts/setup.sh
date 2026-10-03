#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p secrets
chmod 700 secrets
if [[ ! -e secrets/db_password ]]; then
  openssl rand -hex 32 > secrets/db_password
fi
[[ -s secrets/db_password ]] || { echo 'Existing credential is empty; refusing to overwrite.' >&2; exit 1; }
chmod 600 secrets/db_password
echo 'Local lab credential ready; no secret printed.'
