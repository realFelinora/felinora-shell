#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 realFelinora — Felinora-shell
# ağ durumu — her satır etiketli
nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device 2>/dev/null | sed 's/^/DEV /'
echo "CONN $(nmcli -t networking connectivity 2>/dev/null)"
IF=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
echo "IFACE $IF"
echo "GW $(ip route show default 2>/dev/null | awk '{print $3; exit}')"
if [ -n "$IF" ]; then
    echo "IP $(ip -4 -o addr show dev "$IF" 2>/dev/null | awk '{print $4; exit}')"
    echo "SPEED $(cat /sys/class/net/"$IF"/speed 2>/dev/null)"
    echo "MAC $(cat /sys/class/net/"$IF"/address 2>/dev/null)"
fi
nmcli -t -f ACTIVE,SSID,SIGNAL,FREQ dev wifi 2>/dev/null | grep '^yes' | head -1 | sed 's/^/WIFI /'
for v in tailscale0 wg0 tun0; do
    ip -4 -o addr show dev "$v" 2>/dev/null | awk -v n="$v" '{print "VPN",n,$4; exit}'
done
echo "PING $(ping -c1 -W1 1.1.1.1 2>/dev/null | sed -n 's/.*time=\([0-9.]*\).*/\1/p')"
echo "DNS $(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf)"
