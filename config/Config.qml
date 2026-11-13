pragma Singleton
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import Quickshell
import Quickshell.Io
import QtQuick

// Kullanıcı ayarları: ~/.config/felinora-shell/config.json
// Dosya yoksa ya da bir alan eksikse aşağıdaki varsayılanlar kullanılır.
// Örnek dosya: config.example.json
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.config/felinora-shell/config.json"

    // uygulamalar
    property string terminal: "kitty"
    property string networkSettings: "nm-connection-editor"

    // resimler (boş = resim yerine ikon gösterilir)
    property var images: ({ workspace: "", special: "", spin: "", sleep: "", avatar: "" })

    // hava durumu: şehir boşsa konum IP'den bulunur
    property string weatherCity: ""


    // kitty + fastfetch tema eşlemesi (isteğe bağlı; README → "Kitty ve fastfetch")
    property bool kittySync: false
    property bool fastfetchSync: false
    // cava ve Qt/KDE uygulamaları (Dolphin vb.) tema eşlemesi (isteğe bağlı; README)
    property bool cavaSync: false
    property bool qtSync: false

    // dosya yöneticisi: listede hiç görünmeyecek yollar ve "Birlikte aç"ta hep duran uygulamalar (.desktop adları)
    property var filesHidden: []
    property var filesPinned: []

    property bool loaded: false

    // resim yolunu Image için hazırlar ("~/" desteklenir); boşsa "" döner
    function image(kind) {
        const p = images && images[kind] ? String(images[kind]) : ""
        if (!p) return ""
        return "file://" + expand(p)
    }
    function expand(p) { return p.startsWith("~/") ? Quickshell.env("HOME") + p.slice(1) : p }

    Process {
        running: true
        command: ["cat", root.path]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text)
                    if (d.terminal) root.terminal = d.terminal
                    if (d.networkSettings) root.networkSettings = d.networkSettings
                    if (d.images) root.images = Object.assign({}, root.images, d.images)
                    if (d.weather && d.weather.city) root.weatherCity = d.weather.city
                    if (d.kitty) root.kittySync = !!d.kitty.sync
                    if (d.fastfetch) root.fastfetchSync = !!d.fastfetch.sync
                    if (d.cava) root.cavaSync = !!d.cava.sync
                    if (d.qt) root.qtSync = !!d.qt.sync
                    if (d.files) {
                        if (Array.isArray(d.files.alwaysHidden)) root.filesHidden = d.files.alwaysHidden.map(p => root.expand(String(p)))
                        if (Array.isArray(d.files.pinnedApps)) root.filesPinned = d.files.pinnedApps.map(String)
                    }
                } catch (e) {
                    if (this.text.trim() !== "") console.warn("config.json okunamadı:", e)
                }
                root.loaded = true
            }
        }
    }
}
