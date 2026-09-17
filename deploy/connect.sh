#!/bin/sh
set -eu

deploy_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ssh_key=${MATHEVAL_SSH_KEY:-"$HOME/.ssh/matheval_admin"}

if [ ! -r "$ssh_key" ]; then
    echo "Clé privée introuvable : $ssh_key. Voir deploy/REPRISE.org." >&2
    exit 1
fi

exec ssh -i "$ssh_key" \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=yes \
    -o "UserKnownHostsFile=$deploy_dir/ssh-known-hosts" \
    -o ConnectTimeout=10 \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    root@187.77.95.158 "$@"
