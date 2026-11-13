pragma Singleton
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Özel (special) workspace takibi + Hyprland dispatch yardımcıları.
// Hyprland'in yeni Lua config'i ile klasik hyprland.conf farklı dispatch sözdizimi kullanır;
// açılışta hangisi olduğu otomatik algılanır.
Singleton {
    id: root
    property string special: ""   // "" = özel workspace kapalı
    property bool lua: false      // true: Lua config (hl.dsp.*), false: klasik sözdizimi

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name === "activespecial") {
                const ws = ev.data.split(",")[0]
                root.special = ws.replace(/^special:/, "")
            }
        }
    }

    Process {
        running: true
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const mons = JSON.parse(this.text)
                    const m = mons.find(x => x.focused) || mons[0]
                    root.special = (m.specialWorkspace.name || "").replace(/^special:/, "")
                } catch (e) {}
            }
        }
    }

    // Lua config mi? Lua'da hl.dsp.no_op() geçerli bir dispatcher'dır, klasikte hata verir.
    Process {
        running: true
        command: ["hyprctl", "dispatch", "hl.dsp.no_op()"]
        stdout: StdioCollector { onStreamFinished: root.lua = this.text.trim() === "ok" }
    }

    function addr(a) { return a.startsWith("0x") ? a : "0x" + a }
    function dsp(expr) { Hyprland.dispatch(expr) }
    function q(s) { return "\"" + s + "\"" }
    function sel(a) { return "window = " + q("address:" + addr(a)) }

    function focusWs(id) {
        lua ? dsp("hl.dsp.focus({ workspace = " + id + " })") : dsp("workspace " + id)
    }
    function focusWsRel(delta) {
        const r = "e" + (delta > 0 ? "+" : "-") + "1"
        lua ? dsp("hl.dsp.focus({ workspace = " + q(r) + " })") : dsp("workspace " + r)
    }
    function toggleSpecial(name) {
        lua ? dsp("hl.dsp.workspace.toggle_special(" + q(name) + ")") : dsp("togglespecialworkspace " + name)
    }
    function focusWin(a) {
        lua ? dsp("hl.dsp.focus({ " + sel(a) + " })") : dsp("focuswindow address:" + addr(a))
    }
    function closeWin(a) {
        lua ? dsp("hl.dsp.window.close({ " + sel(a) + " })") : dsp("closewindow address:" + addr(a))
    }
    function floatWin(a) {
        lua ? dsp("hl.dsp.window.float({ " + sel(a) + ", action = \"toggle\" })") : dsp("togglefloating address:" + addr(a))
    }
    function fullscreenWin(a) {
        if (lua) dsp("hl.dsp.window.fullscreen({ " + sel(a) + " })")
        else { dsp("focuswindow address:" + addr(a)); dsp("fullscreen 0") }
    }
    function pinWin(a) {
        lua ? dsp("hl.dsp.window.pin({ " + sel(a) + " })") : dsp("pin address:" + addr(a))
    }
    function moveWin(a, ws) {
        if (lua) {
            const w = typeof ws === "number" ? ws : q(ws)
            dsp("hl.dsp.window.move({ workspace = " + w + ", " + sel(a) + " })")
        } else dsp("movetoworkspacesilent " + ws + ",address:" + addr(a))
    }
    function exit() { lua ? dsp("hl.dsp.exit()") : dsp("exit") }
}
