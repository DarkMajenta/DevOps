#!/bin/bash

DATE=$(date +%F_%H-%M-%S)
BASE="/var/log/domain-debug/$DATE"

mkdir -p "$BASE"

echo "[*] START $DATE" | tee "$BASE/info.txt"

########################################
# SYSTEM INFO
########################################

uname -a > "$BASE/uname.txt"
ip a > "$BASE/ip_a.txt"
ip route > "$BASE/routes.txt"
resolvectl status > "$BASE/resolvectl.txt" 2>/dev/null
timedatectl > "$BASE/time.txt"

########################################
# SERVICES
########################################

systemctl status sssd > "$BASE/sssd-status.txt" 2>&1
systemctl status winbind > "$BASE/winbind-status.txt" 2>&1
systemctl status samba > "$BASE/samba-status.txt" 2>&1
systemctl status NetworkManager > "$BASE/network.txt" 2>&1

########################################
# SOCKETS
########################################

ss -tulpen > "$BASE/ss_before.txt"

########################################
# DOMAIN TESTS
########################################

id domainuser > "$BASE/id_test.txt" 2>&1
wbinfo -u > "$BASE/wbinfo_users.txt" 2>&1
wbinfo -g > "$BASE/wbinfo_groups.txt" 2>&1
getent passwd > "$BASE/getent_passwd.txt"

########################################
# JOURNAL
########################################

journalctl -b > "$BASE/journal_full.txt"

########################################
# START NETWORK CAPTURE
########################################

timeout 300 tcpdump -i any -nn -s0 -w "$BASE/boot_login.pcap" &
echo $! > "$BASE/tcpdump.pid"

########################################
# LIVE CONNECTION SNAPSHOT
########################################

for i in {1..60}; do
    ss -tpn >> "$BASE/live_connections.txt"
    echo "-----" >> "$BASE/live_connections.txt"
    sleep 5
done &

########################################
# PROCESS LIST
########################################

ps auxfw > "$BASE/processes.txt"

echo "[*] DONE"