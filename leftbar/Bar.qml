// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Layouts
import "../config"
import "../components"

// sol bar içeriği — arka planı çerçeve çiziyor
Item {
    id: bar
    required property var appPanel
    readonly property Item netButton: netBtn

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        spacing: 8

        OsLogo { Layout.alignment: Qt.AlignHCenter }
        Divider {}
        Workspaces { Layout.alignment: Qt.AlignHCenter }

        Apps {
            id: apps
            Layout.fillHeight: true
            Layout.fillWidth: true
            popup: bar.appPanel
        }

        Divider {}
        BarClock { Layout.alignment: Qt.AlignHCenter }
        NetButton { id: netBtn; Layout.alignment: Qt.AlignHCenter }
        PowerButton { Layout.alignment: Qt.AlignHCenter }
    }

    component Divider: Rectangle {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 24
        implicitHeight: 2
        radius: 1
        color: Theme.surface3
    }
}
