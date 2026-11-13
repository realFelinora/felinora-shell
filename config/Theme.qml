pragma Singleton
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import Quickshell
import QtQuick
import "../services"

// tema sistemi — hepsi koyu, Prefs.theme ile seçilir
Singleton {
    id: theme

    readonly property var baseThemes: [
        { id: "pembe", name: "Pembe Gece", desc: "pembe & mor",
          bg: "#0a090d", bgAlt: "#0f0d13", surface: "#141119", surface2: "#1c1823", surface3: "#27212f", border: "#2a2332", frame: "#0b0a0e",
          accent: "#ff79c6", accentSoft: "#ffb8e0", accent2: "#a77bff", accent2Deep: "#6f45d9", tint: "#d6c1ff",
          text: "#f2eaf7", subtext: "#a197b0", muted: "#5d5469" },
        { id: "obsidyen", name: "Obsidyen", desc: "simsiyah + pembe & mor", frameTint: 0,
          bg: "#070608", bgAlt: "#0b0a0d", surface: "#121015", surface2: "#1a171e", surface3: "#25202b", border: "#26212c", frame: "#050406",
          accent: "#ff79c6", accentSoft: "#ffb8e0", accent2: "#a77bff", accent2Deep: "#6f45d9", tint: "#d6c1ff",
          text: "#f2eaf7", subtext: "#a197b0", muted: "#5d5469" },
        { id: "gece", name: "Gece Moru", desc: "derin menekşe",
          bg: "#08080d", bgAlt: "#0d0c14", surface: "#12111a", surface2: "#1a1824", surface3: "#252233", border: "#262335", frame: "#0a0910",
          accent: "#b794ff", accentSoft: "#dccbff", accent2: "#7c6cff", accent2Deep: "#4c3fc9", tint: "#cfc6ff",
          text: "#ece9f7", subtext: "#9b97b3", muted: "#565271" },
        { id: "kan", name: "Kan Kırmızısı", desc: "koyu kızıl",
          bg: "#0b0708", bgAlt: "#110b0d", surface: "#161012", surface2: "#1f1619", surface3: "#2b1e22", border: "#2e2024", frame: "#0d0809",
          accent: "#ff4d6d", accentSoft: "#ffb3c1", accent2: "#c9184a", accent2Deep: "#800f2f", tint: "#ffccd5",
          text: "#f7eaec", subtext: "#b39a9f", muted: "#6b5458" },
        { id: "buz", name: "Buz Mavisi", desc: "soğuk ve sakin",
          bg: "#07090d", bgAlt: "#0b0e14", surface: "#10141b", surface2: "#171c25", surface3: "#212836", border: "#222a37", frame: "#090b10",
          accent: "#7dd3fc", accentSoft: "#c9ecff", accent2: "#818cf8", accent2Deep: "#4f46e5", tint: "#c7d2fe",
          text: "#e8eef7", subtext: "#94a3b8", muted: "#526075" },
        { id: "sakura", name: "Sakura", desc: "açık pembe & fuşya",
          bg: "#0c090b", bgAlt: "#120d10", surface: "#171215", surface2: "#20191d", surface3: "#2c2228", border: "#30252b", frame: "#0e0a0c",
          accent: "#ffa6c9", accentSoft: "#ffd6e5", accent2: "#e879f9", accent2Deep: "#a21caf", tint: "#ffe4ef",
          text: "#fbeef3", subtext: "#b8a2ad", muted: "#6e5a64" },
        { id: "nane", name: "Nane", desc: "nane & lavanta",
          bg: "#070a09", bgAlt: "#0b0f0e", surface: "#0f1513", surface2: "#161e1b", surface3: "#1f2a26", border: "#203029", frame: "#090c0b",
          accent: "#6ee7b7", accentSoft: "#c6f6e3", accent2: "#a78bfa", accent2Deep: "#6d28d9", tint: "#d1fae5",
          text: "#e8f5ef", subtext: "#93ada3", muted: "#50655d" }
    ]
    // 8. tema "Şarkı": çalan şarkının albüm kapağından renk alır (services/SongColors.qml)
    readonly property var themes: baseThemes.concat([SongColors.theme])
    readonly property var current: {
        if (Prefs.theme === "sarki") return SongColors.theme
        for (let i = 0; i < baseThemes.length; i++) if (baseThemes[i].id === Prefs.theme) return baseThemes[i]
        return baseThemes[0]
    }

    // zemin
    property color bg:       current.bg
    property color bgAlt:    current.bgAlt
    property color surface:  current.surface
    property color surface2: current.surface2
    property color surface3: current.surface3
    property color border:   current.border
    // çerçeve/bar/panel zemini: saf siyah değil, temanın ikinci vurgusuna çalan koyu ton
    // tonlama gücü temaya göre (frameTint: 0 = simsiyah çerçeve)
    readonly property real frameTint: current.frameTint !== undefined ? current.frameTint : 0.21
    property color frameColor: Qt.tint(current.frame, Qt.alpha(current.accent2, frameTint))
    // çerçeve degradesinin uçları (üst: ana vurgu, alt: ikinci vurgu)
    property color frameTop: Qt.tint(current.frame, Qt.alpha(current.accent, frameTint > 0 ? frameTint + 0.1 : 0))
    property color frameBottom: Qt.tint(current.frame, Qt.alpha(current.accent2, frameTint > 0 ? frameTint + 0.12 : 0))

    // vurgular (isimler eski: pink = ana vurgu, purple = ikinci vurgu)
    property color pink:       current.accent
    property color pinkSoft:   current.accentSoft
    property color purple:     current.accent2
    property color purpleDeep: current.accent2Deep
    property color lavender:   current.tint
    readonly property color red:  "#ff5c7c"
    readonly property color warn: "#ffb36b"

    // yazı
    property color text:    current.text
    property color subtext: current.subtext
    property color muted:   current.muted

    // tema değişince renkler yumuşakça geçsin
    Behavior on bg { ColorAnimation { duration: 500 } }
    Behavior on bgAlt { ColorAnimation { duration: 500 } }
    Behavior on surface { ColorAnimation { duration: 500 } }
    Behavior on surface2 { ColorAnimation { duration: 500 } }
    Behavior on surface3 { ColorAnimation { duration: 500 } }
    Behavior on border { ColorAnimation { duration: 500 } }
    Behavior on frameColor { ColorAnimation { duration: 500 } }
    Behavior on frameTop { ColorAnimation { duration: 500 } }
    Behavior on frameBottom { ColorAnimation { duration: 500 } }
    Behavior on pink { ColorAnimation { duration: 500 } }
    Behavior on pinkSoft { ColorAnimation { duration: 500 } }
    Behavior on purple { ColorAnimation { duration: 500 } }
    Behavior on purpleDeep { ColorAnimation { duration: 500 } }
    Behavior on lavender { ColorAnimation { duration: 500 } }
    Behavior on text { ColorAnimation { duration: 500 } }
    Behavior on subtext { ColorAnimation { duration: 500 } }
    Behavior on muted { ColorAnimation { duration: 500 } }

    readonly property string font: "Nunito"
    readonly property string mono: "JetBrainsMono Nerd Font Propo"
    readonly property string iconFont: "JetBrainsMono Nerd Font Propo"

    readonly property int barWidth: 56
    // çerçeve (caelestia shell'den esinlenildi)
    readonly property int frame: 8          // üst/sağ/alt kenar kalınlığı
    readonly property int frameRadius: 24   // çerçevenin iç köşeleri
    readonly property int panelRadius: 22   // panellerin köşeleri + ters köşeler

    // Material 3 "expressive" animasyon eğrileri (Easing.BezierSpline için)
    readonly property var curveSpatial: [0.38, 1.21, 0.22, 1.0, 1, 1]     // hafif esneyip oturur (açılış)
    readonly property var curveEmphDecel: [0.05, 0.7, 0.1, 1.0, 1, 1]     // hızlı başlar, yumuşak durur
    readonly property var curveEmphAccel: [0.3, 0.0, 0.8, 0.15, 1, 1]     // yavaş başlar, hızlı çekilir (kapanış)
    readonly property var curveStandard: [0.2, 0.0, 0.0, 1.0, 1, 1]
    readonly property int radius: 18

    // /etc/os-release ID → dağıtım logosu (Nerd Font)
    readonly property var osIcons: ({
        arch: 0xf303, debian: 0xf306, ubuntu: 0xf31b, fedora: 0xf30a, nixos: 0xf313,
        opensuse: 0xf314, "opensuse-tumbleweed": 0xf314, "opensuse-leap": 0xf314, manjaro: 0xf312,
        endeavouros: 0xf322, gentoo: 0xf30d, void: 0xf32e, linuxmint: 0xf30e, pop: 0xf32a,
        cachyos: 0xf385, garuda: 0xf337, artix: 0xf31f, alpine: 0xf300, kali: 0xf327
    })
    function osIcon(id) { return String.fromCodePoint(osIcons[id] || 0xf31a) }

    // ikonlar
    function cp(c) { return String.fromCodePoint(c) }
    readonly property string arch:      cp(0xf303)
    readonly property string paw:       cp(0xf03e9)
    readonly property string heart:     cp(0xf02d1)
    readonly property string power:     cp(0xf0425)
    readonly property string sleep:     cp(0xf0904)
    readonly property string restart:   cp(0xf0709)
    readonly property string logout:    cp(0xf0343)
    readonly property string ethernet:  cp(0xf0200)
    readonly property string wifiOff:   cp(0xf05aa)
    readonly property var    wifiLevels: [cp(0xf091f), cp(0xf0922), cp(0xf0925), cp(0xf0928)]
    readonly property string lanOff:    cp(0xf0319)
    readonly property string shield:    cp(0xf0565)
    readonly property string down:      cp(0xf072e)
    readonly property string up:        cp(0xf0737)
    readonly property string cpu:       cp(0xf0ee0)
    readonly property string ram:       cp(0xf035b)
    readonly property string gpu:       cp(0xf08ae)
    readonly property string disk:      cp(0xf02ca)
    readonly property string thermo:    cp(0xf050f)
    readonly property string fan:       cp(0xf0210)
    readonly property string flash:     cp(0xf0241)
    readonly property string speed:     cp(0xf04c5)
    readonly property string pulse:     cp(0xf0430)
    readonly property string web:       cp(0xf059f)
    readonly property string play:      cp(0xf040a)
    readonly property string pause:     cp(0xf03e4)
    readonly property string next:      cp(0xf04ad)
    readonly property string prev:      cp(0xf04ae)
    readonly property string music:     cp(0xf075a)
    readonly property string folder:    cp(0xf024b)
    readonly property string folderImg: cp(0xf024f)
    readonly property string folderOpen: cp(0xf0770)
    readonly property string image:     cp(0xf02e9)
    readonly property string file:      cp(0xf0214)
    readonly property string home:      cp(0xf02dc)
    readonly property string desktop:   cp(0xf07c0)
    readonly property string download:  cp(0xf01da)
    readonly property string back:      cp(0xf004d)
    readonly property string upDir:     cp(0xf005d)
    readonly property string left:      cp(0xf0141)
    readonly property string right:     cp(0xf0142)
    readonly property string close:     cp(0xf0156)
    readonly property string fullscreen: cp(0xf0293)
    readonly property string pin:       cp(0xf0403)
    readonly property string floating:  cp(0xf05b2)
    readonly property string calendar:  cp(0xf00ed)
    readonly property string clock:     cp(0xf0150)
    readonly property string mapPin:    cp(0xf034e)
    readonly property string wind:      cp(0xf059d)
    readonly property string drop:      String.fromCharCode(0xe371)
    readonly property string humidity:  String.fromCharCode(0xe373)
    readonly property string sunrise:   String.fromCharCode(0xe34c)
    readonly property string sunset:    String.fromCharCode(0xe34d)
    readonly property string dashboard: cp(0xf056e)
    readonly property string chart:     cp(0xf154d)
    readonly property string cloud:     cp(0xf0595)
    readonly property string cog:       cp(0xf0493)
    readonly property string refresh:   cp(0xf0450)
    readonly property string check:     cp(0xf012c)
    readonly property string cat:       cp(0xf011b)
    readonly property string palette:   cp(0xf03d8)
    readonly property string moon:      cp(0xf0f65)
    readonly property string account:   cp(0xf0004)
    readonly property string lock:      cp(0xf033e)
    readonly property string search:    cp(0xf0349)
    readonly property string calc:      cp(0xf00ec)
    readonly property string terminal:  cp(0xf018d)
    readonly property string rocket:    cp(0xf14de)
    readonly property string apps:      cp(0xf003b)
    readonly property string returnKey: cp(0xf0311)
    readonly property string upDown:    cp(0xf0e79)
    readonly property string star:      cp(0xf04ce)
    readonly property string fire:      cp(0xf0238)
    readonly property string copy:      cp(0xf018f)
    readonly property string tag:       cp(0xf04f9)
    readonly property string lockOpen:  cp(0xf0fc6)
    readonly property string capsLock:  cp(0xf0632)
    readonly property string alert:     cp(0xf0028)
    readonly property string enter:     cp(0xf0cdf)
    readonly property string checkCircle: cp(0xf05e0)
    readonly property string eye:       cp(0xf0054)
}
