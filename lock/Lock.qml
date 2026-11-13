// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../config"

// kilit ekranı: Wayland oturum kilidi + PAM şifre kontrolü
// kilitle:  qs -c felinora-shell ipc call lock lock
Scope {
    id: root

    property string buffer: ""        // yazılan şifre (ekranda sadece pati olarak görünür)
    property string status: ""        // "" | checking | fail | error | success
    property bool exiting: false      // doğru şifre → çıkış animasyonu
    property string wallpaper: ""
    property bool caps: false
    signal failed()

    function lockNow() {
        if (sessionLock.locked) return
        buffer = ""
        status = ""
        exiting = false
        wpProc.running = true
        sessionLock.locked = true
    }

    function submit() {
        if (exiting || pam.active || buffer.length === 0) return
        status = "checking"
        pam.start()
    }

    Connections {
        target: Ui
        function onLockRequested() { root.lockNow() }
    }

    // hiçbir şey yapılmadan Prefs.lockMinutes dakika geçince kilitle
    // (video izlerken uygulamaların "uyku engeli" varsa beklenir)
    IdleMonitor {
        enabled: Prefs.lockMinutes > 0 && !sessionLock.locked
        timeout: Prefs.lockMinutes * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) root.lockNow()
    }

    WlSessionLock {
        id: sessionLock
        LockSurface { ctx: root }
    }

    PamContext {
        id: pam
        config: "passwd"
        configDirectory: Quickshell.shellPath("assets/pam.d")

        onResponseRequiredChanged: {
            if (!responseRequired) return
            respond(root.buffer)
        }
        onCompleted: res => {
            root.buffer = ""
            if (res === PamResult.Success) {
                root.status = "success"
                root.exiting = true
                unlockTimer.restart()
            } else {
                root.status = res === PamResult.Failed ? "fail" : "error"
                root.failed()
                statusReset.restart()
            }
        }
    }

    // çıkış animasyonu bitince kilidi gerçekten aç
    Timer {
        id: unlockTimer
        interval: 720
        onTriggered: {
            sessionLock.locked = false
            root.exiting = false
            root.status = ""
        }
    }
    Timer {
        id: statusReset
        interval: 3500
        onTriggered: if (root.status === "fail" || root.status === "error") root.status = ""
    }

    // kilitlenirken şu anki duvar kağıdı
    Process {
        id: wpProc
        command: ["sh", "-c", "awww query 2>/dev/null || swww query 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = this.text.match(/image: (.+)$/m)
                root.wallpaper = m ? m[1].trim() : ""
            }
        }
    }

    // caps lock ışığı
    Process {
        id: capsProc
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | head -1"]
        stdout: StdioCollector { onStreamFinished: root.caps = this.text.trim() === "1" }
    }
    Timer {
        interval: 400
        repeat: true
        running: sessionLock.locked
        triggeredOnStart: true
        onTriggered: capsProc.running = true
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lockNow() }
        function isLocked(): bool { return sessionLock.locked }
    }
}
