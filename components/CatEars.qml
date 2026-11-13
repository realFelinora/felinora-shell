// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import "../config"

// herhangi bir kartın üstüne kondurulan kedi kulakları
Item {
    id: ears
    property real earSize: 26
    property real inset: 18
    property color fill: Theme.surface2
    property color line: Theme.pink
    height: earSize
    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined
    anchors.bottom: parent ? parent.top : undefined
    anchors.bottomMargin: -6

    component Ear: Canvas {
        id: earCv
        property bool flip: false
        Connections { target: ears; function onFillChanged() { earCv.requestPaint() } function onLineChanged() { earCv.requestPaint() } }
        width: ears.earSize; height: ears.earSize
        transformOrigin: Item.Bottom
        onPaint: {
            const c = getContext("2d"); c.reset()
            const tip = flip ? width * 0.72 : width * 0.28
            c.beginPath(); c.moveTo(1, height); c.lineTo(tip, 1.5); c.lineTo(width - 1, height); c.closePath()
            c.fillStyle = ears.fill; c.fill()
            c.lineWidth = 2; c.lineJoin = "round"; c.strokeStyle = ears.line; c.stroke()
            c.beginPath(); c.moveTo(width * 0.24, height); c.lineTo(flip ? width * 0.66 : width * 0.34, height * 0.32); c.lineTo(width * 0.76, height); c.closePath()
            c.fillStyle = Qt.alpha(ears.line, 0.45); c.fill()
        }
    }

    Ear { id: l; x: ears.inset; rotation: -12 }
    Ear { id: r; x: ears.width - width - ears.inset; rotation: 12; flip: true }

    SequentialAnimation {
        id: twitch
        property Item target: l
        property real base: -12
        NumberAnimation { target: twitch.target; property: "rotation"; to: twitch.base * 2.2; duration: 90 }
        NumberAnimation { target: twitch.target; property: "rotation"; to: twitch.base; duration: 500; easing.type: Easing.OutElastic }
    }
    Timer {
        interval: 4000 + Math.random() * 3000; running: ears.visible; repeat: true
        onTriggered: {
            const left = Math.random() > 0.5
            twitch.target = left ? l : r
            twitch.base = left ? -12 : 12
            twitch.restart()
        }
    }
}
