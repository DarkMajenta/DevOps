#!/bin/bash

set -euo pipefail

DOMAIN="${1:-}"
BIND_USER="${2:-}"
BASE_DN="${3:-}"
OUT="${4:-domain-hosts.txt}"

if [ -z "$DOMAIN" ] || [ -z "$BIND_USER" ]; then
    echo "Использование:"
    echo "  $0 domain.controller.address 'DOMAIN\\user' 'DC=nw,DC=controller,DC=ru' domain-hosts.txt"
    exit 1
fi

if [ -z "$BASE_DN" ]; then
    BASE_DN="$(echo "$DOMAIN" | awk -F. '{for(i=1;i<=NF;i++){printf "DC=%s", $i; if(i<NF) printf ","}}')"
fi

read -rsp "Пароль доменного пользователя: " BIND_PASS
echo ""

DC="$(host -t SRV "_ldap._tcp.dc._msdcs.${DOMAIN}" 2>/dev/null | awk '{print $NF}' | sed 's/\.$//' | sort -u | head -1)"

if [ -z "$DC" ]; then
    echo "Не удалось найти контроллер домена."
    exit 2
fi

echo "DC: $DC"
echo "Base DN: $BASE_DN"

ldapsearch -x \
    -H "ldap://${DC}" \
    -D "$BIND_USER" \
    -w "$BIND_PASS" \
    -b "$BASE_DN" \
    "(&(objectCategory=computer)(dNSHostName=*))" \
    dNSHostName operatingSystem lastLogonTimestamp |
    awk '
        BEGIN { IGNORECASE=1 }
        /^dNSHostName:/ { print $2 }
    ' | sort -u > "$OUT"

echo "Найдено машин:"
wc -l "$OUT"
head "$OUT"