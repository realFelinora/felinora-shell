pragma Singleton
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import Quickshell
import QtQuick
import "../config"

// Kitty ve fastfetch'i shell temasıyla eşler (isteğe bağlı, config.json → "kitty"/"fastfetch").
//  - kitty: ~/.config/kitty/felinora-theme.conf yazılır ("liquid glass": yarı saydam zemin),
//    tema değişince açık pencerelere renkler 500 ms'de yumuşakça geçirilir (README'ye bak)
//  - fastfetch: ~/.config/fastfetch/config.jsonc yazılır (ilk seferde eskisi .felinora-yedek olarak saklanır)
Singleton {
    id: root

    readonly property string file: Quickshell.env("HOME") + "/.config/kitty/felinora-theme.conf"

    readonly property var pal: Theme.current
    onPalChanged: if (ready) debounce.restart()
    readonly property bool ready: Prefs.ready && Config.loaded && (Config.kittySync || Config.fastfetchSync || Config.cavaSync || Config.qtSync)
    onReadyChanged: if (ready) debounce.restart()

    Timer { id: debounce; interval: 30; onTriggered: root.apply() }

    // ---- yumuşak geçiş: shell'in 500 ms renk animasyonuyla aynı anda kitty'ye ara renkler yollanır ----
    // (kitty.conf: allow_remote_control socket-only + listen_on unix:$XDG_RUNTIME_DIR/kitty-{kitty_pid})
    property var shownMap: null
    property var fromMap: ({})
    property var toMap: ({})
    property real t: 0
    // set-colors'ın kabul ettiği renk ayarları
    readonly property var liveKeys: /^(foreground|background|selection_foreground|selection_background|cursor|cursor_text_color|url_color|active_border_color|inactive_border_color|active_tab_foreground|active_tab_background|inactive_tab_foreground|inactive_tab_background|tab_bar_background|color\d+)$/
    NumberAnimation { id: fade; target: root; property: "t"; from: 0; to: 1; duration: 500; onFinished: root.finishFade() }
    Timer { interval: 50; repeat: true; running: fade.running; onTriggered: root.sendColors(root.blendMap(root.t)) }

    function colorMap(conf) {
        const m = {}
        conf.split("\n").forEach(l => { const r = l.match(/^(\S+) (#[0-9a-fA-F]{6})$/); if (r && liveKeys.test(r[1])) m[r[1]] = r[2] })
        return m
    }
    function blendMap(t) {
        const out = {}
        for (const k in toMap) out[k] = mix(fromMap[k] || toMap[k], toMap[k], t)
        return out
    }
    function sendColors(m, final) {
        // cava renkleri ("cava." önekli) dosyaya yazılır; ara karelerde yalnız renkler (USR2), sonda tüm ayar (USR1)
        if (Config.cavaSync) {
            const cm = {}
            for (const k in m) if (k.startsWith("cava.")) cm[k] = m[k]
            Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" > "$2" && pkill -' + (final ? "USR1" : "USR2") + ' -x cava; true',
                                     "sh", buildCava(cm), cavaFile])
        }
        const args = []
        for (const k in m) if (!k.startsWith("cava.")) args.push(k + "=" + m[k])
        if (!Config.kittySync) return
        Quickshell.execDetached(["sh", "-c",
            'for s in "$XDG_RUNTIME_DIR"/kitty-*; do [ -S "$s" ] && kitten @ --to "unix:$s" set-colors --all --configured "$@" >/dev/null 2>&1 & done; wait',
            "sh", ...args])
    }
    function finishFade() {
        sendColors(toMap, true)
        applyQt(pal)
        shownMap = toMap
        // saydamlık vb. renk dışı ayarlar + uzaktan kontrolü olmayan eski pencereler için
        if (Config.kittySync) Quickshell.execDetached(["pkill", "-USR1", "-x", "kitty"])
    }

    // ---- renk yardımcıları ----
    function hex(c) {
        const h = v => ("0" + Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)).slice(-2)
        return "#" + h(c.r) + h(c.g) + h(c.b)
    }
    function mix(a, b, t) {
        const x = Qt.color(a), y = Qt.color(b)
        return hex({ r: x.r + (y.r - x.r) * t, g: x.g + (y.g - x.g) * t, b: x.b + (y.b - x.b) * t })
    }

    // kitty 256 renk yuvaları 17-30 temaya ayrılır; fastfetch bunları kullanır →
    // tema değişince ekranda zaten yazılı olan fastfetch çıktısı da anında yeni renge geçer
    // 17 vurgu, 18 ikinci vurgu, 19 yumuşak vurgu, 20 yazı, 21 koyu yüzey, 22 kırmızı, 23-30 degrade
    function slots(p) {
        const out = [p.accent, p.accent2, p.accentSoft, p.text, p.surface3, "#ff5c7c"]
        for (let i = 0; i < 8; i++) out.push(mix(p.accent, p.accentSoft, i / 7))
        return out
    }

    function build(p) {
        const ansi = (base, t) => mix(base, p.accent, t)
        const bright = c => mix(c, "#ffffff", 0.3)
        const red = ansi("#ff6b8b", 0.2), green = ansi("#7ee0a8", 0.15), yellow = ansi("#f5d58a", 0.15)
        const blue = mix("#7aa2ff", p.accent2, 0.35), cyan = ansi("#7ddbe6", 0.15)
        const bg = mix(p.bg, p.accent2, 0.04)
        const L = [
            "# Felinora-shell tarafından otomatik yazılır — elle düzenleme, tema değişince ezilir.",
            "# tema: " + (p.name || p.id),
            "",
            "# --- liquid glass ---",
            "background_opacity 0.78",
            "dynamic_background_opacity yes",
            "window_padding_width 10",
            "",
            "foreground " + p.text,
            "background " + bg,
            "selection_foreground " + p.text,
            "selection_background " + mix(bg, p.accent2, 0.45),
            "cursor " + p.accent,
            "cursor_text_color " + bg,
            "cursor_trail_color " + p.accentSoft,
            "url_color " + p.accentSoft,
            "url_style curly",
            "mark1_background " + p.accent,
            "",
            "active_border_color " + p.accent,
            "inactive_border_color " + p.surface3,
            "bell_border_color " + red,
            "",
            "# sekmeler",
            "tab_bar_edge top",
            "tab_bar_style powerline",
            "tab_powerline_style round",
            "tab_title_template \" {title} \"",
            "active_tab_foreground " + bg,
            "active_tab_background " + p.accent,
            "active_tab_font_style bold",
            "inactive_tab_foreground " + p.subtext,
            "inactive_tab_background " + p.surface2,
            "tab_bar_background " + bg,
            "",
            "# 16 renk (temaya göre tonlanmış)",
            "color0 " + p.surface3, "color8 " + p.muted,
            "color1 " + red, "color9 " + bright(red),
            "color2 " + green, "color10 " + bright(green),
            "color3 " + yellow, "color11 " + bright(yellow),
            "color4 " + blue, "color12 " + bright(blue),
            "color5 " + p.accent, "color13 " + p.accentSoft,
            "color6 " + cyan, "color14 " + bright(cyan),
            "color7 " + p.subtext, "color15 " + p.text,
            "",
            "# tema yuvaları (fastfetch canlı renkleri)",
            ...slots(p).map((c, i) => "color" + (17 + i) + " " + c),
            ""
        ]
        return L.join("\n")
    }

    // ---- fastfetch: tema renkli dağıtım logosu ----
    readonly property string ffFile: Quickshell.env("HOME") + "/.config/fastfetch/config.jsonc"

    function buildFastfetch(p) {
        // kitty eşlemesi açıksa yuva renkleri (canlı değişir), değilse doğrudan RGB
        const sl = n => {
            if (Config.kittySync) return "38;5;" + n
            const c = Qt.color(slots(p)[n - 17])
            return "38;2;" + Math.round(c.r * 255) + ";" + Math.round(c.g * 255) + ";" + Math.round(c.b * 255)
        }
        const ic = c => String.fromCodePoint(c)
        // bölümler: [başlık simgesi, başlık, satırlar[[tür, simge, ad, ek ayarlar]]]
        const sections = [
            [0xf08c7, "system", [
                ["os", 0xf08c7, "OS"],
                ["kernel", 0xf17c, "Kernel"],
                ["uptime", 0xf0150, "Uptime"],
                ["packages", 0xf03d6, "Packages"],
                ["shell", 0xf489, "Shell"]
            ]],
            [0xf01c5, "hardware", [
                ["host", 0xf01c5, "Host"],
                ["cpu", 0xf4bc, "CPU", { temp: true, showPeCoreCount: true }],
                ["gpu", 0xf08ae, "GPU", { temp: true }],
                ["memory", 0xf035b, "Memory"],
                ["swap", 0xf04e1, "Swap"],
                ["disk", 0xf02ca, "Disk", { folders: "/" }],
                ["display", 0xf0379, "Display"]
            ]],
            [0xf108, "desktop", [
                ["wm", 0xf05af, "WM"],
                ["custom", 0xf03d8, "Theme", { format: (p.name || p.id) }],
                ["terminal", 0xe795, "Terminal"],
                ["terminalfont", 0xf0284, "Font"]
            ]]
        ]
        const total = sections.reduce((n, s) => n + s[2].length, 0)
        const grad = i => sl(23 + Math.min(7, Math.floor(i * 8 / total)))
        const line = n => "─".repeat(n)
        const mods = ["break", { type: "title", format: "{user-name-colored}{at-symbol-colored}{host-name-colored}",
                                 color: { user: sl(17), at: sl(18), host: sl(19) } }]
        let k = 0
        sections.forEach((sec, si) => {
            const head = (si === 0 ? " ╭─ " : " ├─ ") + ic(sec[0]) + " " + sec[1] + " "
            mods.push({ type: "custom", format: "{#" + sl(17) + "}" + head.slice(0, 4) + "{#1;" + sl(18) + "}"
                        + head.slice(4) + "{#" + sl(17) + "}" + line(Math.max(4, 30 - head.length)) })
            sec[2].forEach(r => {
                const m = Object.assign({ type: r[0], key: " │ " + ic(r[1]) + " " + r[2], keyColor: grad(k++) }, r[3] || {})
                if (r[0] === "custom") m.format = "{#" + sl(20) + "}" + m.format
                mods.push(m)
            })
        })
        mods.push({ type: "custom", format: "{#" + sl(19) + "} ╰" + line(13) + " " + ic(0xf0054) + " " + line(14) })
        mods.push("break", { type: "colors", symbol: "circle", paddingLeft: 3 })
        const bar = {
            char: { elapsed: "■", total: "·" },
            border: { left: "", right: "" },
            color: { elapsed: sl(17), total: sl(21) },
            width: 10
        }
        const cfg = {
            "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
            logo: { padding: { top: 2, left: 2, right: 3 }, color: { "1": sl(17), "2": sl(18) } },
            display: {
                separator: " " + ic(0xf0054) + " ",
                color: { separator: sl(18), output: sl(20) },
                key: { width: 17 },
                bar: bar,
                percent: { type: 3, color: { green: sl(19), yellow: sl(17), red: sl(22) } }
            },
            modules: mods
        }
        return "// Felinora-shell tarafından otomatik yazılır (tema: " + (p.name || p.id) + ")\n"
             + "// önceki ayarın yedeği: config.jsonc.felinora-yedek\n" + JSON.stringify(cfg, null, 2) + "\n"
    }

    function apply() {
        const conf = build(pal)
        const target = Object.assign(Config.kittySync ? colorMap(conf) : {}, Config.cavaSync ? cavaColors(pal) : {})
        const animate = shownMap !== null && JSON.stringify(shownMap) !== JSON.stringify(target)
        Quickshell.execDetached(["sh", "-c",
            '[ "$6" = 1 ] && { printf "%s" "$1" > "$2"; [ "$5" = 1 ] && pkill -USR1 -x kitty; }; '
            + '[ "$7" = 1 ] || exit 0; '
            + 'mkdir -p "$(dirname "$4")"; '
            + 'if [ -f "$4" ] && ! grep -q "Felinora-shell tarafından" "$4" && [ ! -f "$4.felinora-yedek" ]; then cp "$4" "$4.felinora-yedek"; fi; '
            + 'printf "%s" "$3" > "$4"; true',
            "sh", conf, file, buildFastfetch(pal), ffFile, animate ? "0" : "1",
            Config.kittySync ? "1" : "0", Config.fastfetchSync ? "1" : "0"])
        if (animate) {
            fromMap = fade.running ? blendMap(t) : shownMap   // yarıda kalan geçişten devam
            toMap = target
            fade.restart()
        } else {
            shownMap = target
            applyQt(pal)
            if (Config.cavaSync) Quickshell.execDetached(["sh", "-c", cavaBackup + 'printf "%s" "$1" > "$2" && pkill -USR1 -x cava; true',
                                                         "sh", buildCava(target), cavaFile])
        }
    }

    // ---- Qt / KDE uygulamaları (Dolphin vb.): qt6ct renk şeması + kdeglobals (config.json → qt.sync) ----
    // Gerekli: QT_QPA_PLATFORMTHEME=qt6ct. qt6ct yalnızca klasörde dosya yeniden adlandırılınca fark eder
    // (tmp + mv) ve ~3 sn sonra uygular; bu yüzden Qt uygulamalarında geçiş yumuşak değil, tek seferde olur.
    readonly property string qtDir: Quickshell.env("HOME") + "/.config/qt6ct"
    function buildQtColors(p) {
        const bg = p.bg, alt = p.bgAlt || mix(p.bg, p.surface2, 0.35)
        const surf = p.surface || mix(p.bg, p.surface2, 0.6), border = p.border || p.surface3
        const sel = mix(surf, p.accent, 0.42)
        // QPalette rol sırası: WindowText Button Light Midlight Dark Mid Text BrightText ButtonText Base Window Shadow
        //                      Highlight HighlightedText Link LinkVisited AlternateBase NoRole ToolTipBase ToolTipText PlaceholderText Accent
        const row = (txt, btxt) => [txt, p.surface2, p.surface3, p.surface2, bg, border, txt, "#ffffff", btxt, alt, bg, "#000000",
                                    sel, p.text, p.accent, p.accent2, surf, bg, p.surface2, p.text, p.muted, p.accent].join(", ")
        return "[ColorScheme]\nactive_colors=" + row(p.text, p.text) + "\ninactive_colors=" + row(p.text, p.text)
             + "\ndisabled_colors=" + row(p.muted, p.muted) + "\n"
    }
    function applyQt(p) {
        if (!Config.qtSync) return
        const scheme = qtDir + "/colors/felinora.conf"
        // qt6ct.conf'ta yalnızca renk şeması satırları değiştirilir (ilk seferde yedeklenir)
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$(dirname "$2")" && printf "%s" "$1" > "$2.tmp" && mv "$2.tmp" "$2"; c="$3"; '
            + '[ -f "$c" ] && [ ! -f "$c.felinora-yedek" ] && cp "$c" "$c.felinora-yedek"; '
            + '[ -f "$c" ] || printf "[Appearance]\\n" > "$c"; '
            + 'grep -v "^color_scheme_path=\\|^custom_palette=" "$c" | sed "/^\\[Appearance\\]/a color_scheme_path=$2\\ncustom_palette=true" > "$c.tmp" && mv "$c.tmp" "$c"; true',
            "sh", buildQtColors(p), scheme, qtDir + "/qt6ct.conf"])
        // KDE uygulamaları renkleri kdeglobals + Felinora.colors şemasından okur
        const keys = ["bg", "bgAlt", "surface", "surface2", "surface3", "accent", "accent2", "text", "subtext", "muted"]
        const kp = {}
        keys.forEach(k => { if (p[k] !== undefined) kp[k] = String(p[k]) })
        Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/kde-colors.py"), JSON.stringify(kp)])
    }

    // ---- cava: temanın renklerinde degrade çubuklar (config.json → cava.sync) ----
    // ~/.config/cava/config yeniden yazılır; ilk seferde eskisi config.felinora-yedek olarak saklanır.
    readonly property string cavaFile: Quickshell.env("HOME") + "/.config/cava/config"
    readonly property string cavaBackup: 'mkdir -p "$(dirname "$2")"; if [ -f "$2" ] && ! grep -q "Felinora-shell tarafından" "$2" && [ ! -f "$2.felinora-yedek" ]; then cp "$2" "$2.felinora-yedek"; fi; '
    function cavaColors(p) {
        const m = {}
        // aşağıdan yukarı: koyu ikinci vurgu → ikinci vurgu → ana vurgu → yumuşak vurgu
        const stops = [p.accent2Deep, p.accent2, p.accent, p.accentSoft]
        for (let i = 0; i < 8; i++) {
            const x = i / 7 * (stops.length - 1), j = Math.min(stops.length - 2, Math.floor(x))
            m["cava.g" + (i + 1)] = mix(stops[j], stops[j + 1], x - j)
        }
        return m
    }
    function buildCava(m) {
        const q = c => "'" + c + "'"
        const L = [
            "; Felinora-shell tarafından otomatik yazılır — tema değişince ezilir.",
            "; önceki ayarın yedeği: config.felinora-yedek",
            "", "[general]", "framerate = 60", "autosens = 1",
            "bar_width = 2", "bar_spacing = 1",
            "", "[input]", "method = pulse", "source = auto",
            "", "[output]", "method = noncurses", "channels = stereo", "show_idle_bar_heads = 1",
            "", "[color]", "gradient = 1"
        ]
        for (let i = 1; i <= 8; i++) L.push("gradient_color_" + i + " = " + q(m["cava.g" + i] || "#ffffff"))
        L.push("", "[smoothing]", "noise_reduction = 80", "monstercat = 1", "waves = 0", "gravity = 120", "")
        return L.join("\n")
    }
}
