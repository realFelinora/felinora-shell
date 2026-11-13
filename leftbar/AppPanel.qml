// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "../config"
import "../components"
import "../services"

// program ikonunun üstüne gelince: canlı önizleme + pencere ayarları (bardan çıkan panel)
Item {
    id: pop

    property var group: null
    property string appName: ""
    property string appIcon: ""
    property real targetY: 0
    property bool shown: false
    property bool overIcon: false
    property bool overPanel: false
    readonly property bool open: shown && group !== null

    implicitWidth: 320
    implicitHeight: col.implicitHeight + 28

    function showFor(g, name, icon, y) {
        group = g; appName = name; appIcon = icon; targetY = y
        overIcon = true
        shown = true
        hideTimer.stop()
    }
    function leaveIcon() { overIcon = false; hideTimer.restart() }

    onOverPanelChanged: if (!overPanel) hideTimer.restart()
    Timer {
        id: hideTimer
        interval: 260
        onTriggered: if (!pop.overIcon && !pop.overPanel) pop.shown = false
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            spacing: 10
            IconImage { implicitSize: 24; source: pop.appIcon }
            Txt {
                Layout.fillWidth: true
                text: pop.appName
                size: 15
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Rectangle {
                visible: pop.group && pop.group.wins.length > 1
                implicitWidth: cnt.implicitWidth + 12; implicitHeight: 20; radius: 10
                color: Theme.purple
                Txt { id: cnt; anchors.centerIn: parent; text: pop.group ? pop.group.wins.length + " pencere" : ""; size: 10; color: Theme.bg }
            }
        }

        Repeater {
            model: pop.group ? pop.group.wins.slice(0, 3) : []
            delegate: WindowCard { required property var modelData; win: modelData; Layout.fillWidth: true }
        }
    }

    component WindowCard: Rectangle {
        id: card
        property var win
        implicitHeight: wc.implicitHeight + 16
        radius: 14
        color: Theme.surface
        border.width: 1
        border.color: win && win.activated ? Theme.pink : Theme.border

        ColumnLayout {
            id: wc
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            RowLayout {
                spacing: 6
                Txt {
                    Layout.fillWidth: true
                    text: card.win ? card.win.title : ""
                    size: 11
                    color: Theme.subtext
                    elide: Text.ElideRight
                }
                Rectangle {
                    implicitWidth: wsl.implicitWidth + 10; implicitHeight: 16; radius: 8
                    color: Theme.surface3
                    Txt {
                        id: wsl
                        anchors.centerIn: parent
                        size: 9
                        color: Theme.lavender
                        text: card.win && card.win.workspace ? "ws " + card.win.workspace.name.replace("special:", "★ ") : ""
                    }
                }
            }

            // canlı önizleme
            ClippingRectangle {
                id: shotBox
                Layout.fillWidth: true
                Layout.preferredHeight: shot.hasContent && shot.sourceSize.width > 0
                    ? Math.min(180, width * shot.sourceSize.height / shot.sourceSize.width) : 150
                radius: 10
                color: Theme.surface2

                // canlı yakalama pahalı: ikonun üstünden hızlıca geçerken başlama,
                // açıkken saniyede bir yenile
                property bool ready: false
                Timer { interval: 160; running: pop.open; onTriggered: shotBox.ready = true }
                ScreencopyView {
                    id: shot
                    anchors.fill: parent
                    captureSource: shotBox.ready && pop.open && card.win ? card.win.wayland : null
                    live: false
                }
                Timer {
                    interval: 1000
                    repeat: true
                    running: pop.open && shotBox.ready
                    onTriggered: shot.captureFrame()
                }
                Txt {
                    anchors.centerIn: parent
                    visible: !shot.hasContent
                    text: "önizleme yükleniyor... (=･ω･=)"
                    size: 11
                    color: Theme.muted
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { HyprState.focusWin(card.win.address); pop.shown = false }
                }
            }

            // ayarlar
            RowLayout {
                spacing: 2
                IconButton { icon: Theme.eye;        size: 15; implicitWidth: 30; implicitHeight: 30; onClicked: { HyprState.focusWin(card.win.address); pop.shown = false } }
                IconButton { icon: Theme.floating;   size: 15; implicitWidth: 30; implicitHeight: 30; fg: Theme.lavender; onClicked: HyprState.floatWin(card.win.address) }
                IconButton { icon: Theme.fullscreen; size: 15; implicitWidth: 30; implicitHeight: 30; fg: Theme.lavender; onClicked: HyprState.fullscreenWin(card.win.address) }
                IconButton { icon: Theme.pin;        size: 15; implicitWidth: 30; implicitHeight: 30; fg: Theme.lavender; onClicked: HyprState.pinWin(card.win.address) }
                Item { Layout.fillWidth: true }
                IconButton { icon: Theme.close;      size: 15; implicitWidth: 30; implicitHeight: 30; fg: Theme.red; onClicked: HyprState.closeWin(card.win.address) }
            }

            // workspace'e taşı
            RowLayout {
                spacing: 4
                Txt { text: "taşı"; size: 10; color: Theme.muted }
                Repeater {
                    model: ["1", "2", "3", "4", "5", "★"]
                    delegate: Rectangle {
                        required property string modelData
                        implicitWidth: 26; implicitHeight: 22; radius: 8
                        color: mm.containsMouse ? Theme.pink : Theme.surface2
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Txt {
                            anchors.centerIn: parent
                            text: modelData
                            size: 11; mono: true
                            color: mm.containsMouse ? Theme.bg : Theme.lavender
                        }
                        MouseArea {
                            id: mm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: HyprState.moveWin(card.win.address, modelData === "★" ? "special:magic" : Number(modelData))
                        }
                    }
                }
            }
        }
    }
}
