#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Shell temasından KDE renk şeması üretir: ~/.local/share/color-schemes/Felinora.colors + kdeglobals renk grupları.
# Kullanım: kde-colors.py '<palet json>'
import json, os, sys, configparser

p = json.loads(sys.argv[1])
home = os.path.expanduser("~")

def rgb(h):
    h = h.lstrip("#"); return ",".join(str(int(h[i:i+2], 16)) for i in (0, 2, 4))
def mix(a, b, t):
    a, b = a.lstrip("#"), b.lstrip("#")
    return "#" + "".join("%02x" % round(int(a[i:i+2], 16) * (1 - t) + int(b[i:i+2], 16) * t) for i in (0, 2, 4))

bg = p["bg"]; surf = p.get("surface") or mix(bg, p["surface2"], 0.6); alt = p.get("bgAlt") or mix(bg, p["surface2"], 0.35)
fg = p["text"]; muted = p["muted"]; acc = p["accent"]; acc2 = p["accent2"]
sel = mix(surf, acc, 0.42)
common = {"ForegroundNormal": fg, "ForegroundInactive": p["subtext"], "ForegroundActive": acc, "ForegroundLink": acc,
          "ForegroundVisited": acc2, "ForegroundNegative": "#ff5c7c", "ForegroundNeutral": "#f5d58a", "ForegroundPositive": "#7ee0a8",
          "DecorationFocus": acc, "DecorationHover": mix(acc, fg, 0.25)}
groups = {
    "Colors:View": {"BackgroundNormal": alt, "BackgroundAlternate": surf},
    "Colors:Window": {"BackgroundNormal": bg, "BackgroundAlternate": surf},
    "Colors:Header": {"BackgroundNormal": bg, "BackgroundAlternate": surf},
    "Colors:Button": {"BackgroundNormal": p["surface2"], "BackgroundAlternate": p["surface3"]},
    "Colors:Tooltip": {"BackgroundNormal": p["surface2"], "BackgroundAlternate": p["surface3"]},
    "Colors:Complementary": {"BackgroundNormal": bg, "BackgroundAlternate": surf},
    "Colors:Selection": {"BackgroundNormal": sel, "BackgroundAlternate": mix(surf, acc, 0.3), "ForegroundNormal": fg,
                         "ForegroundInactive": fg, "ForegroundActive": fg},
}
out = {}
for g, v in groups.items():
    d = dict(common); d.update(v); out[g] = {k: rgb(c) for k, c in d.items()}
out["Colors:Header][Inactive"] = out["Colors:Header"]
out["WM"] = {"activeBackground": rgb(bg), "activeForeground": rgb(fg), "inactiveBackground": rgb(bg),
             "inactiveForeground": rgb(muted), "activeBlend": rgb(acc), "inactiveBlend": rgb(muted)}
out["General"] = {"ColorScheme": "Felinora", "Name": "Felinora", "shadeSortColumn": "true"}
out["ColorEffects:Disabled"] = {"Color": rgb(bg), "ColorAmount": "0.4", "ColorEffect": "3", "ContrastAmount": "0.6",
                                "ContrastEffect": "1", "IntensityAmount": "0", "IntensityEffect": "0"}
out["ColorEffects:Inactive"] = {"ChangeSelectionColor": "false", "Enable": "false"}

def write(path, merge):
    cp = configparser.RawConfigParser(strict=False, interpolation=None, delimiters=("=",))
    cp.optionxform = str
    if merge and os.path.exists(path):
        cp.read(path, encoding="utf-8")
    for g, v in out.items():
        if not merge or not g.startswith("General"):
            if cp.has_section(g): cp.remove_section(g)
            cp.add_section(g)
            for k, val in v.items(): cp.set(g, k, val)
        else:
            if not cp.has_section(g): cp.add_section(g)
            cp.set(g, "ColorScheme", "Felinora")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f: cp.write(f, space_around_delimiters=False)
    os.replace(tmp, path)

write(home + "/.local/share/color-schemes/Felinora.colors", False)
write(home + "/.config/kdeglobals", True)
