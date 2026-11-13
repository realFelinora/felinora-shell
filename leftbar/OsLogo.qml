// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Effects
import "../config"
import "../components"
import "../services"

// kedi kulaklı Arch rozeti — tıkla: dashboard
Item {
    id: root
    implicitWidth: 44
    implicitHeight: 52

    property real glow: ma.containsMouse || Ui.dashboardOpen ? 1 : 0.45
    Behavior on glow { NumberAnimation { duration: 250 } }

    Item {
        id: badgeBox
        width: 40; height: 40
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        rotation: ma.containsMouse ? -6 : 0
        Behavior on rotation { NumberAnimation { duration: 450; easing.type: Easing.OutElastic } }

        CatEars {
            earSize: 15
            inset: 1
            fill: Theme.surface2
        }

        Rectangle {
            id: badge
            anchors.fill: parent
            radius: 14
            color: Theme.surface2
            border.width: 2
            border.color: Theme.pink

            Icon {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1
                text: Theme.osIcon(SysInfo.osId)
                size: 22
                color: Theme.pink
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.pink
                    shadowBlur: 0.8
                    shadowOpacity: root.glow
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.dashboardOpen = !Ui.dashboardOpen
    }
}
