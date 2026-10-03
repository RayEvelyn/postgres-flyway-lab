#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${TARGET:?Set ubuntu@your-lab-host}"
[[ $TARGET =~ ^[a-z_][a-z0-9_-]*@[a-zA-Z0-9.-]+$ ]] || exit 2
ssh_opts=()
if [[ -n ${HOMELAB_SSH_CONFIG:-} ]]; then ssh_opts=(-F "$HOMELAB_SSH_CONFIG"); fi
remote=$(ssh "${ssh_opts[@]}" "$TARGET" 'mktemp -d /tmp/homelab.XXXXXXXXXX')
[[ $remote =~ ^/tmp/homelab\.[a-zA-Z0-9]{10}$ ]] || exit 2
trap 'ssh "${ssh_opts[@]}" "$TARGET" "rm -rf -- $remote"' EXIT
# Enumerate public code only. Never tar the checkout, state or local secrets.
# Client expands only the validated temporary directory, deliberately.
# shellcheck disable=SC2029
ssh "${ssh_opts[@]}" "$TARGET" "mkdir -p '$remote/sql' '$remote/scripts'"
scp "${ssh_opts[@]}" compose.yaml "$TARGET:$remote/"
scp "${ssh_opts[@]}" sql/*.sql "$TARGET:$remote/sql/"
scp "${ssh_opts[@]}" scripts/setup.sh scripts/flyway.sh scripts/verify.sh scripts/bootstrap-guest.sh "$TARGET:$remote/scripts/"
# shellcheck disable=SC2029
ssh "${ssh_opts[@]}" "$TARGET" "sudo -n bash '$remote/scripts/bootstrap-guest.sh' '$remote'"
