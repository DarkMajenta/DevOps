#!/bin/bash

set +e

DOMAIN="${1:-}"
TEST_USER="${2:-}"

HOSTNAME_SHORT="$(hostname -s 2>/dev/null)"
HOSTNAME_FQDN="$(hostname -f 2>/dev/null)"
DATE_TAG="$(date +%Y%m%d-%H%M%S)"
OUTDIR="/tmp/ad-client-diagnostic-${HOSTNAME_SHORT}-${DATE_TAG}"
ARCHIVE="${OUTDIR}.tar.gz"

mkdir -p "$OUTDIR"

exec > >(tee -a "$OUTDIR/run.log") 2>&1

echo "=== AD / SSSD / Kerberos / GPO diagnostic ==="
echo "Host: $HOSTNAME_SHORT"
echo "FQDN: $HOSTNAME_FQDN"
echo "Date: $(date -Is)"
echo "Domain argument: $DOMAIN"
echo "Test user argument: $TEST_USER"
echo ""

run_cmd() {
    local name="$1"
    shift
    echo ""
    echo "===== $name ====="
    echo "COMMAND: $*"
    "$@" > "$OUTDIR/${name}.txt" 2>&1
    local rc=$?
    echo "RC=$rc" >> "$OUTDIR/${name}.txt"
    echo "saved: $OUTDIR/${name}.txt"
}

run_shell() {
    local name="$1"
    shift
    echo ""
    echo "===== $name ====="
    echo "COMMAND: $*"
    bash -lc "$*" > "$OUTDIR/${name}.txt" 2>&1
    local rc=$?
    echo "RC=$rc" >> "$OUTDIR/${name}.txt"
    echo "saved: $OUTDIR/${name}.txt"
}

echo "Collecting base system information..."

run_cmd "hostnamectl" hostnamectl
run_cmd "hostname_f" hostname -f
run_cmd "uname_a" uname -a
run_cmd "os_release" cat /etc/os-release
run_cmd "date_timedatectl" timedatectl
run_shell "chrony_status" "command -v chronyc >/dev/null && { chronyc tracking; echo; chronyc sources -v; } || echo 'chronyc not found'"
run_shell "ntp_status" "timedatectl timesync-status 2>/dev/null || true"

echo "Collecting network information..."

run_cmd "ip_addr" ip addr
run_cmd "ip_route" ip route
run_shell "resolv_conf" "cat /etc/resolv.conf"
run_shell "nsswitch_conf" "cat /etc/nsswitch.conf 2>/dev/null || true"
run_shell "hosts_file" "cat /etc/hosts 2>/dev/null || true"

echo "Collecting domain-related configuration..."

run_shell "realm_list" "command -v realm >/dev/null && realm list || echo 'realm not found'"
run_shell "adcli_info" "command -v adcli >/dev/null && adcli info \"${DOMAIN}\" || echo 'adcli not found or domain not specified'"
run_shell "sssd_conf_safe" "if [ -f /etc/sssd/sssd.conf ]; then sed -E 's/(password|ldap_default_authtok|krb5_keytab_password).*/\\1 = ***MASKED***/Ig' /etc/sssd/sssd.conf; else echo '/etc/sssd/sssd.conf not found'; fi"
run_shell "krb5_conf" "cat /etc/krb5.conf 2>/dev/null || true"
run_shell "samba_conf" "testparm -s 2>/dev/null || cat /etc/samba/smb.conf 2>/dev/null || true"

echo "Collecting SSSD state..."

run_shell "systemctl_sssd" "systemctl status sssd --no-pager || true"
run_shell "sssctl_domain_status" "command -v sssctl >/dev/null && sssctl domain-status || echo 'sssctl not found'"
run_shell "sssctl_config_check" "command -v sssctl >/dev/null && sssctl config-check || echo 'sssctl not found'"
run_shell "sssctl_cache_status" "command -v sssctl >/dev/null && sssctl cache-status || echo 'sssctl not found'"
run_shell "sssd_logs_errors" "grep -RniE 'error|fail|offline|ldap|krb|kdc|keytab|denied|timeout|unreachable|gpo' /var/log/sssd 2>/dev/null || true"
run_shell "journal_sssd_boot" "journalctl -u sssd -b --no-pager 2>/dev/null || true"
run_shell "journal_sssd_prevboot" "journalctl -u sssd -b -1 --no-pager 2>/dev/null || true"

echo "Collecting Kerberos information..."

run_shell "klist_current" "klist 2>/dev/null || true"
run_shell "klist_keytab" "klist -kte /etc/krb5.keytab 2>/dev/null || true"
run_shell "keytab_file_info" "ls -l /etc/krb5.keytab 2>/dev/null || true"

