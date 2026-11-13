#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 realFelinora — Felinora-shell
#
# Felinora-shell kurulumu
#   ./install.sh          → ~/.config/quickshell/felinora-shell bu klasöre bağlanır (symlink)
#   ./install.sh --copy   → bağlamak yerine kopyalar
#
# Hyprland config'ine dokunmaz; eklemen gereken satırları en sonda yazdırır.

set -e

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.config/quickshell/felinora-shell"
CONF_DIR="$HOME/.config/felinora-shell"
MODE="link"
[ "$1" = "--copy" ] && MODE="copy"

pink() { printf '\033[38;5;212m%s\033[0m\n' "$1"; }
warn() { printf '\033[33m! %s\033[0m\n' "$1"; }
ok()   { printf '\033[32m✓ %s\033[0m\n' "$1"; }

pink "ฅ^•ﻌ•^ฅ  Felinora-shell kurulumu"
echo

# --- zorunlu ---
missing=0
for cmd in quickshell hyprctl; do
    if command -v "$cmd" >/dev/null 2>&1; then ok "$cmd"; else warn "$cmd bulunamadı (zorunlu)"; missing=1; fi
done
[ "$missing" = 1 ] && { echo; warn "Önce zorunlu bağımlılıkları kur."; exit 1; }

# --- isteğe bağlı ---
for pair in "nmcli:ağ paneli (NetworkManager)" "wl-copy:hesap makinesi kopyalama (wl-clipboard)" \
            "awww:duvar kağıdı (awww veya swww)" "nvidia-smi:NVIDIA GPU bilgisi" "lspci:GPU adı (pciutils)"; do
    cmd=${pair%%:*}; what=${pair#*:}
    if command -v "$cmd" >/dev/null 2>&1; then ok "$cmd"
    elif [ "$cmd" = "awww" ] && command -v swww >/dev/null 2>&1; then ok "swww"
    else warn "$cmd yok — $what çalışmaz"; fi
done
for font in "Nunito" "JetBrainsMono Nerd Font Propo"; do
    if fc-list : family 2>/dev/null | grep -qi "$font"; then ok "font: $font"; else warn "font yok: $font"; fi
done
echo

# --- dosyalar ---
mkdir -p "$(dirname "$DEST")"
if [ -e "$DEST" ] || [ -L "$DEST" ]; then
    if [ -L "$DEST" ] && [ "$(readlink -f "$DEST")" = "$SRC" ]; then
        ok "zaten kurulu: $DEST"
    else
        warn "$DEST zaten var. Üzerine yazmıyorum; önce kendin taşı ya da sil."
        exit 1
    fi
elif [ "$MODE" = "copy" ]; then
    cp -r "$SRC" "$DEST" && ok "kopyalandı: $DEST"
else
    ln -s "$SRC" "$DEST" && ok "bağlandı: $DEST → $SRC"
fi

mkdir -p "$CONF_DIR"
if [ -f "$CONF_DIR/config.json" ]; then
    ok "ayar dosyası zaten var: $CONF_DIR/config.json"
else
    cp "$SRC/config.example.json" "$CONF_DIR/config.json" && ok "ayar dosyası oluşturuldu: $CONF_DIR/config.json"
fi

echo
pink "Son adım: Hyprland config'ine ekle"
cat <<'EOF'

  # hyprland.conf (klasik)
  exec-once = quickshell -c felinora-shell
  bind = SUPER, M, exec, qs -c felinora-shell ipc call felinora launcher
  bind = SUPER, L, exec, qs -c felinora-shell ipc call felinora session

  -- hyprland.lua (yeni Lua config)
  hl.on("hyprland.start", function() hl.exec_cmd("quickshell -c felinora-shell") end)
  hl.bind("SUPER + M", hl.dsp.exec_cmd("qs -c felinora-shell ipc call felinora launcher"))
  hl.bind("SUPER + L", hl.dsp.exec_cmd("qs -c felinora-shell ipc call felinora session"))

Hemen denemek için:  quickshell -c felinora-shell &
EOF
