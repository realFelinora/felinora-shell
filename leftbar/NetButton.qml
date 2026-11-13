// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import "../config"
import "../components"
import "../services"

// internet durumu: ikon + nabız halkası + trafik ışıkları
Item {
    id: root
    implicitWidth: 44
    implicitHeight: 54

    readonly property bool rxBusy: SysInfo.rxRate > 20 * 1024
    readonly property bool txBusy: SysInfo.txRate > 20 * 1024
    readonly property color tint: Network.online ? Theme.pink : (Network.type !== "none" ? Theme.warn : Theme.muted)

    Item {
        id: circle
        width: 38; height: 38
        anchors.horizontalCenter: parent.horizontalCenter

        // nabız
        Rectangle {
            id: ring
            anchors.centerIn: parent
            width: 38; height: 38; radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: root.tint
            visible: Network.online
            SequentialAnimation on scale {
                running: Network.online
                loops: Animation.Infinite
                NumberAnimation { from: 0.9; to: 1.35; duration: 1600; easing.type: Easing.OutCubic }
                PauseAnimation { duration: 600 }
            }
            SequentialAnimation on opacity {
                running: Network.online
                loops: Animation.Infinite
                NumberAnimation { from: 0.7; to: 0; duration: 1600; easing.type: Easing.OutCubic }
                PauseAnimation { duration: 600 }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: ma.containsMouse || Ui.netOpen ? Theme.surface3 : Theme.surface
            border.width: 1
            border.color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.5)
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Icon {
            anchors.centerIn: parent
            text: Network.icon
            size: 18
            color: root.tint
        }
        // ↓ ↑ aktivite
        Column {
            anchors.right: parent.right
            anchors.rightMargin: -3
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Rectangle { width: 5; height: 5; radius: 2.5; color: root.txBusy ? Theme.purple : Theme.surface3; Behavior on color { ColorAnimation { duration: 200 } } }
            Rectangle { width: 5; height: 5; radius: 2.5; color: root.rxBusy ? Theme.pink : Theme.surface3; Behavior on color { ColorAnimation { duration: 200 } } }
        }
    }

    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: Network.type === "ethernet" ? "ETH" : Network.type === "wifi" ? "WIFI" : "OFF"
        size: 9
        font.weight: Font.Black
        font.letterSpacing: 1
        color: root.tint
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.netOpen = !Ui.netOpen
    }
}
