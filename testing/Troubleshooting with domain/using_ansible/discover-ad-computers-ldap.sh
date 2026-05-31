#!/bin/bash

set -euo pipefail

DOMAIN="${1:-}"
BASE_DN="${2:-}"
OUT="${3:-domain-hosts.txt}"

if [ -z "$DOMAIN" ]; then
    echo "Использование:"
    echo "  $0 domain.controller.address 'DC=nw,DC=domain,DC=ru' domain-hosts.txt"
    exit 1
fi

if [ -z "$BASE_DN" ]; then
    BASE_DN="$(echo "$DOMAIN" | awk -F. '{for(i=1;i<=NF;i++){printf "DC=%s", $i; if(i<NF) printf ","}}')"
fi

echo "Домен: $DOMAIN"
echo "Base DN: $BASE_DN"
echo "Выходной файл: $OUT"
echo ""

echo "Ищу контроллеры домена через DNS SRV..."
DC_LIST="$(host -t SRV "_ldap._tcp.dc._msdcs.${DOMAIN}" 2>/dev/null | awk '{print $NF}' | sed 's/\.$//' | sort -u)"

if [ -z "$DC_LIST" ]; then
    echo "Не удалось найти DC через DNS SRV."
    exit 2
fi

echo "$DC_LIST"
echo ""

: > "$OUT"

for DC in $DC_LIST; do
    echo "Пробую LDAP через $DC..."

    ldapsearch -Y GSSAPI \
        -H "ldap://${DC}" \
        -b "$BASE_DN" \
        "(&(objectCategory=computer)(dNSHostName=*))" \
        dNSHostName operatingSystem lastLogonTimestamp \
        2>/tmp/ldapsearch-error.log |
        awk '
            BEGIN { IGNORECASE=1 }
            /^dNSHostName:/ { print $2 }
        ' >> "$OUT" && break || {
            echo "LDAP через $DC не сработал:"
            cat /tmp/ldapsearch-error.log
            echo ""
        }
done

sort -u "$OUT" -o "$OUT"

echo ""
echo "Найдено машин:"
wc -l "$OUT"
echo ""
echo "Первые строки:"
head "$OUT"