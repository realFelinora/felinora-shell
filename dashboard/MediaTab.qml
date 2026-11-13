// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../config"
import "../components"
import "../services"

// [kapak + maskot] [başlık · sanatçı · açıklama · zaman çizgisi · kontroller] [şarkı sözleri]
Item {
    id: root

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // ---------- sol: kapak ----------
        Card {
            Layout.preferredWidth: 270
            Layout.fillHeight: true

            Item {
                id: coverBox
                anchors.horizontalCenter: parent.horizontalCenter
                y: 36
                width: 226; height: 226

                CatEars { earSize: 34; inset: 20; fill: Theme.surface2 }

                // arkadaki parıltı
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width; height: parent.height
                    radius: 28
                    color: Theme.pink
                    opacity: Player.playing ? 0.5 : 0.15
                    Behavior on opacity { NumberAnimation { duration: 500 } }
                    layer.enabled: true
                    layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 40 }
                }
                ClippingRectangle {
                    anchors.fill: parent
                    radius: 26
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
                        width: 140; height: 116
                        visible: Player.art === ""
                        kind: "sleep"
                    }
                }
            }

            // müziğe göre sallanan maskot
            Mascot {
                id: dancer
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: coverBox.bottom
                anchors.topMargin: 18
                width: 92; height: 100
                kind: "spin"
                transformOrigin: Item.Bottom
                SequentialAnimation on rotation {
                    running: Player.playing
                    loops: Animation.Infinite
                    NumberAnimation { to: 10;  duration: 380; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -10; duration: 380; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on anchors.topMargin {
                    running: Player.playing
                    loops: Animation.Infinite
                    NumberAnimation { to: 10; duration: 190; easing.type: Easing.OutQuad }
                    NumberAnimation { to: 18; duration: 190; easing.type: Easing.InQuad }
                }
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                text: Player.playing ? "♪ vibe check ♪" : Player.active ? "duraklatıldı (=･ω･=)" : "sessizlik..."
                size: 11
                color: Theme.subtext
            }
        }

        // ---------- orta: bilgi + kontrol ----------
        Card {
            Layout.preferredWidth: 360
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 6

                // oynatıcı seçimi
                Row {
                    spacing: 6
                    visible: Player.list.length > 1
                    Repeater {
                        model: Player.list
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: Player.player === modelData
                            width: pl.implicitWidth + 16; height: 22; radius: 11
                            color: sel ? Theme.purple : Theme.surface2
                            Txt { id: pl; anchors.centerIn: parent; text: modelData.identity; size: 10; color: parent.sel ? Theme.bg : Theme.subtext }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Player.manual = modelData }
                        }
                    }
                }

                Rectangle {
                    implicitWidth: idTxt.implicitWidth + 18
                    implicitHeight: 22
                    radius: 11
                    color: Theme.surface2
                    visible: Player.list.length <= 1 && Player.active
                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Icon { text: Theme.music; size: 11; anchors.verticalCenter: parent.verticalCenter }
                        Txt { id: idTxt; text: Player.identity; size: 10; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                Item { implicitHeight: 10 }
                Txt {
                    Layout.fillWidth: true
                    text: Player.active ? Player.title : "Hiçbir şey çalmıyor"
                    size: 24
                    font.weight: Font.Black
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
                Txt {
                    Layout.fillWidth: true
                    text: Player.active ? (Player.artist || "bilinmeyen sanatçı") : "spotify'ı aç, birlikte dinleyelim~"
                    size: 15
                    color: Theme.pink
                    elide: Text.ElideRight
                }
                Txt {
                    Layout.fillWidth: true
                    visible: Player.album !== ""
                    text: Player.album
                    size: 12
                    color: Theme.subtext
                    elide: Text.ElideRight
                }

                Item { Layout.fillHeight: true }

                // zaman çizgisi
                Item {
                    id: seek
                    Layout.fillWidth: true
                    implicitHeight: 26
                    enabled: Player.length > 0
                    property real dragFrac: -1
                    readonly property real frac: dragFrac >= 0 ? dragFrac : (Player.length > 0 ? Math.min(1, Player.position / Player.length) : 0)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 8
                        radius: 4
                        color: Theme.surface3
                        Rectangle {
                            height: parent.height
                            radius: 4
                            width: Math.max(8, parent.width * seek.frac)
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.pink }
                                GradientStop { position: 1; color: Theme.purple }
                            }
                        }
                    }
                    // pati tutamaç
                    Rectangle {
                        x: seek.width * seek.frac - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: sm.pressed || sm.containsMouse ? 26 : 22
                        height: width
                        radius: width / 2
                        color: Theme.bg
                        border.width: 2
                        border.color: Theme.pink
                        Behavior on width { NumberAnimation { duration: 120 } }
                        Icon { anchors.centerIn: parent; text: Theme.paw; size: 12 }
                    }
                    MouseArea {
                        id: sm
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        function fracAt(x) { return Math.max(0, Math.min(1, (x - 6) / seek.width)) }
                        onPressed: e => seek.dragFrac = fracAt(e.x)
                        onPositionChanged: e => { if (pressed) seek.dragFrac = fracAt(e.x) }
                        onReleased: { Player.seek(seek.dragFrac * Player.length); seek.dragFrac = -1 }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Txt { text: Player.time(seek.frac * Player.length); size: 12; mono: true; color: Theme.subtext }
                    Item { Layout.fillWidth: true }
                    Txt { text: "-" + Player.time(Player.length - seek.frac * Player.length); size: 12; mono: true; color: Theme.pink }
                }

                Item { implicitHeight: 6 }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 16
                    IconButton { icon: Theme.prev; size: 24; implicitWidth: 50; implicitHeight: 50; fg: Theme.lavender; onClicked: Player.prev() }
                    IconButton { icon: Player.playing ? Theme.pause : Theme.play; size: 30; implicitWidth: 66; implicitHeight: 66; active: true; onClicked: Player.toggle() }
                    IconButton { icon: Theme.next; size: 24; implicitWidth: 50; implicitHeight: 50; fg: Theme.lavender; onClicked: Player.next() }
                }
            }
        }

        // ---------- sağ: şarkı sözleri ----------
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Row {
                id: lyrHead
                x: 18; y: 16
                spacing: 6
                Icon { text: Theme.music; size: 14; anchors.verticalCenter: parent.verticalCenter }
                Txt { text: "Sözler"; size: 14; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
                Txt {
                    text: Player.synced ? "· canlı" : ""
                    size: 11; color: Theme.purple
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            ListView {
                id: lyr
                anchors.fill: parent
                anchors.topMargin: 48
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                anchors.bottomMargin: 12
                clip: true
                spacing: 8
                model: Player.lyrics
                currentIndex: Player.lyricIndex
                highlightRangeMode: Player.synced ? ListView.ApplyRange : ListView.NoHighlightRange
                preferredHighlightBegin: height * 0.4
                preferredHighlightEnd: height * 0.4 + 30
                highlightMoveDuration: 400
                boundsBehavior: Flickable.StopAtBounds

                delegate: Txt {
                    required property var modelData
                    required property int index
                    readonly property bool cur: index === Player.lyricIndex
                    readonly property bool past: Player.synced && index < Player.lyricIndex
                    width: lyr.width
                    text: modelData.s === "" ? "♪" : modelData.s
                    wrapMode: Text.Wrap
                    size: cur ? 17 : 14
                    font.weight: cur ? Font.Black : Font.DemiBold
                    color: cur ? Theme.pink : past ? Theme.muted : (Player.synced ? Theme.subtext : Theme.text)
                    Behavior on size { NumberAnimation { duration: 200 } }
                    Behavior on color { ColorAnimation { duration: 200 } }
                    MouseArea {
                        anchors.fill: parent
                        enabled: Player.synced
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Player.seek(modelData.t)
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: Player.lyricsState !== "ok"
                Mascot {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 96; height: 80
                    kind: "sleep"
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Player.lyricsState === "loading" ? "sözleri arıyorum... (=･ω･=)"
                        : Player.lyricsState === "none" ? "söz bulunamadı (=；ω；=)"
                        : "bir şey çal, sözleri getireyim~"
                    size: 12
                    color: Theme.subtext
                }
            }
        }
    }
}
