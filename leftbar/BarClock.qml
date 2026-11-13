// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import Quickshell
import "../config"
import "../components"

// 12 saatlik dikey saat + AM/PM
Item {
    id: root
    implicitWidth: 44
    implicitHeight: col.implicitHeight

    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property int h12: clock.hours % 12 === 0 ? 12 : clock.hours % 12
    readonly property string ampm: clock.hours < 12 ? "AM" : "PM"
    function pad(n) { return n < 10 ? "0" + n : "" + n }

    Column {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.pad(root.h12)
            mono: true
            size: 19
            font.weight: Font.Bold
            color: Theme.pink
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            height: 6
            Repeater {
                model: 2
                Rectangle {
                    width: 3; height: 3; radius: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.purple
                    opacity: clock.seconds % 2 === 0 ? 1 : 0.25
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
            }
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.pad(clock.minutes)
            mono: true
            size: 19
            font.weight: Font.Bold
            color: Theme.text
        }
        Item { width: 1; height: 4 }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 32; height: 16; radius: 8
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.pink }
                GradientStop { position: 1; color: Theme.purple }
            }
            Txt {
                anchors.centerIn: parent
                text: root.ampm
                size: 10
                font.weight: Font.Black
                color: Theme.bg
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.openTab("dashboard")
    }
}
