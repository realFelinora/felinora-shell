#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 realFelinora — Felinora-shell
#
# Ekran kartı bilgisi — tek satır CSV:
#   ad,sıcaklık(°C),kullanım(%),vram_kullanılan(MiB),vram_toplam(MiB),güç(W),fan(%)
# Bilinmeyen alanlar boş bırakılır. NVIDIA (nvidia-smi), AMD (amdgpu sysfs) ve
# diğerleri (sadece ad, lspci) desteklenir.

if command -v nvidia-smi >/dev/null 2>&1; then
    out=$(nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw,fan.speed \
        --format=csv,noheader,nounits 2>/dev/null | head -1)
    if [ -n "$out" ]; then
        echo "$out" | sed 's/\[N\/A\]//g; s/ *, */,/g'
        exit 0
    fi
fi

for card in /sys/class/drm/card[0-9]*; do
    dev="$card/device"
    [ -f "$dev/gpu_busy_percent" ] || continue
    name=$(lspci -s "$(basename "$(readlink -f "$dev")")" 2>/dev/null | sed 's/^[^:]*: //; s/^.*\[AMD\/ATI\] //')
    util=$(cat "$dev/gpu_busy_percent" 2>/dev/null)
    used=$(( $(cat "$dev/mem_info_vram_used" 2>/dev/null || echo 0) / 1048576 ))
    total=$(( $(cat "$dev/mem_info_vram_total" 2>/dev/null || echo 0) / 1048576 ))
    temp=""; power=""; fan=""
    for h in "$dev"/hwmon/hwmon*; do
        [ -f "$h/temp1_input" ] && temp=$(( $(cat "$h/temp1_input") / 1000 ))
        [ -f "$h/power1_average" ] && power=$(( $(cat "$h/power1_average") / 1000000 ))
        if [ -f "$h/pwm1" ]; then fan=$(( $(cat "$h/pwm1") * 100 / 255 )); fi
    done
    echo "${name:-AMD GPU},$temp,$util,$used,$total,$power,$fan"
    exit 0
done

# bilinmeyen / Intel: sadece ad
name=$(lspci 2>/dev/null | grep -i -m1 -E 'vga|3d|display' | sed 's/^[^:]*: [^:]*: //')
echo "${name:-GPU},,,,,,"
