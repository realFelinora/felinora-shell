// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland
import "../config"
import "../components"
import "../services"

// ┌hava─┐┌──profil──┐┌medya┐
// ├saat─┤├──takvim─┤│     │
// └─────┘└─────────┘└─────┘
Item {
    id: root

    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property int h12: clock.hours % 12 === 0 ? 12 : clock.hours % 12
    function pad(n) { return n < 10 ? "0" + n : "" + n }

    property string host: ""
    property string kernel: ""
    Process {
        running: true
        command: ["sh", "-c", "uname -n; uname -r"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.trim().split("\n")
                root.host = l[0] || ""
                root.kernel = l[1] || ""
            }
        }
    }

    readonly property string greeting: {
        const h = clock.hours
        if (h < 6) return "uyuman lazım~ (=ᵕ ᵕ=)zzZ"
        if (h < 12) return "günaydın kedicik~ (=^･ω･^=)"
        if (h < 18) return "iyi günler, mırr~ ฅ^•ﻌ•^ฅ"
        return "iyi akşamlar~ (=^‿^=)"
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // ---------- sol sütun: hava + saat ----------
        ColumnLayout {
            Layout.preferredWidth: 210
            Layout.maximumWidth: 210
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 12

            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Ui.dashTab = 3 }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 2
                    RowLayout {
                        Icon {
                            text: Weather.current ? Weather.icon(Weather.current.code, Weather.current.isDay) : Theme.cloud
                            size: 40
                            color: Theme.pink
                        }
                        Item { Layout.fillWidth: true }
                        Txt {
                            text: Weather.current ? Math.round(Weather.current.temp) + "°C" : "--°"
                            size: 34
                            font.weight: Font.Black
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Txt { text: Weather.current ? Weather.desc(Weather.current.code) : "hava yükleniyor..."; size: 15; color: Theme.pink; font.weight: Font.Bold }
                    Txt { text: Weather.current ? "hissedilen " + Math.round(Weather.current.feels) + "°C" : ""; size: 12; color: Theme.subtext }
                    RowLayout {
                        spacing: 4
                        Icon { text: Theme.mapPin; size: 12; color: Theme.purple }
                        Txt { text: Weather.city || "..."; size: 12; color: Theme.subtext }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        Txt { text: root.pad(root.h12); mono: true; size: 54; font.weight: Font.Bold; color: Theme.pink }
                        Txt { text: ":"; mono: true; size: 54; font.weight: Font.Bold; color: Theme.purple; opacity: clock.seconds % 2 ? 0.3 : 1 }
                        Txt { text: root.pad(clock.minutes); mono: true; size: 54; font.weight: Font.Bold }
                    }
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 64; implicitHeight: 26; radius: 13
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.pink }
                            GradientStop { position: 1; color: Theme.purple }
                        }
                        Txt { anchors.centerIn: parent; text: clock.hours < 12 ? "AM" : "PM"; size: 14; font.weight: Font.Black; color: Theme.bg }
                    }
                    Item { implicitHeight: 6 }
                    // saniye çubuğu
                    Bar {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 150
                        implicitHeight: 6
                        value: clock.seconds / 59
                    }
                    Txt {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.greeting
                        size: 11
                        color: Theme.subtext
                    }
                }
            }
        }

        // ---------- orta sütun: profil + takvim ----------
        ColumnLayout {
            Layout.preferredWidth: 476
            Layout.maximumWidth: 476
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 12

            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 180

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 22

                    // profil resmi — tıkla: dosya seçici
                    Item {
                        implicitWidth: 136
                        implicitHeight: 136

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            gradient: Gradient {
                                GradientStop { position: 0; color: Theme.pink }
                                GradientStop { position: 1; color: Theme.purpleDeep }
                            }
                            RotationAnimation on rotation { from: 0; to: 360; duration: 8000; loops: Animation.Infinite; running: Ui.dashboardOpen }
                        }
                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: width / 2
                            color: Theme.surface2
                            Image {
                                anchors.fill: parent
                                source: Prefs.profile ? "file://" + Prefs.profile : ""
                                visible: Prefs.profile !== ""
                                sourceSize: Qt.size(256, 256)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }
                            Mascot { anchors.fill: parent; kind: "avatar"; crop: true; visible: Prefs.profile === "" }
                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(0, 0, 0, 0.55)
                                opacity: pfm.containsMouse ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                                Column {
                                    anchors.centerIn: parent
                                    Icon { anchors.horizontalCenter: parent.horizontalCenter; text: Theme.folderImg; size: 24 }
                                    Txt { text: "değiştir"; size: 11 }
                                }
                            }
                        }
                        MouseArea {
                            id: pfm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Ui.openPicker("profile")
                        }
                        // uptime — sağ alt
                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: -14
                            anchors.bottomMargin: 2
                            implicitWidth: upRow.implicitWidth + 16
                            implicitHeight: 26
                            radius: 13
                            color: Theme.bg
                            border.width: 1.5
                            border.color: Theme.pink
                            Row {
                                id: upRow
                                anchors.centerIn: parent
                                spacing: 4
                                Icon { text: Theme.clock; size: 12; anchors.verticalCenter: parent.verticalCenter }
                                Txt { text: SysInfo.duration(SysInfo.uptime); size: 11; mono: true; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Txt { text: Quickshell.env("USER"); size: 26; font.weight: Font.Black }
                        Txt { text: "@" + root.host; size: 13; color: Theme.purple }
                        Item { implicitHeight: 6 }
                        Txt { text: root.greeting; size: 13; color: Theme.pink }
                        Item { implicitHeight: 4 }
                        InfoLine { icon: Theme.osIcon(SysInfo.osId); label: SysInfo.osName + " · " + root.kernel }
                        InfoLine { icon: Theme.desktop; label: "Hyprland · " + Hyprland.toplevels.values.length + " pencere" }
                        InfoLine { icon: Theme.clock; label: "açık: " + SysInfo.duration(SysInfo.uptime) }
                    }
                }
            }

            Calendar {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }

        // ---------- sağ sütun: medya ----------
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                anchors.topMargin: 26
                spacing: 8

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 200
                    implicitHeight: 200
                    CatEars { earSize: 30; inset: 18; fill: Theme.surface2 }
                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 22
                        color: Theme.surface2
                        border.width: 2
                        border.color: Theme.pink
                        Image {
                            anchors.fill: parent
                            source: Player.art
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: Player.art !== ""
                        }
                        Mascot {
                            anchors.centerIn: parent
                            width: 120; height: 100
                            visible: Player.art === ""
                            kind: "sleep"
                        }
                    }
                }

                Item { implicitHeight: 4 }
                Txt {
                    Layout.fillWidth: true
                    text: Player.active ? Player.title : "şu an bir şey çalmıyor"
                    size: 16
                    font.weight: Font.Black
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }
                Txt {
                    Layout.fillWidth: true
                    text: Player.active ? (Player.artist || Player.identity) : "zzz... (=ᵕ ᵕ=)"
                    size: 13
                    color: Theme.pink
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
                Item { Layout.fillHeight: true }
                Bar {
                    Layout.fillWidth: true
                    implicitHeight: 5
                    visible: Player.length > 0
                    value: Player.length > 0 ? Player.position / Player.length : 0
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10
                    IconButton { icon: Theme.prev; size: 20; implicitWidth: 42; implicitHeight: 42; fg: Theme.lavender; onClicked: Player.prev() }
                    IconButton { icon: Player.playing ? Theme.pause : Theme.play; size: 24; implicitWidth: 54; implicitHeight: 54; active: true; onClicked: Player.toggle() }
                    IconButton { icon: Theme.next; size: 20; implicitWidth: 42; implicitHeight: 42; fg: Theme.lavender; onClicked: Player.next() }
                }
            }
        }
    }

    component InfoLine: Row {
        property string icon
        property string label
        spacing: 8
        Icon { text: parent.icon; size: 13; color: Theme.purple; anchors.verticalCenter: parent.verticalCenter }
        Txt { text: parent.label; size: 12; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
    }
}
