#!/bin/bash

DATE=$(date +%F_%H-%M-%S)
BASE="/var/log/domain-login/$DATE"

mkdir -p "$BASE"

echo "[*] DOMAIN LOGIN TRACE"

########################################
# PAM
########################################

grep pam /var/log/auth.log > "$BASE/pam.txt" 2>/dev/null
journalctl | grep -i pam > "$BASE/pam_journal.txt"

########################################
# SSSD
########################################

cp -r /var/log/sssd "$BASE/"

########################################
# SAMBA
########################################

cp -r /var/log/samba "$BASE/"

########################################
# LIGHTDM
########################################

cp -r /var/log/lightdm "$BASE/"

########################################
# FAILED SERVICES
########################################

systemctl --failed > "$BASE/failed.txt"

########################################
# KERBEROS
########################################

klist > "$BASE/klist.txt" 2>&1
kinit domainuser >> "$BASE/kinit.txt" 2>&1

########################################
# DNS
########################################

host your.domain.local > "$BASE/dns.txt" 2>&1

########################################
# NETWORK
########################################

ss -tpna > "$BASE/connections.txt"

########################################
# FIREWALL
########################################

iptables-save > "$BASE/iptables.txt" 2>&1
nft list ruleset > "$BASE/nftables.txt" 2>&1

echo "[*] DONE"