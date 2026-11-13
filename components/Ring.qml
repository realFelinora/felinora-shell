// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import "../config"

// yay şeklinde yüzde halkası (pembe→mor)
Item {
    id: r
    property real value: 0
    property real thickness: 10
    property color c1: Theme.pink
    property color c2: Theme.purple
    property color track: Theme.surface3
    property real shown: 0
    Behavior on shown { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    onValueChanged: shown = Math.max(0, Math.min(1, value))
    Component.onCompleted: shown = Math.max(0, Math.min(1, value))
    onShownChanged: cv.requestPaint()
    onC1Changed: cv.requestPaint()
    onC2Changed: cv.requestPaint()
    onTrackChanged: cv.requestPaint()

    Canvas {
        id: cv
        anchors.fill: parent
        onPaint: {
            const c = getContext("2d")
            c.reset()
            const w = width, h = height
            const rad = Math.min(w, h) / 2 - r.thickness / 2 - 1
            const start = Math.PI * 0.75, sweep = Math.PI * 1.5
            c.lineCap = "round"
            c.lineWidth = r.thickness
            c.strokeStyle = r.track
            c.beginPath(); c.arc(w / 2, h / 2, rad, start, start + sweep); c.stroke()
            if (r.shown > 0.005) {
                const g = c.createLinearGradient(0, h, w, 0)
                g.addColorStop(0, r.c1); g.addColorStop(1, r.c2)
                c.strokeStyle = g
                c.beginPath(); c.arc(w / 2, h / 2, rad, start, start + sweep * r.shown); c.stroke()
            }
        }
    }
}
