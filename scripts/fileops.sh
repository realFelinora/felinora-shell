#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Nya Files dosya işlemleri. Hata olursa stderr'e yazar ve 1 ile çıkar.
#   fileops.sh copy|move HEDEF KAYNAK...   (aynı isim varsa "ad (2).uzantı" yapar)
#   fileops.sh clip HEDEF                  (sistem panosundaki dosyaları kopyalar)
#   fileops.sh trash YOL...  |  delete YOL...  |  emptytrash
#   fileops.sh mkdir KLASÖR AD  |  touch KLASÖR AD  |  rename YOL YENİ_AD
#   fileops.sh hide|unhide KLASÖR AD...   (KLASÖR/.hidden listesine ekler/çıkarır; Dolphin de okur)
set -u
op=$1; shift

unique() {   # $1 klasör, $2 ad → kullanılmayan yol
    d=$1; n=$2
    [ -e "$d/$n" ] || [ -L "$d/$n" ] || { printf '%s\n' "$d/$n"; return; }
    case "$n" in
        .*.*|*.*) base=${n%.*}; ext=".${n##*.}" ;;
        *) base=$n; ext="" ;;
    esac
    case "$n" in .*) [ "$base" = "" ] && { base=$n; ext=""; } ;; esac
    i=2
    while [ -e "$d/$base ($i)$ext" ]; do i=$((i + 1)); done
    printf '%s\n' "$d/$base ($i)$ext"
}

fail=0
case "$op" in
    copy|move)
        dest=$1; shift
        for src in "$@"; do
            [ -e "$src" ] || continue
            name=$(basename -- "$src")
            if [ "$op" = move ] && [ "$(dirname -- "$src")" = "$dest" ]; then continue; fi
            case "$dest/" in "$src"/*) echo "klasör kendi içine kopyalanamaz: $name" >&2; fail=1; continue ;; esac
            to=$(unique "$dest" "$name")
            if [ "$op" = copy ]; then cp -a --reflink=auto -- "$src" "$to" || fail=1
            else mv -- "$src" "$to" || fail=1; fi
        done ;;
    clip)
        dest=$1
        wl-paste -n -t text/uri-list 2>/dev/null | tr -d '\r' | while IFS= read -r u; do
            case "$u" in file://*) ;; *) continue ;; esac
            p=$(printf '%s' "${u#file://}" | python3 -c 'import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read()),end="")')
            [ -e "$p" ] || continue
            to=$(unique "$dest" "$(basename -- "$p")")
            cp -a --reflink=auto -- "$p" "$to" || exit 1
        done || fail=1 ;;
    trash)  gio trash -- "$@" || fail=1 ;;
    delete) rm -rf -- "$@" || fail=1 ;;
    emptytrash) gio trash --empty || fail=1 ;;
    mkdir)  mkdir -- "$(unique "$1" "$2")" || fail=1 ;;
    touch)  : > "$(unique "$1" "$2")" || fail=1 ;;
    rename)
        src=$1; new=$2
        case "$new" in */*|""|.|..) echo "geçersiz ad" >&2; exit 1 ;; esac
        to="$(dirname -- "$src")/$new"
        [ "$to" = "$src" ] && exit 0
        if [ -e "$to" ]; then echo "bu adda bir şey zaten var" >&2; exit 1; fi
        mv -- "$src" "$to" || fail=1 ;;
    hide|unhide)
        d=$1; shift; f="$d/.hidden"; tmp="$d/.hidden.nya$$"
        { [ -f "$f" ] && cat -- "$f"; [ "$op" = hide ] && printf '%s\n' "$@"; } | awk -v rm="$op" '
            BEGIN { for (i = 2; i < ARGC; i++) { if (rm == "unhide") del[ARGV[i]] = 1; delete ARGV[i] } }
            NF && !seen[$0]++ && !($0 in del)' - "$@" > "$tmp" || { rm -f "$tmp"; exit 1; }
        if [ -s "$tmp" ]; then mv -f -- "$tmp" "$f"; else rm -f -- "$tmp" "$f"; fi || fail=1 ;;
    *) echo "bilinmeyen işlem: $op" >&2; exit 2 ;;
esac
exit $fail
