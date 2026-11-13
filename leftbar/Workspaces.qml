// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Effects
import Quickshell.Hyprland
import "../config"
import "../components"
import "../services"

// 5 workspace — bulunduğun yeri maskot gösterir.
// special workspace açıkken her şey bulanıklaşır, üstte special maskotu çıkar.
Item {
    id: root
    readonly property int count: 5
    readonly property int slot: 38
    readonly property int activeId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property bool inSpecial: HyprState.special !== ""

    implicitWidth: 44
    implicitHeight: count * slot + 8

    function occupied(id) {
        const ws = Hyprland.workspaces.values
        for (let i = 0; i < ws.length; i++)
            if (ws[i].id === id) return ws[i].toplevels.values.length > 0
        return false
    }

    Item {
        id: content
        anchors.fill: parent

        property real blurAmount: root.inSpecial ? 1 : 0
        Behavior on blurAmount { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        layer.enabled: blurAmount > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: content.blurAmount
            blurMax: 20
            saturation: -0.4 * content.blurAmount
        }

        Rectangle {
            anchors.fill: parent
            radius: 22
            color: Theme.surface
        }

        Column {
            y: 4
            anchors.horizontalCenter: parent.horizontalCenter
            Repeater {
                model: root.count
                delegate: Item {
                    id: cell
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property bool isActive: root.activeId === wsId
                    readonly property bool filled: root.occupied(wsId)
                    width: 44
                    height: root.slot

                    Txt {
                        anchors.centerIn: parent
                        text: cell.wsId
                        mono: true
                        size: hover.containsMouse ? 15 : 13
                        opacity: cell.isActive ? 0 : 1
                        color: cell.filled ? Theme.lavender : Theme.muted
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Behavior on size { NumberAnimation { duration: 150 } }
                    }
                    Rectangle {
                        visible: cell.filled && !cell.isActive
                        width: 4; height: 4; radius: 2
                        color: Theme.pink
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 5
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: HyprState.focusWs(cell.wsId)
                    }
                }
            }
        }

        // aktif workspace: maskot
        Item {
            id: indicator
            width: 40; height: 40
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.activeId >= 1 && root.activeId <= root.count
            y: 4 + (Math.min(root.activeId, root.count) - 1) * root.slot + (root.slot - height) / 2
            Behavior on y { SpringAnimation { spring: 4; damping: 0.32; mass: 0.8 } }

            Rectangle {
                anchors.centerIn: parent
                width: 36; height: 36; radius: 18
                color: Qt.alpha(Theme.pink, 0.14)
                border.width: 1.5
                border.color: Qt.alpha(Theme.pink, 0.5)
            }
            Mascot {
                id: cat
                anchors.centerIn: parent
                width: 32; height: 32
                kind: "workspace"
            }
            // workspace değişince küçük zıplama
            SequentialAnimation {
                id: hop
                NumberAnimation { target: cat; property: "scale"; to: 1.25; duration: 120; easing.type: Easing.OutQuad }
                NumberAnimation { target: cat; property: "scale"; to: 1.0; duration: 380; easing.type: Easing.OutElastic }
            }
            Connections {
                target: root
                function onActiveIdChanged() { hop.restart() }
            }
        }

        WheelHandler {
            onWheel: e => HyprState.focusWsRel(e.angleDelta.y > 0 ? -1 : 1)
        }
    }

    // special workspace katmanı
    Item {
        id: specialLayer
        anchors.fill: parent
        opacity: root.inSpecial ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        Mascot {
            id: scat
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -8
            width: 40; height: 40
            kind: "special"
            SequentialAnimation on anchors.verticalCenterOffset {
                running: specialLayer.visible
                loops: Animation.Infinite
                NumberAnimation { to: -14; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: -8;  duration: 900; easing.type: Easing.InOutSine }
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: scat.bottom
            anchors.topMargin: 8
            width: specialName.implicitWidth + 10
            height: 16
            radius: 8
            color: Theme.purple
            Txt {
                id: specialName
                anchors.centerIn: parent
                text: HyprState.special
                size: 9
                color: Theme.bg
                font.weight: Font.Black
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: specialLayer.visible
            cursorShape: Qt.PointingHandCursor
            onClicked: HyprState.toggleSpecial(HyprState.special)
        }
    }
}
