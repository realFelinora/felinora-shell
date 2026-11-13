#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 realFelinora — Felinora-shell
# hafif sistem bilgisi — her satır etiketli
echo "STAT $(head -1 /proc/stat)"
awk '/^(MemTotal|MemAvailable|SwapTotal|SwapFree):/{sub(":","",$1); print "MEM",$1,$2}' /proc/meminfo
echo "UP $(cut -d' ' -f1 /proc/uptime)"
for h in /sys/class/hwmon/hwmon*; do
    case "$(cat "$h/name" 2>/dev/null)" in
        k10temp|coretemp|zenpower|cpu_thermal) echo "TEMP $(cat "$h/temp1_input" 2>/dev/null)"; break ;;
    esac
done
awk -F: '/^cpu MHz/{s+=$2; n++} END{if (n) printf "MHZ %d\n", s/n}' /proc/cpuinfo
IF=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
echo "IFACE $IF"
[ -n "$IF" ] && grep "$IF:" /proc/net/dev | sed 's/.*://' | awk '{print "NET",$1,$9}'
# fiziksel disk G/Ç (sektör = 512 bayt)
awk '$3 ~ /^(sd[a-z]+|nvme[0-9]+n[0-9]+|vd[a-z]+|mmcblk[0-9]+)$/ {print "DISKIO",$3,$6,$10}' /proc/diskstats
