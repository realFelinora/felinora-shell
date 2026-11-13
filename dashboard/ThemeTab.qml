// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../config"
import "../components"
import "../services"

// tema seçici — her kart kendi renkleriyle küçük bir masaüstü önizlemesi çizer
Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Icon { text: Theme.palette; size: 20 }
            Txt { text: "Temalar"; size: 18; font.weight: Font.Black }
            Txt { text: "· şu an: " + Theme.current.name; size: 13; color: Theme.subtext }
            Item { Layout.fillWidth: true }

            // otomatik kilit süresi
            Icon { text: Theme.lock; size: 15; color: Theme.purple }
            Txt { text: "otomatik kilit"; size: 12; color: Theme.subtext; rightPadding: 4 }
            Repeater {
                model: [5, 10, 15, 30, 0]
                delegate: Rectangle {
                    id: chip
                    required property int modelData
                    readonly property bool sel: Prefs.lockMinutes === modelData
                    implicitWidth: chipTxt.implicitWidth + 18
                    implicitHeight: 26
                    radius: 13
                    color: sel ? Theme.pink : (chipMa.containsMouse ? Theme.surface3 : Theme.surface2)
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Txt {
                        id: chipTxt
                        anchors.centerIn: parent
                        text: chip.modelData === 0 ? "kapalı" : chip.modelData + " dk"
                        size: 11
                        font.weight: Font.Bold
                        color: chip.sel ? Theme.bg : Theme.subtext
                    }
                    MouseArea { id: chipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Prefs.lockMinutes = chip.modelData }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 4
            rowSpacing: 12
            columnSpacing: 12

            Repeater {
                model: Theme.baseThemes
                delegate: ThemeCard {
                    required property var modelData
                    t: modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
            // 2. satırın 4.'sü: şarkıya göre değişen tema (kart şarkı değişince yeniden oluşmasın diye ayrı)
            ThemeCard {
                t: SongColors.theme
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    component ThemeCard: Rectangle {
        id: card
        property var t
        readonly property bool sel: Theme.current.id === t.id

        radius: 20
        color: t.surface
        border.width: sel ? 2 : 1
        border.color: sel ? t.accent : (cm.containsMouse ? Qt.alpha(t.accent, 0.5) : t.border)
        scale: cm.pressed ? 0.97 : (cm.containsMouse ? 1.02 : 1)
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        layer.enabled: sel
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: card.t.accent
            shadowBlur: 0.8
            shadowOpacity: 0.45
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ---- mini masaüstü önizlemesi ----
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: card.t.frame
                clip: true

                // sol mini bar
                Column {
                    x: 6; y: 8
                    spacing: 5
                    Rectangle { width: 10; height: 10; radius: 3; color: "transparent"; border.width: 1.5; border.color: card.t.accent }
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            width: 10; height: index === 1 ? 14 : 6; radius: 3
                            color: index === 1 ? card.t.accent : card.t.surface3
                        }
                    }
                }

                // iç alan (pencere boşluğu)
                Rectangle {
                    x: 22; y: 6
                    width: parent.width - 28
                    height: parent.height - 12
                    radius: 8
                    color: card.t.bg

                    // aşağı inen mini panel
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -4
                        width: parent.width * 0.7
                        height: parent.height * 0.72
                        radius: 8
                        color: card.t.frame
                        border.width: 1
                        border.color: card.t.border

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 10
                            width: parent.width * 0.55; height: 9; radius: 4.5
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: card.t.accent }
                                GradientStop { position: 1; color: card.t.accent2 }
                            }
                        }
                        Row {
                            x: 10; y: 28
                            spacing: 6
                            Rectangle {
                                width: 26; height: 26; radius: 13
                                color: "transparent"
                                border.width: 3
                                border.color: card.t.accent
                                Image {
                                    visible: !!card.t.art
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    source: card.t.art || ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    layer.enabled: true
                                    layer.effect: MultiEffect { maskEnabled: true; maskSource: artMask }
                                }
                                Rectangle { id: artMask; visible: false; layer.enabled: true; anchors.fill: parent; anchors.margins: 3; radius: width / 2 }
                            }
                            Column {
                                spacing: 4
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle { width: 46; height: 5; radius: 2.5; color: card.t.text }
                                Rectangle { width: 34; height: 4; radius: 2; color: card.t.subtext }
                                Rectangle { width: 40; height: 4; radius: 2; color: card.t.accent2 }
                            }
                        }
                    }
                }

                Icon {
                    visible: card.sel
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6
                    text: Theme.checkCircle
                    size: 18
                    color: card.t.accent
                }
            }

            // ---- ad + renkler ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    Txt { text: card.t.name; size: 14; font.weight: Font.Black; color: card.t.text }
                    Txt { text: card.t.desc; size: 10; color: card.t.subtext }
                }
                Repeater {
                    model: [card.t.accent, card.t.accent2, card.t.tint, card.t.accentSoft]
                    Rectangle {
                        required property var modelData
                        width: 14; height: 14; radius: 7
                        color: modelData
                        border.width: 1
                        border.color: Qt.alpha("white", 0.12)
                    }
                }
            }
        }

        MouseArea {
            id: cm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Prefs.theme = card.t.id
        }
    }
}
