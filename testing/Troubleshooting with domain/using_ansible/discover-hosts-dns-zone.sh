#!/bin/bash

set -euo pipefail

DOMAIN="${1:-}"
DNS_SERVER="${2:-}"
OUT="${3:-domain-hosts.txt}"

if [ -z "$DOMAIN" ]; then
    echo "Использование:"
    echo "  $0 domain.controller.address [dns-server] domain-hosts.txt"
    exit 1
fi

if [ -z "$DNS_SERVER" ]; then
    DNS_SERVER="$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf)"
fi

echo "Домен: $DOMAIN"
echo "DNS-сервер: $DNS_SERVER"

echo "Пробую AXFR зоны. Скорее всего, будет запрещено, но проверить можно."

dig @"$DNS_SERVER" "$DOMAIN" AXFR +short |
    awk '
        $1 ~ /\.$/ && $4 ~ /^A$/ {
            gsub(/\.$/, "", $1);
            print $1
        }
    ' |
    sort -u > "$OUT" || true

echo "Найдено:"
wc -l "$OUT"
head "$OUT"