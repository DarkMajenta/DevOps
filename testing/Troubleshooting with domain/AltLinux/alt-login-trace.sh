#!/bin/bash

DATE=$(date +%F_%H-%M-%S)
BASE="/var/log/login-trace/$DATE"

mkdir -p "$BASE"

echo "START LOGIN TRACE"

########################################
# LIVE SSSD
########################################

journalctl -f -u sssd > "$BASE/sssd-live.txt" &
PID1=$!

########################################
# LIVE WINBIND
########################################

journalctl -f -u winbind > "$BASE/winbind-live.txt" &
PID2=$!

########################################
# LIVE LIGHTDM
########################################

journalctl -f -u lightdm > "$BASE/lightdm-live.txt" &
PID3=$!

########################################
# LIVE KERNEL
########################################

journalctl -kf > "$BASE/kernel-live.txt" &
PID4=$!

########################################
# LIVE TCPDUMP
########################################

tcpdump -i any -nn -s0 \
-w "$BASE/login.pcap" &
PID5=$!

########################################
# WAIT LOGIN
########################################

echo "Perform domain login now..."
sleep 180

########################################
# STOP
########################################

kill $PID1 $PID2 $PID3 $PID4 $PID5

echo "DONE"