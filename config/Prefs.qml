pragma Singleton
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import Quickshell
import Quickshell.Io
import QtQuick

// kalıcı ayarlar: ~/.local/state/felinora-shell/state.json
// (adı "State" değil çünkü QtQuick'in kendi State tipiyle çakışıyor)
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.local/state/felinora-shell"

    property string profile: ""          // profil resmi yolu
    property string disk: ""             // performans sekmesinde seçili fiziksel disk (sda, sdb...)
    property string theme: "pembe"      // seçili renk teması
    property var launches: ({})          // başlatıcı: uygulama id → açılma sayısı
    property int lockMinutes: 10         // bu kadar dakika hiçbir şey yapılmazsa kilitle (0 = kapalı)

    property bool ready: false

    function save() {
        if (!ready) return
        file.setText(JSON.stringify({
            profile: profile, disk: disk, theme: theme, lockMinutes: lockMinutes, launches: launches
        }, null, 2))
    }
    onProfileChanged: save()
    onDiskChanged: save()
    onThemeChanged: save()
    onLockMinutesChanged: save()
    onLaunchesChanged: save()

    function countLaunch(id) {
        const m = Object.assign({}, launches)
        m[id] = (m[id] || 0) + 1
        launches = m
    }

    // açılışta oku
    Process {
        running: true
        command: ["sh", "-c", "mkdir -p \"$1\" && cat \"$1/state.json\" 2>/dev/null", "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text)
                    root.profile = d.profile || ""
                    root.disk = d.disk || ""
                    root.theme = d.theme || "pembe"
                    root.lockMinutes = d.lockMinutes !== undefined ? d.lockMinutes : 10
                    root.launches = d.launches || {}
                } catch (e) {}
                root.ready = true
                root.save()
            }
        }
    }

    // yazmak için
    FileView {
        id: file
        path: root.dir + "/state.json"
        preload: false
    }
}
