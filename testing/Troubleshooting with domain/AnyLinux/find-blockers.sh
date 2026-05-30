#!/bin/bash

OUT="/var/log/blockers.txt"

echo "===== FAILED =====" > $OUT
systemctl --failed >> $OUT

echo "===== DENIED =====" >> $OUT
journalctl -p err..alert >> $OUT

echo "===== SSSD ERRORS =====" >> $OUT
grep -Ri "fail\|error\|denied" /var/log/sssd >> $OUT

echo "===== SAMBA ERRORS =====" >> $OUT
grep -Ri "fail\|error\|denied" /var/log/samba >> $OUT

echo "===== KERBEROS =====" >> $OUT
grep -Ri "krb5\|kerberos" /var/log >> $OUT

echo "===== USBGUARD =====" >> $OUT
journalctl | grep -i usbguard >> $OUT

echo "===== KASPERSKY =====" >> $OUT
grep -Ri "deny\|block\|drop" /var/log/kaspersky >> $OUT 2>/dev/null