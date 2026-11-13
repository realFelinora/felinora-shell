// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Effects
import "../config"
import "../components"

// sekme çubuğu — kayan pembe pati göstergesi
Rectangle {
    id: root
    readonly property var items: [
        { icon: Theme.dashboard, label: "Dashboard" },
        { icon: Theme.music, label: "Media" },
        { icon: Theme.chart, label: "Performance" },
        { icon: Theme.cloud, label: "Weather" },
        { icon: Theme.palette, label: "Tema" }
    ]
    readonly property int tabW: 140

    implicitWidth: tabW * items.length + 8
    implicitHeight: 40
    radius: 20
    color: Theme.surface
    border.width: 1
    border.color: Theme.border

    // lastik gibi esneyen gösterge: gidilen yöndeki kenar önden koşar, arkadaki sonra yetişir
    property int prevTab: Ui.dashTab
    property bool movingRight: true
    property real leftEdge: 4 + Ui.dashTab * tabW
    property real rightEdge: 4 + (Ui.dashTab + 1) * tabW
    Connections {
        target: Ui
        // önce yönü belirle, sonra kenarları taşı — animasyon süreleri doğru yöne göre seçilsin
        function onDashTabChanged() {
            root.movingRight = Ui.dashTab > root.prevTab
            root.prevTab = Ui.dashTab
            root.leftEdge = 4 + Ui.dashTab * root.tabW
            root.rightEdge = 4 + (Ui.dashTab + 1) * root.tabW
        }
    }
    Behavior on leftEdge {
        NumberAnimation {
            duration: root.movingRight ? 520 : 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.movingRight ? Theme.curveStandard : Theme.curveSpatial
        }
    }
    Behavior on rightEdge {
        NumberAnimation {
            duration: root.movingRight ? 300 : 520
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.movingRight ? Theme.curveSpatial : Theme.curveStandard
        }
    }

    Rectangle {
        id: indicator
        y: 4
        x: root.leftEdge
        width: root.rightEdge - root.leftEdge
        height: parent.height - 8
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.pink }
            GradientStop { position: 1; color: Theme.purple }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.pink
            shadowBlur: 0.8
            shadowOpacity: 0.55
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }

    Row {
        x: 4; y: 4
        Repeater {
            model: root.items
            delegate: Item {
                required property var modelData
                required property int index
                readonly property bool sel: Ui.dashTab === index
                width: root.tabW
                height: root.height - 8
                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.parent.sel ? Theme.paw : modelData.icon
                        size: 15
                        color: parent.parent.sel ? Theme.bg : (tm.containsMouse ? Theme.pink : Theme.subtext)
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        size: 13
                        font.weight: Font.Bold
                        color: parent.parent.sel ? Theme.bg : (tm.containsMouse ? Theme.text : Theme.subtext)
                    }
                }
                MouseArea {
                    id: tm
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Ui.dashTab = index
                }
            }
        }
    }
}
