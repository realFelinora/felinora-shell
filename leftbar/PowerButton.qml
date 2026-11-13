// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import "../config"
import "../components"

Item {
    implicitWidth: 44
    implicitHeight: 42

    Rectangle {
        anchors.centerIn: parent
        width: 38; height: 38; radius: 19
        color: ma.containsMouse || Ui.sessionOpen ? Theme.pink : Theme.surface
        border.width: 1
        border.color: Qt.alpha(Theme.pink, 0.45)
        Behavior on color { ColorAnimation { duration: 160 } }

        Icon {
            anchors.centerIn: parent
            text: Theme.power
            size: 18
            color: ma.containsMouse || Ui.sessionOpen ? Theme.bg : Theme.pink
            rotation: ma.containsMouse ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: 350; easing.type: Easing.OutBack } }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.sessionOpen = !Ui.sessionOpen
    }
}
