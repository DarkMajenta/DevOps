#!/bin/bash

DATE=$(date +%F_%H-%M-%S)
BASE="/var/log/netwatch/$DATE"

mkdir -p "$BASE"

while true; do

    echo "===== $(date) =====" >> "$BASE/connections.txt"

    ss -tpn >> "$BASE/connections.txt"

    echo "" >> "$BASE/connections.txt"

    netstat -plant >> "$BASE/netstat.txt"

    sleep 5

done