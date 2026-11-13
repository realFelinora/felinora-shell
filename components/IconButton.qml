// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Effects
import "../config"

Rectangle {
    id: b
    property string icon
    property real size: 16
    property color fg: Theme.pink
    property color hoverBg: Theme.surface3
    property bool active: false
    property string tip: ""
    readonly property bool hovered: ma.containsMouse
    signal clicked()
    signal rightClicked()

    implicitWidth: 34
    implicitHeight: 34
    radius: height / 2
    color: ma.containsMouse ? hoverBg : "transparent"
    Behavior on color { ColorAnimation { duration: 140 } }

    // aktif buton: vurgu degradesi + yumuşak ışıltı
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: b.active
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(b.fg, ma.containsMouse ? 1.12 : 1.0) }
            GradientStop { position: 1; color: Qt.colorEqual(b.fg, Theme.pink) ? Theme.purple : Qt.darker(b.fg, 1.25) }
        }
        layer.enabled: b.active
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.pink
            shadowBlur: 0.7
            shadowOpacity: ma.containsMouse ? 0.75 : 0.45
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 2
        }
    }
    scale: ma.pressed ? 0.88 : 1
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

    Icon {
        anchors.centerIn: parent
        text: b.icon
        size: b.size
        color: b.active ? Theme.bg : b.fg
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => e.button === Qt.RightButton ? b.rightClicked() : b.clicked()
    }
}
