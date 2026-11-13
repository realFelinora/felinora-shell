pragma Singleton
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import Quickshell
import Quickshell.Io
import QtQuick

// "Şarkı" teması: çalan şarkının albüm kapağından renk paleti çıkarır.
// İnternetteki kapaklar (Spotify vb.) önce ~/.cache/felinora-shell/art/ içine indirilir.
Singleton {
    id: root

    readonly property string art: Player.art
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/felinora-shell/art"
    property string localArt: ""          // ColorQuantizer'a verilen yerel dosya
    readonly property bool hasArt: localArt !== "" && quant.colors.length > 0

    onArtChanged: load()
    Component.onCompleted: load()

    function load() {
        if (!art) { localArt = ""; return }
        if (art.startsWith("file://")) { localArt = art; return }
        if (!/^https?:\/\//.test(art)) { localArt = ""; return }
        const f = cacheDir + "/" + Qt.md5(art) + ".img"
        dl.target = "file://" + f
        dl.command = ["sh", "-c", '[ -s "$2" ] || { mkdir -p "$(dirname "$2")" && curl -fsSL --max-time 8 -o "$2.tmp" "$1" && mv "$2.tmp" "$2"; }; '
                      + 'ls -t "$(dirname "$2")"/*.img 2>/dev/null | tail -n +40 | xargs -r rm -f', "sh", art, f]
        dl.running = false
        dl.running = true
    }
    Process {
        id: dl
        property string target: ""
        onExited: code => { if (code === 0) root.localArt = target }
    }

    ColorQuantizer {
        id: quant
        source: root.localArt
        depth: 3            // 8 renk
        rescaleSize: 96
    }

    // ---- palet üretimi ----
    function hsl(h, s, l) { return Qt.hsla(((h % 1) + 1) % 1, Math.max(0, Math.min(1, s)), Math.max(0, Math.min(1, l)), 1).toString() }
    function hueDist(a, b) { const d = Math.abs(a - b) % 1; return Math.min(d, 1 - d) }

    readonly property var fallback: ({
        bg: "#0a090d", bgAlt: "#0f0d13", surface: "#141119", surface2: "#1c1823", surface3: "#27212f", border: "#2a2332", frame: "#0b0a0e",
        accent: "#ff79c6", accentSoft: "#ffb8e0", accent2: "#a77bff", accent2Deep: "#6f45d9", tint: "#d6c1ff",
        text: "#f2eaf7", subtext: "#a197b0", muted: "#5d5469"
    })

    readonly property var theme: {
        const base = { id: "sarki", name: "Şarkı", art: hasArt ? Player.art : "" }
        if (!hasArt) return Object.assign({}, fallback, base, { desc: "şarkı çalınca renk alır" })
        // en canlı renk ana vurgu, tonu yeterince farklı ikinci canlı renk ikinci vurgu
        const cs = []
        for (let i = 0; i < quant.colors.length; i++) {
            const c = quant.colors[i]
            const h = c.hslHue < 0 ? 0 : c.hslHue, s = c.hslSaturation, l = c.hslLightness
            cs.push({ h: h, s: s, l: l, score: s * (1 - Math.abs(l - 0.5) * 1.4) })
        }
        cs.sort((a, b) => b.score - a.score)
        const a = cs[0]
        const gray = a.s < 0.12                       // siyah-beyaz kapak
        let b = cs.find(c => c !== a && c.s > 0.15 && hueDist(c.h, a.h) > 0.07)
        const h1 = a.h
        const h2 = b ? b.h : h1 + 0.11
        const s1 = gray ? 0.08 : Math.max(0.65, a.s)
        const s2 = gray ? 0.06 : Math.max(0.55, b ? b.s : a.s)
        const ts = gray ? 0.03 : 0.28                 // zeminin renk tonu gücü
        return Object.assign(base, {
            desc: (Player.title || "albüm kapağından").slice(0, 26),
            bg: hsl(h1, ts, 0.043), bgAlt: hsl(h1, ts, 0.062), surface: hsl(h1, ts, 0.08),
            surface2: hsl(h1, ts, 0.11), surface3: hsl(h1, ts, 0.155), border: hsl(h1, ts, 0.165), frame: hsl(h1, ts, 0.04),
            accent: hsl(h1, s1, 0.72), accentSoft: hsl(h1, s1 * 0.9, 0.86),
            accent2: hsl(h2, s2, 0.66), accent2Deep: hsl(h2, s2, 0.42), tint: hsl(h2, s2 * 0.8, 0.86),
            text: hsl(h1, gray ? 0.04 : 0.3, 0.94), subtext: hsl(h1, gray ? 0.03 : 0.14, 0.66), muted: hsl(h1, gray ? 0.03 : 0.12, 0.38)
        })
    }
}
