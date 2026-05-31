#!/bin/bash

DOMAIN="${1:-}"
TEST_USER="${2:-}"

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 domain.local [DOMAIN\\\\user]"
    exit 1
fi

echo "=== Quick AD client check ==="
echo "Host: $(hostname -f 2>/dev/null)"
echo "Domain: $DOMAIN"
echo "Date: $(date -Is)"
echo ""

echo "=== DNS servers ==="
cat /etc/resolv.conf
echo ""

echo "=== SRV LDAP DC ==="
host -t SRV "_ldap._tcp.dc._msdcs.${DOMAIN}" || true
echo ""

echo "=== SRV Kerberos DC ==="
host -t SRV "_kerberos._tcp.dc._msdcs.${DOMAIN}" || true
echo ""

echo "=== SSSD domain status ==="
sssctl domain-status 2>/dev/null || echo "sssctl unavailable"
echo ""

echo "=== Keytab ==="
sudo klist -kte /etc/krb5.keytab 2>/dev/null || echo "cannot read keytab"
echo ""

echo "=== Kerberos current ticket ==="
klist 2>/dev/null || echo "no current ticket"
echo ""

echo "=== Time sync ==="
timedatectl
echo ""

if [ -n "$TEST_USER" ]; then
    echo "=== User lookup timing ==="
    time getent passwd "$TEST_USER"
    time id "$TEST_USER"
    echo ""
fi

echo "=== Recent SSSD errors ==="
journalctl -u sssd -b --no-pager 2>/dev/null | grep -Ei 'error|fail|offline|ldap|krb|kdc|keytab|timeout|unreachable|gpo' | tail -100 || true
echo ""

echo "=== Recent GPO/GPOA messages ==="
journalctl -b --no-pager 2>/dev/null | grep -Ei 'gpo|gpupdate|policy' | tail -100 || true
echo ""