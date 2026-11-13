// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import "../config"
import "../components"
import "../services"

// açık programlar — saatin hemen üstünde, alttan yukarı dizilir
ListView {
    id: list
    required property var popup

    verticalLayoutDirection: ListView.BottomToTop
    spacing: 4
    clip: true
    interactive: contentHeight > height
    boundsBehavior: Flickable.StopAtBounds

    function appIdOf(t) {
        if (t.wayland && t.wayland.appId) return t.wayland.appId
        if (t.lastIpcObject && t.lastIpcObject.class) return t.lastIpcObject.class
        return "?"
    }
    function iconFor(appId) {
        const e = DesktopEntries.heuristicLookup(appId)
        return Quickshell.iconPath(e && e.icon ? e.icon : appId.toLowerCase(), "application-x-executable")
    }
    function nameFor(appId) {
        const e = DesktopEntries.heuristicLookup(appId)
        return e && e.name ? e.name : appId
    }

    readonly property var groups: {
        const map = {}, out = []
        const ts = Hyprland.toplevels.values
        for (let i = 0; i < ts.length; i++) {
            const id = appIdOf(ts[i])
            if (!map[id]) { map[id] = { appId: id, wins: [] }; out.push(map[id]) }
            map[id].wins.push(ts[i])
        }
        return out
    }

    model: groups

    delegate: Item {
        id: d
        required property var modelData
        required property int index
        readonly property bool focused: modelData.wins.some(w => w.activated)
        width: list.width
        height: 42

        Rectangle {
            anchors.centerIn: parent
            width: 40; height: 40; radius: 14
            color: ma.containsMouse ? Theme.surface3 : (d.focused ? Theme.surface2 : "transparent")
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // odaktaki pencere: soldaki pembe çizgi
        Rectangle {
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: d.focused ? 20 : 0
            radius: 2
            color: Theme.pink
            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
        }

        IconImage {
            anchors.centerIn: parent
            implicitSize: 26
            source: list.iconFor(d.modelData.appId)
            scale: ma.containsMouse ? 1.15 : 1
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
        }

        // birden fazla pencere: noktalar
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 2
            visible: d.modelData.wins.length > 1
            Repeater {
                model: Math.min(3, d.modelData.wins.length)
                Rectangle { width: 3; height: 3; radius: 1.5; color: Theme.purple }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                const p = d.mapToItem(null, 0, d.height / 2)
                list.popup.showFor(d.modelData, list.nameFor(d.modelData.appId), list.iconFor(d.modelData.appId), p.y)
            }
            onExited: list.popup.leaveIcon()
            onClicked: e => {
                const wins = d.modelData.wins
                if (e.button === Qt.MiddleButton) { HyprState.closeWin(wins[0].address); return }
                // tıklayınca sıradaki pencereye odaklan
                let i = wins.findIndex(w => w.activated)
                HyprState.focusWin(wins[(i + 1) % wins.length].address)
            }
        }
    }
}
