// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import "../config"

// küçük canlı grafik
Canvas {
    id: s
    property var values: []
    property color lineColor: Theme.pink
    property real maxValue: 0
    onValuesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onPaint: {
        const c = getContext("2d")
        c.reset()
        const v = values
        if (!v || v.length < 2) return
        let m = maxValue > 0 ? maxValue : 1
        for (let i = 0; i < v.length; i++) m = Math.max(m, v[i])
        const step = width / (v.length - 1)
        c.beginPath()
        for (let i = 0; i < v.length; i++) {
            const x = i * step, y = height - 2 - (v[i] / m) * (height - 4)
            if (i === 0) c.moveTo(x, y); else c.lineTo(x, y)
        }
        c.lineWidth = 2
        c.lineJoin = "round"
        c.strokeStyle = lineColor
        c.stroke()
        c.lineTo(width, height); c.lineTo(0, height); c.closePath()
        const g = c.createLinearGradient(0, 0, 0, height)
        g.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.35))
        g.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0))
        c.fillStyle = g
        c.fill()
    }
}
