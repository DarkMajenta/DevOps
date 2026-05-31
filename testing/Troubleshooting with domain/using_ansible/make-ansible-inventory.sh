#!/bin/bash

set -euo pipefail

HOSTS_FILE="${1:-domain-hosts.txt}"
OUT="${2:-inventory.ini}"
LOCAL_USER="${3:-localadmin}"

if [ ! -f "$HOSTS_FILE" ]; then
    echo "Файл $HOSTS_FILE не найден."
    exit 1
fi

cat > "$OUT" <<EOF
[alt_clients]
EOF

grep -vE '^\s*$|^\s*#' "$HOSTS_FILE" | sort -u >> "$OUT"

cat >> "$OUT" <<EOF

[alt_clients:vars]
ansible_user=${LOCAL_USER}
ansible_connection=ssh
ansible_become=true
ansible_become_method=su
ansible_become_user=root
ansible_become_exe=su
ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'
EOF

echo "Inventory создан: $OUT"
cat "$OUT"