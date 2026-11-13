// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Layouts
import "../config"
import "../components"
import "../services"

// CPU · GPU · RAM / Depolama · Ağ
Item {
    id: root

    function tempColor(t) { return t >= 80 ? Theme.red : t >= 65 ? Theme.warn : Theme.pink }
    function gb(kb) { return (kb / 1048576).toFixed(1) }

    readonly property var disk: {
        const ds = SysInfo.disks
        for (let i = 0; i < ds.length; i++) if (ds[i].name === Prefs.disk) return ds[i]
        return ds.length ? ds[0] : null
    }
    readonly property var io: disk && SysInfo.diskIo[disk.name] ? SysInfo.diskIo[disk.name] : ({ r: 0, w: 0 })

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 236
            Layout.fillHeight: false
            spacing: 12

            // ---- CPU ----
            StatCard {
                icon: Theme.cpu
                title: "CPU"
                subtitle: SysInfo.cpuModel
                value: SysInfo.cpu
                center: Math.round(SysInfo.cpu * 100) + "%"
                hist: SysInfo.cpuHist
                rows: [
                    { k: "Sıcaklık", v: SysInfo.cpuTemp > 0 ? SysInfo.cpuTemp.toFixed(0) + "°C" : "-", c: root.tempColor(SysInfo.cpuTemp) },
                    { k: "Frekans", v: (SysInfo.cpuMhz / 1000).toFixed(2) + " GHz" },
                    { k: "Çekirdek", v: SysInfo.cores + "" }
                ]
            }

            // ---- GPU ----
            StatCard {
                icon: Theme.gpu
                title: "GPU"
                subtitle: SysInfo.gpu.ok ? SysInfo.gpu.name : "okunuyor..."
                value: Math.max(0, SysInfo.gpu.util)
                center: SysInfo.gpu.util >= 0 ? Math.round(SysInfo.gpu.util * 100) + "%" : "-"
                hist: SysInfo.gpuHist
                c1: Theme.purple; c2: Theme.pink
                rows: [
                    { k: "Sıcaklık", v: SysInfo.gpu.temp >= 0 ? SysInfo.gpu.temp + "°C" : "-", c: root.tempColor(SysInfo.gpu.temp) },
                    { k: "VRAM", v: SysInfo.gpu.memTotal > 0 ? (SysInfo.gpu.memUsed / 1024).toFixed(1) + "/" + (SysInfo.gpu.memTotal / 1024).toFixed(0) + " GB" : "-" },
                    { k: SysInfo.gpu.power >= 0 ? "Güç · Fan" : "Fan",
                      v: (SysInfo.gpu.power >= 0 ? SysInfo.gpu.power.toFixed(0) + "W · " : "") + (SysInfo.gpu.fan >= 0 ? SysInfo.gpu.fan + "%" : "-") }
                ]
            }

            // ---- RAM ----
            StatCard {
                icon: Theme.ram
                title: "Bellek"
                subtitle: root.gb(SysInfo.memTotal) + " GB RAM"
                value: SysInfo.memTotal > 0 ? SysInfo.memUsed / SysInfo.memTotal : 0
                center: root.gb(SysInfo.memUsed) + "G"
                hist: []
                rows: [
                    { k: "Kullanılan", v: root.gb(SysInfo.memUsed) + " GB" },
                    { k: "Boş", v: root.gb(SysInfo.memTotal - SysInfo.memUsed) + " GB" },
                    { k: "Swap", v: root.gb(SysInfo.swapUsed) + "/" + root.gb(SysInfo.swapTotal) + " GB" }
                ]
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // ---- Depolama ----
            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    RowLayout {
                        spacing: 6
                        Icon { text: Theme.disk; size: 18 }
                        Txt { text: "Depolama"; size: 15; font.weight: Font.Black }
                        Item { Layout.fillWidth: true }
                        // hangi fiziksel disk gösterilsin
                        Repeater {
                            model: SysInfo.disks
                            delegate: Rectangle {
                                id: chip
                                required property var modelData
                                readonly property bool sel: root.disk !== null && root.disk.name === modelData.name
                                implicitWidth: chipRow.implicitWidth + 18
                                implicitHeight: 26
                                radius: 13
                                color: sel ? Theme.pink : (chipMa.containsMouse ? Theme.surface3 : Theme.surface2)
                                Behavior on color { ColorAnimation { duration: 140 } }
                                Row {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Txt { text: chip.modelData.ssd ? "SSD" : "HDD"; size: 10; font.weight: Font.Black; color: chip.sel ? Theme.bg : Theme.pink; anchors.verticalCenter: parent.verticalCenter }
                                    Txt { text: SysInfo.bytes(chip.modelData.size); size: 11; mono: true; color: chip.sel ? Theme.bg : Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                                }
                                MouseArea {
                                    id: chipMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Prefs.disk = chip.modelData.name
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 16
                        Ring {
                            implicitWidth: 124; implicitHeight: 124
                            value: root.disk && root.disk.fsTotal > 0 ? root.disk.used / root.disk.fsTotal : 0
                            thickness: 12
                            Column {
                                anchors.centerIn: parent
                                Txt { anchors.horizontalCenter: parent.horizontalCenter; text: root.disk && root.disk.fsTotal > 0 ? Math.round(root.disk.used / root.disk.fsTotal * 100) + "%" : "-"; size: 24; font.weight: Font.Black }
                                Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "dolu"; size: 11; color: Theme.subtext }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Txt {
                                Layout.fillWidth: true
                                text: root.disk ? "/dev/" + root.disk.name + " · " + (root.disk.model || "?") : "-"
                                size: 12; font.weight: Font.Bold; elide: Text.ElideRight
                            }
                            Txt {
                                text: root.disk ? (root.disk.ssd ? "SSD" : "HDD") + (root.disk.tran ? " · " + root.disk.tran : "") : ""
                                size: 10; color: Theme.purple
                            }
                            KV { k: "Kullanılan"; v: root.disk ? SysInfo.bytes(root.disk.used) : "-" }
                            KV { k: "Boş"; v: root.disk ? SysInfo.bytes(root.disk.fsTotal - root.disk.used) : "-"; vc: Theme.pink }
                            KV { k: "Okuma · Yazma"; v: SysInfo.rate(root.io.r) + " · " + SysInfo.rate(root.io.w) }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 4
                                Repeater {
                                    model: root.disk ? root.disk.parts : []
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: pt.implicitWidth + 12; height: 18; radius: 9
                                        color: Theme.surface3
                                        Txt { id: pt; anchors.centerIn: parent; text: modelData.mount + "  " + Math.round(modelData.used / modelData.size * 100) + "%"; size: 9; mono: true; color: Theme.lavender }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---- Ağ ----
            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Spark {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: 1
                    height: 80
                    values: SysInfo.rxHist
                    lineColor: Theme.pink
                }
                Spark {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: 1
                    height: 80
                    values: SysInfo.txHist
                    lineColor: Theme.purple
                    maxValue: Math.max.apply(null, SysInfo.rxHist.concat([1]))
                }

                ColumnLayout {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 10

                    RowLayout {
                        Icon { text: Network.icon; size: 18 }
                        Txt { text: "İnternet"; size: 15; font.weight: Font.Black }
                        Item { Layout.fillWidth: true }
                        Txt { text: SysInfo.iface + " · " + (Network.ping >= 0 ? Math.round(Network.ping) + " ms" : "-"); mono: true; size: 11; color: Theme.subtext }
                    }
                    RowLayout {
                        spacing: 24
                        ColumnLayout {
                            spacing: 0
                            Row { spacing: 4; Icon { text: Theme.down; size: 14; color: Theme.pink } Txt { text: "indirme"; size: 11; color: Theme.subtext } }
                            Txt { text: SysInfo.rate(SysInfo.rxRate); mono: true; size: 22; font.weight: Font.Bold }
                            Txt { text: "toplam " + SysInfo.bytes(SysInfo.rxTotal); size: 11; color: Theme.muted }
                        }
                        ColumnLayout {
                            spacing: 0
                            Row { spacing: 4; Icon { text: Theme.up; size: 14; color: Theme.purple } Txt { text: "yükleme"; size: 11; color: Theme.subtext } }
                            Txt { text: SysInfo.rate(SysInfo.txRate); mono: true; size: 22; font.weight: Font.Bold }
                            Txt { text: "toplam " + SysInfo.bytes(SysInfo.txTotal); size: 11; color: Theme.muted }
                        }
                    }
                }
            }
        }
    }

    component KV: RowLayout {
        id: kv
        property string k
        property string v
        property color vc: Theme.text
        Layout.fillWidth: true
        Txt { text: kv.k; size: 12; color: Theme.subtext }
        Item { Layout.fillWidth: true }
        Txt { text: kv.v; size: 12; mono: true; color: kv.vc }
    }

    component StatCard: Card {
        id: sc
        property string icon
        property string title
        property string subtitle
        property real value
        property string center
        property var hist: []
        property var rows: []
        property color c1: Theme.pink
        property color c2: Theme.purple
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        Spark {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 1
            height: 50
            values: sc.hist
            maxValue: 1
            lineColor: sc.c1
            opacity: 0.6
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            RowLayout {
                spacing: 6
                Icon { text: sc.icon; size: 18; color: sc.c1 }
                Txt { text: sc.title; size: 15; font.weight: Font.Black }
            }
            Txt { Layout.fillWidth: true; text: sc.subtitle; size: 11; color: Theme.subtext; elide: Text.ElideRight }

            RowLayout {
                spacing: 14
                Ring {
                    implicitWidth: 104; implicitHeight: 104
                    value: sc.value
                    c1: sc.c1; c2: sc.c2
                    Txt { anchors.centerIn: parent; text: sc.center; size: 20; font.weight: Font.Black }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: sc.rows
                        delegate: ColumnLayout {
                            required property var modelData
                            spacing: 0
                            Txt { text: modelData.k; size: 10; color: Theme.muted }
                            Txt { text: modelData.v; size: 14; mono: true; font.weight: Font.Bold; color: modelData.c || Theme.text }
                        }
                    }
                }
            }
        }
    }
}
