#!/bin/bash

DATE=$(date +%F_%H-%M-%S)
BASE="/var/log/alt-domain-debug/$DATE"

mkdir -p "$BASE"

exec > >(tee -a "$BASE/run.log") 2>&1

echo "===== ALT DOMAIN DEBUG START ====="

########################################
# SYSTEM
########################################

hostnamectl > "$BASE/hostnamectl.txt"
uname -a > "$BASE/uname.txt"
cat /etc/os-release > "$BASE/os-release.txt"

########################################
# NETWORK
########################################

ip a > "$BASE/ip_a.txt"
ip r > "$BASE/routes.txt"
resolvectl status > "$BASE/resolvectl.txt" 2>/dev/null
cat /etc/resolv.conf > "$BASE/resolv.conf"

########################################
# TIME
########################################

timedatectl > "$BASE/time.txt"
chronyc tracking > "$BASE/chrony.txt" 2>&1

########################################
# DOMAIN STATE
########################################

realm list > "$BASE/realm.txt" 2>&1
adcli info YOUR.DOMAIN > "$BASE/adcli.txt" 2>&1

########################################
# SSSD
########################################

sssctl config-check > "$BASE/sssctl-config.txt" 2>&1
sssctl domain-status > "$BASE/sssctl-domain.txt" 2>&1
sssctl cache-status > "$BASE/sssctl-cache.txt" 2>&1

########################################
# USER CHECK
########################################

id DOMAIN\\\\user > "$BASE/id.txt" 2>&1
getent passwd > "$BASE/getent.txt"
wbinfo -u > "$BASE/wbinfo-users.txt" 2>&1

########################################
# SERVICES
########################################

systemctl status sssd > "$BASE/sssd-status.txt" 2>&1
systemctl status winbind > "$BASE/winbind-status.txt" 2>&1
systemctl status lightdm > "$BASE/lightdm-status.txt" 2>&1

########################################
# BOOT ANALYZE
########################################

systemd-analyze > "$BASE/boot-time.txt"
systemd-analyze blame > "$BASE/blame.txt"
systemd-analyze critical-chain > "$BASE/critical-chain.txt"

########################################
# CONNECTIONS
########################################

ss -tpna > "$BASE/ss.txt"

########################################
# JOURNAL
########################################

journalctl -b > "$BASE/journal.txt"

########################################
# ERROR FILTER
########################################

journalctl -p err..alert > "$BASE/errors.txt"

########################################
# TCPDUMP
########################################

timeout 300 tcpdump \
-i any \
-nn \
-s0 \
-vv \
-w "$BASE/domain-login.pcap" \
port 53 or \
port 88 or \
port 135 or \
port 139 or \
port 389 or \
port 445 or \
port 464 or \
port 636 &

########################################
# CONNTRACK
########################################

conntrack -L > "$BASE/conntrack.txt" 2>&1

########################################
# FIREWALL
########################################

iptables-save > "$BASE/iptables.txt" 2>&1
nft list ruleset > "$BASE/nftables.txt" 2>&1

########################################
# PROCESS
########################################

ps auxfw > "$BASE/processes.txt"

echo "===== DONE ====="