if [ -n "$DOMAIN" ]; then
    echo "Collecting DNS SRV records for domain $DOMAIN..."

    run_shell "dns_srv_ldap_dc" "host -t SRV _ldap._tcp.dc._msdcs.${DOMAIN} 2>&1 || true"
    run_shell "dns_srv_ldap_domain" "host -t SRV _ldap._tcp.${DOMAIN} 2>&1 || true"
    run_shell "dns_srv_kerberos_dc" "host -t SRV _kerberos._tcp.dc._msdcs.${DOMAIN} 2>&1 || true"
    run_shell "dns_srv_kerberos_domain" "host -t SRV _kerberos._tcp.${DOMAIN} 2>&1 || true"
    run_shell "dns_srv_kpasswd" "host -t SRV _kpasswd._tcp.${DOMAIN} 2>&1 || true"
    run_shell "dns_soa" "host -t SOA ${DOMAIN} 2>&1 || true"
    run_shell "dns_ns" "host -t NS ${DOMAIN} 2>&1 || true"

    run_shell "ldap_ping_ports" "
        for srv in \$(host -t SRV _ldap._tcp.dc._msdcs.${DOMAIN} 2>/dev/null | awk '{print \$NF}' | sed 's/\\.\$//' | sort -u); do
            echo \"--- \$srv ---\"
            getent hosts \"\$srv\" || true
            timeout 3 bash -c \"</dev/tcp/\$srv/389\" && echo 'tcp 389 ok' || echo 'tcp 389 fail'
            timeout 3 bash -c \"</dev/tcp/\$srv/636\" && echo 'tcp 636 ok' || echo 'tcp 636 fail'
            timeout 3 bash -c \"</dev/tcp/\$srv/88\" && echo 'tcp 88 ok' || echo 'tcp 88 fail'
            timeout 3 bash -c \"</dev/tcp/\$srv/445\" && echo 'tcp 445 ok' || echo 'tcp 445 fail'
        done
    "

    run_shell "sysvol_access_kerberos" "
        command -v smbclient >/dev/null || { echo 'smbclient not found'; exit 0; }
        smbclient -k //${DOMAIN}/SYSVOL -c 'ls' 2>&1 || true
    "
fi

echo "Collecting GPOA / GPUPDATE information..."

run_shell "gpoa_packages" "rpm -qa | grep -Ei 'gpo|gpupdate|samba|sssd|krb|adcli|realmd' | sort || true"
run_shell "gpupdate_version" "command -v gpupdate >/dev/null && gpupdate --version 2>&1 || echo 'gpupdate not found'"
run_shell "gpoa_version" "command -v gpoa >/dev/null && gpoa --version 2>&1 || echo 'gpoa not found'"
run_shell "journal_gpo_boot" "journalctl -b --no-pager | grep -Ei 'gpo|gpupdate|policy|polkit|sssd|krb|keytab' || true"

if command -v gpupdate >/dev/null; then
    run_shell "time_gpupdate" "time gpupdate 2>&1"
fi

if [ -n "$TEST_USER" ]; then
    echo "Collecting test user lookup for $TEST_USER..."

    run_shell "getent_passwd_test_user" "time getent passwd '${TEST_USER}' 2>&1"
    run_shell "id_test_user" "time id '${TEST_USER}' 2>&1"
    run_shell "sssctl_user_checks" "command -v sssctl >/dev/null && sssctl user-checks '${TEST_USER}' 2>&1 || echo 'sssctl not found'"
fi

echo "Collecting Kaspersky-related service state..."

run_shell "kaspersky_packages" "rpm -qa | grep -Ei 'kesl|kaspersky|klnagent|kav|kes' | sort || true"
run_shell "kaspersky_services" "systemctl list-units --type=service --all | grep -Ei 'kesl|kaspersky|klnagent|kav|kes' || true"
run_shell "journal_kaspersky_boot" "journalctl -b --no-pager | grep -Ei 'kesl|kaspersky|klnagent|license|activation|network error' || true"

echo "Collecting top service timings..."

run_shell "systemd_blame" "systemd-analyze blame 2>/dev/null | head -100 || true"
run_shell "failed_units" "systemctl --failed --no-pager || true"

echo "Packing result..."

tar -czf "$ARCHIVE" -C "$(dirname "$OUTDIR")" "$(basename "$OUTDIR")"

echo ""
echo "=== DONE ==="
echo "Output directory: $OUTDIR"
echo "Archive: $ARCHIVE"
echo ""