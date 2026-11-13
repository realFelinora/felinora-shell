// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import "../config"

// kart: tepesi vurgu rengine hafifçe çalan degrade + üst kenarda ince parıltı
Rectangle {
    id: card
    property real glow: 0.32          // üst parıltının gücü (0 = yok)
    radius: Theme.radius
    border.width: 1
    border.color: Theme.border
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.tint(Theme.surface, Qt.alpha(Theme.pink, 0.05)) }
        GradientStop { position: 0.55; color: Theme.surface }
        GradientStop { position: 1.0; color: Qt.darker(Theme.surface, 1.08) }
    }

    Rectangle {
        z: 10
        visible: card.glow > 0
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - card.radius * 2
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.alpha(Theme.pink, card.glow) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
