// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../config"
import "../components"
import "../services"

// sağ kenardan çıkan çıkış menüsü: uyku · kapat · [dönen maskot] · yeniden başlat · çıkış
Item {
    id: root
    implicitWidth: 136
    implicitHeight: col.implicitHeight + 36

    function run(cmd) {
        Ui.sessionOpen = false
        if (cmd === "logout") HyprState.exit()
        else if (cmd === "lock") Ui.lock()
        else if (cmd === "suspend") {
            // önce kilitle, uyanınca kilit ekranı karşılasın
            Ui.lock()
            Quickshell.execDetached(["sh", "-c", "sleep 0.8; systemctl suspend"])
        }
        else Quickshell.execDetached(cmd)
    }
    function key(k) {
        if (k === Qt.Key_L) run("lock")
        else if (k === Qt.Key_1) run("suspend")
        else if (k === Qt.Key_2) run(["systemctl", "poweroff"])
        else if (k === Qt.Key_3) run(["systemctl", "reboot"])
        else if (k === Qt.Key_4) run("logout")
    }

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 10

        // kilitle — 2 + maskot + 2 düzeni bozulmasın diye üstte ayrı, geniş hap
        Rectangle {
            id: lockBtn
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 96
            implicitHeight: 40
            radius: 20
            color: lm.containsMouse ? Theme.pink : Theme.surface
            border.width: 1
            border.color: Qt.alpha(Theme.pink, 0.45)
            scale: lm.pressed ? 0.92 : (lm.containsMouse ? 1.05 : 1)
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

            opacity: 0
            transform: Translate { id: lockSlide; x: 46 }
            Connections {
                target: Ui
                function onSessionOpenChanged() {
                    if (Ui.sessionOpen) { lockLeave.stop(); lockEnter.restart() }
                    else { lockEnter.stop(); lockLeave.restart() }
                }
            }
            SequentialAnimation {
                id: lockEnter
                PropertyAction { target: lockSlide; property: "x"; value: 46 }
                PropertyAction { target: lockBtn; property: "opacity"; value: 0 }
                PauseAnimation { duration: 60 }
                ParallelAnimation {
                    NumberAnimation { target: lockBtn; property: "opacity"; to: 1; duration: 240 }
                    NumberAnimation { target: lockSlide; property: "x"; to: 0; duration: 460; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial }
                }
            }
            NumberAnimation { id: lockLeave; target: lockBtn; property: "opacity"; to: 0; duration: 110 }

            Row {
                anchors.centerIn: parent
                spacing: 6
                Icon { text: Theme.lock; size: 16; color: lm.containsMouse ? Theme.bg : Theme.pink; anchors.verticalCenter: parent.verticalCenter }
                Txt { text: "kilitle"; size: 12; font.weight: Font.Bold; color: lm.containsMouse ? Theme.bg : Theme.text; anchors.verticalCenter: parent.verticalCenter }
            }
            Txt {
                anchors.right: parent.right; anchors.rightMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                text: "L"; size: 9; mono: true
                color: lm.containsMouse ? Theme.bg : Theme.muted
            }
            MouseArea { id: lm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.run("lock") }
        }

        SessionButton { order: 1; icon: Theme.sleep;   label: "uyku";    hint: "1"; tint: Theme.lavender; onActivated: root.run("suspend") }
        SessionButton { order: 2; icon: Theme.power;   label: "kapat";   hint: "2"; tint: Theme.red;      onActivated: root.run(["systemctl", "poweroff"]) }

        // dönen maskot
        Item {
            id: spinBox
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 100
            implicitHeight: 108
            scale: 0
            opacity: 0
            Connections {
                target: Ui
                function onSessionOpenChanged() {
                    if (Ui.sessionOpen) { spinOut.stop(); spinIn.restart() }
                    else { spinIn.stop(); spinOut.restart() }
                }
            }
            SequentialAnimation {
                id: spinIn
                PropertyAction { target: spinBox; property: "scale"; value: 0.4 }
                PauseAnimation { duration: 200 }
                ParallelAnimation {
                    NumberAnimation { target: spinBox; property: "opacity"; to: 1; duration: 220 }
                    NumberAnimation { target: spinBox; property: "scale"; to: 1; duration: 560; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial }
                }
            }
            NumberAnimation { id: spinOut; target: spinBox; property: "opacity"; to: 0; duration: 120 }
            Rectangle {
                anchors.centerIn: parent
                width: 96; height: 96; radius: 48
                color: "transparent"
                border.width: 2
                border.color: Theme.surface3
                Repeater {
                    model: 8
                    Rectangle {
                        required property int index
                        width: 5; height: 5; radius: 2.5
                        color: index % 2 ? Theme.purple : Theme.pink
                        x: 48 + 48 * Math.cos(index * Math.PI / 4) - 2.5
                        y: 48 + 48 * Math.sin(index * Math.PI / 4) - 2.5
                    }
                }
                RotationAnimation on rotation {
                    running: Ui.sessionOpen
                    from: 360; to: 0; duration: 9000
                    loops: Animation.Infinite
                }
            }
            Mascot {
                anchors.centerIn: parent
                width: 80; height: 80
                kind: "spin"
                RotationAnimation on rotation {
                    running: Ui.sessionOpen
                    from: 0; to: 360; duration: 4000
                    loops: Animation.Infinite
                }
            }
        }

        SessionButton { order: 4; icon: Theme.restart; label: "yeniden"; hint: "3"; tint: Theme.pink;   onActivated: root.run(["systemctl", "reboot"]) }
        SessionButton { order: 5; icon: Theme.logout;  label: "çıkış";   hint: "4"; tint: Theme.purple; onActivated: root.run("logout") }
    }

    component SessionButton: Rectangle {
        id: sb
        property int order: 0
        property string icon
        property string label
        property string hint
        property color tint: Theme.pink
        signal activated()

        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 96
        implicitHeight: 80
        radius: 24
        color: sm.containsMouse ? sb.tint : Theme.surface
        scale: sm.pressed ? 0.92 : (sm.containsMouse ? 1.05 : 1)
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

        // menü açılınca sırayla sağdan kayarak gelir
        opacity: 0
        transform: Translate { id: slide; x: 46 }
        Connections {
            target: Ui
            function onSessionOpenChanged() {
                if (Ui.sessionOpen) { leave.stop(); enter.restart() }
                else { enter.stop(); leave.restart() }
            }
        }
        SequentialAnimation {
            id: enter
            PropertyAction { target: slide; property: "x"; value: 46 }
            PropertyAction { target: sb; property: "opacity"; value: 0 }
            PauseAnimation { duration: 90 + sb.order * 50 }
            ParallelAnimation {
                NumberAnimation { target: sb; property: "opacity"; to: 1; duration: 240 }
                NumberAnimation { target: slide; property: "x"; to: 0; duration: 460; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial }
            }
        }
        NumberAnimation { id: leave; target: sb; property: "opacity"; to: 0; duration: 110 }

        Column {
            anchors.centerIn: parent
            spacing: 4
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: sb.icon
                size: 26
                color: sm.containsMouse ? Theme.bg : sb.tint
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: sb.label
                size: 12
                font.weight: Font.Bold
                color: sm.containsMouse ? Theme.bg : Theme.text
            }
        }
        Txt {
            anchors.top: parent.top; anchors.right: parent.right
            anchors.margins: 8
            text: sb.hint
            size: 9
            mono: true
            color: sm.containsMouse ? Theme.bg : Theme.muted
        }
        MouseArea {
            id: sm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sb.activated()
        }
    }
}
