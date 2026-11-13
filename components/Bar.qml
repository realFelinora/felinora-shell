// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import "../config"

// yatay doluluk çubuğu
Rectangle {
    id: b
    property real value: 0
    property color c1: Theme.pink
    property color c2: Theme.purple
    implicitHeight: 8
    radius: height / 2
    color: Theme.surface3
    Rectangle {
        height: parent.height
        radius: parent.radius
        width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, b.value)))
        Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: b.c1 }
            GradientStop { position: 1; color: b.c2 }
        }
    }
}
