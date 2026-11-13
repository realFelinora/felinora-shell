// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../config"
import "../components"
import "../services"

// internet paneli (bardan çıkan panel)
Item {
    id: pop
    implicitWidth: 340
    implicitHeight: col.implicitHeight + 32

    Connections {
        target: Ui
        function onNetOpenChanged() { if (Ui.netOpen) { Network.refresh(); Network.scan() } }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // başlık
        RowLayout {
            spacing: 12
            Rectangle {
                implicitWidth: 52; implicitHeight: 52; radius: 26
                gradient: Gradient {
                    GradientStop { position: 0; color: Network.online ? Theme.pink : Theme.surface3 }
                    GradientStop { position: 1; color: Network.online ? Theme.purpleDeep : Theme.surface2 }
                }
                Icon { anchors.centerIn: parent; text: Network.icon; size: 24; color: Network.online ? Theme.bg : Theme.subtext }
                RotationAnimation on rotation {
                    running: Network.online && Ui.netOpen
                    from: -6; to: 6; duration: 1400
                    loops: Animation.Infinite
                    easing.type: Easing.InOutSine
                }
            }
            ColumnLayout {
                spacing: 2
                Txt {
                    text: Network.online ? "bağlısın~ (=^･ω･^=)" : Network.type !== "none" ? "bağlı ama internet yok (=･ω･=)?" : "internet yok (=；ω；=)"
                    size: 15; font.weight: Font.Bold
                }
                Txt {
                    text: Network.methodLabel + (Network.type === "wifi" ? " · " + Network.ssid : "")
                    size: 12; color: Theme.pink
                }
                Txt {
                    visible: Network.connection !== ""
                    text: Network.connection + " · " + Network.device
                    size: 11; color: Theme.subtext
                }
            }
        }

        // canlı hız grafiği
        Card {
            Layout.fillWidth: true
            implicitHeight: 104
            Spark {
                anchors.fill: parent
                anchors.margins: 1
                anchors.topMargin: 40
                values: SysInfo.rxHist
                lineColor: Theme.pink
            }
            Spark {
                anchors.fill: parent
                anchors.margins: 1
                anchors.topMargin: 40
                values: SysInfo.txHist
                lineColor: Theme.purple
                maxValue: Math.max.apply(null, SysInfo.rxHist.concat([1]))
            }
            RowLayout {
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 12
                Icon { text: Theme.down; size: 14; color: Theme.pink }
                Txt { text: SysInfo.rate(SysInfo.rxRate); mono: true; size: 13 }
                Item { Layout.fillWidth: true }
                Icon { text: Theme.up; size: 14; color: Theme.purple }
                Txt { text: SysInfo.rate(SysInfo.txRate); mono: true; size: 13 }
            }
        }

        // bilgiler
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8
            InfoChip { label: "IP"; value: Network.ip || "-"; icon: Theme.web }
            InfoChip { label: "Ping"; value: Network.ping >= 0 ? Math.round(Network.ping) + " ms" : "-"; icon: Theme.pulse
                       valueColor: Network.ping < 0 ? Theme.muted : Network.ping < 40 ? Theme.pink : Network.ping < 100 ? Theme.warn : Theme.red }
            InfoChip { label: "Ağ geçidi"; value: Network.gateway || "-"; icon: Theme.ethernet }
            InfoChip { label: "Hız"; value: Network.linkSpeed || (Network.type === "wifi" ? Network.signal + "%" : "-"); icon: Theme.speed }
            InfoChip { label: "DNS"; value: Network.dns || "-"; icon: Theme.cog }
            InfoChip { label: "VPN"; value: Network.vpn ? Network.vpn.split(" ")[0] : "kapalı"; icon: Theme.shield
                       valueColor: Network.vpn ? Theme.purple : Theme.muted }
        }

        // wifi listesi
        ColumnLayout {
            Layout.fillWidth: true
            visible: Network.hasWifiDevice
            spacing: 4
            RowLayout {
                Txt { text: "Wi-Fi ağları"; size: 12; color: Theme.subtext; Layout.fillWidth: true }
                IconButton { icon: Theme.refresh; size: 14; implicitWidth: 26; implicitHeight: 26; onClicked: Network.scan() }
            }
            Repeater {
                model: Network.wifiList.slice(0, 6)
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 32; radius: 10
                    color: wm.containsMouse ? Theme.surface3 : Theme.surface
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                        Icon { text: Theme.wifiLevels[Math.min(3, Math.floor(modelData.signal / 25))]; size: 14; color: modelData.active ? Theme.pink : Theme.lavender }
                        Txt { text: modelData.ssid; size: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                        Icon { visible: modelData.active; text: Theme.check; size: 14; color: Theme.pink }
                    }
                    MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (!modelData.active) Network.connect(modelData.ssid) }
                }
            }
        }
        Txt {
            visible: !Network.hasWifiDevice
            text: "wi-fi kartı yok, kablo ile mırlıyoruz~"
            size: 11; color: Theme.muted
        }

        RowLayout {
            spacing: 8
            PillButton { text: "Ağ ayarları"; icon: Theme.cog; onClicked: { Ui.netOpen = false; Quickshell.execDetached([Config.networkSettings]) } }
            PillButton { text: "Yenile"; icon: Theme.refresh; onClicked: { Network.refresh(); Network.scan() } }
        }
    }

    component InfoChip: Rectangle {
        id: ic
        property string label
        property string value
        property string icon
        property color valueColor: Theme.text
        Layout.fillWidth: true
        implicitHeight: 44
        radius: 12
        color: Theme.surface
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8
            spacing: 8
            Icon { text: ic.icon; size: 15; color: Theme.purple }
            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true
                Txt { text: ic.label; size: 9; color: Theme.muted }
                Txt { text: ic.value; size: 12; mono: true; color: ic.valueColor; elide: Text.ElideRight; Layout.fillWidth: true }
            }
        }
    }

    component PillButton: Rectangle {
        id: pb
        property string text
        property string icon
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 17
        color: pm.containsMouse ? Theme.pink : Theme.surface2
        Behavior on color { ColorAnimation { duration: 140 } }
        Row {
            anchors.centerIn: parent
            spacing: 6
            Icon { text: pb.icon; size: 14; color: pm.containsMouse ? Theme.bg : Theme.pink; anchors.verticalCenter: parent.verticalCenter }
            Txt { text: pb.text; size: 12; color: pm.containsMouse ? Theme.bg : Theme.text; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pb.clicked() }
    }
}
