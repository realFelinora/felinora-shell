#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Nya Files "Birlikte aç" yardımcısı.
#   openwith.py apps DOSYA            → JSON: dosya türü, varsayılan uygulama, açabilen uygulamalar
#   openwith.py open UYGULAMA.desktop DOSYA...
#   openwith.py default UYGULAMA.desktop TÜR
#   openwith.py run "KOMUT" DOSYA [TÜR]   → terminalde yazar gibi: KOMUT DOSYA (TÜR verilirse varsayılan yapar)
import configparser, glob, json, os, re, shlex, shutil, subprocess, sys

HOME = os.path.expanduser("~")
# dosya türü uymasa da "Birlikte aç"ta hep görünen programlar: config.json → files.pinnedApps
# (shell bunları FELINORA_PINNED ortam değişkeninde ";" ile ayırarak verir, ör. "sublime_text.desktop;org.xfce.ristretto.desktop")
PINNED = [p for p in os.environ.get("FELINORA_PINNED", "").split(";") if p]
RECENT = HOME + "/.cache/felinora-shell/openwith-recent.json"
TUI = {"nvim", "vim", "vi", "nano", "micro", "hx", "helix", "less", "more", "htop", "btop", "mc", "ranger", "yazi", "lf", "emacs -nw", "kak", "bat", "cat", "hexyl", "xxd", "python", "python3"}
DIRS = [os.environ.get("XDG_DATA_HOME", HOME + "/.local/share")] + \
       os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
DIRS += [HOME + "/.local/share/flatpak/exports/share", "/var/lib/flatpak/exports/share"]


def desktop_files():
    seen = {}
    for d in DIRS:
        for f in glob.glob(os.path.join(d, "applications", "**", "*.desktop"), recursive=True):
            did = os.path.relpath(f, os.path.join(d, "applications")).replace("/", "-")
            seen.setdefault(did, f)          # öncelik: kullanıcı klasörü
    return seen


def read(path):
    cp = configparser.RawConfigParser(strict=False, interpolation=None)
    cp.optionxform = str
    try:
        cp.read(path, encoding="utf-8")
        return cp["Desktop Entry"] if cp.has_section("Desktop Entry") else None
    except Exception:
        return None


def mime_of(path):
    if os.path.isdir(path):
        return "inode/directory"
    try:
        out = subprocess.run(["xdg-mime", "query", "filetype", path], capture_output=True, text=True, timeout=5).stdout.strip()
        if out:
            return out
    except Exception:
        pass
    return subprocess.run(["file", "--mime-type", "-b", path], capture_output=True, text=True).stdout.strip() or "application/octet-stream"


def default_for(mime):
    try:
        return subprocess.run(["xdg-mime", "query", "default", mime], capture_output=True, text=True, timeout=5).stdout.strip()
    except Exception:
        return ""


def apps(path):
    mime = mime_of(path)
    group = mime.split("/")[0] + "/*"
    textish = mime.startswith("text/") or mime in ("application/json", "application/x-shellscript", "application/xml")
    out = []
    for did, f in desktop_files().items():
        e = read(f)
        if not e or e.get("Type") != "Application" or e.get("Hidden", "false") == "true":
            continue
        mine = did.startswith("nya-")                     # bizim oluşturduğumuz "komutla aç" kısayolları
        if e.get("NoDisplay", "false") == "true" and not mine:
            continue
        types = [t for t in e.get("MimeType", "").split(";") if t]
        score = 2 if mime in types else 1 if group in types or (textish and "text/plain" in types) else 0
        if mine and not score:
            continue
        # türü uymayan programlardan sadece PINNED listesindekiler gösterilir
        if not score and did not in PINNED:
            continue
        out.append({"id": did, "name": e.get("Name[tr]") or e.get("Name", did), "icon": e.get("Icon", ""),
                    "comment": e.get("Comment[tr]") or e.get("Comment", ""), "exact": score == 2, "match": score,
                    "exec": e.get("Exec", "").split(" ")[0].split("/")[-1]})
    out.sort(key=lambda a: (-a["match"], a["name"].lower()))
    return {"mime": mime, "default": default_for(mime), "apps": out, "recent": recent()}


def recent():
    try:
        with open(RECENT) as f:
            return [c for c in json.load(f) if isinstance(c, str)][:6]
    except Exception:
        return []


def remember(cmd):
    r = [cmd] + [c for c in recent() if c != cmd]
    os.makedirs(os.path.dirname(RECENT), exist_ok=True)
    with open(RECENT + ".tmp", "w") as f:
        json.dump(r[:6], f, ensure_ascii=False)
    os.replace(RECENT + ".tmp", RECENT)


def terminal_wanted(argv):
    name = os.path.basename(argv[0])
    if name in TUI:
        return True
    for did, f in desktop_files().items():          # .desktop'ı Terminal=true diyorsa
        e = read(f)
        if e and e.get("Terminal", "false") == "true":
            ex = shlex.split(e.get("Exec", "x"))[0] if e.get("Exec") else ""
            if os.path.basename(ex) == name:
                return True
    return False


def run_cmd(cmd, path, mime):
    try:
        argv = shlex.split(cmd)
    except ValueError:
        sys.exit("komut anlaşılamadı (tırnaklar?)")
    if not argv:
        sys.exit("komut boş")
    if not shutil.which(argv[0]):
        sys.exit(f"'{argv[0]}' bulunamadı")
    term = terminal_wanted(argv)
    full = (["kitty", "--"] if term and shutil.which("kitty") else []) + argv + [path]
    subprocess.Popen(full, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL,
                     start_new_session=True, cwd=os.path.dirname(path) or HOME)
    remember(cmd)
    if mime:
        # "her zaman bununla aç": komut için gizli bir .desktop kısayolu oluşturup varsayılan yap
        slug = re.sub(r"[^a-z0-9]+", "-", cmd.lower()).strip("-")[:40] or "komut"
        did = f"nya-{slug}.desktop"
        d = DIRS[0] + "/applications"            # XDG_DATA_HOME (xdg-mime'ın baktığı yer)
        os.makedirs(d, exist_ok=True)
        old = read(d + "/" + did)
        types = set(t for t in (old.get("MimeType", "") if old else "").split(";") if t) | {mime}
        execl = " ".join(shlex.quote(a) for a in argv) + " %f"
        with open(d + "/" + did, "w") as f:
            f.write("[Desktop Entry]\nType=Application\n"
                    f"Name={argv[0]} (komut)\nComment=Nya Files: {cmd}\nExec={execl}\n"
                    f"Terminal={'true' if term else 'false'}\nIcon=utilities-terminal\nNoDisplay=true\n"
                    f"MimeType={';'.join(sorted(types))};\n")
        subprocess.run(["xdg-mime", "default", did, mime], check=False)
    print("terminal" if term else "ok")


def launch(did, files):
    f = desktop_files().get(did)
    if not f:
        sys.exit("uygulama bulunamadı")
    # gio launch .desktop dosyasındaki Exec kodlarını (%f %F %u %U) doğru doldurur
    subprocess.Popen(["gio", "launch", f] + files, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


cmd = sys.argv[1] if len(sys.argv) > 1 else ""
if cmd == "apps":
    print(json.dumps(apps(sys.argv[2]), ensure_ascii=False))
elif cmd == "open":
    launch(sys.argv[2], sys.argv[3:])
elif cmd == "run":
    run_cmd(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "")
elif cmd == "default":
    subprocess.run(["xdg-mime", "default", sys.argv[2], sys.argv[3]], check=True)
else:
    sys.exit("kullanım: openwith.py apps|open|default ...")
