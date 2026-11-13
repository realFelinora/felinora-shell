// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../config"
import "../components"

// temalı dosya yöneticisi — profil resmi (ileride duvar kağıdı) seçmek için
PanelWindow {
    id: win
    screen: Quickshell.screens[0]
    visible: Ui.pickerOpen
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 940
    implicitHeight: 600
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "felinora-files"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string home: Quickshell.env("HOME")
    property string dir: home + "/Pictures"
    property var history: []
    property string selected: ""
    property bool onlyImages: true

    readonly property var imageExt: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg"]
    function isImage(name) { return imageExt.indexOf(name.split(".").pop().toLowerCase()) >= 0 }

    function go(path, remember) {
        if (remember !== false && path !== dir) history = history.concat([dir])
        dir = path
        selected = ""
    }
    function back() {
        if (!history.length) return
        dir = history[history.length - 1]
        history = history.slice(0, -1)
        selected = ""
    }
    function up() {
        if (dir === "/") return
        const p = dir.replace(/\/[^\/]+\/?$/, "")
        go(p === "" ? "/" : p)
    }
    function confirm() {
        if (!selected) return
        if (Ui.pickerPurpose === "profile") {
            Prefs.profile = selected
            // sistem geneli profil resmi (giriş ekranları vs. kullanır)
            Quickshell.execDetached(["cp", "-f", selected, home + "/.face"])
        }
        Ui.pickerOpen = false
    }

    onVisibleChanged: if (visible) { selected = ""; if (Prefs.profile) { const d = Prefs.profile.replace(/\/[^\/]+$/, ""); if (d) dir = d } }

    Rectangle {
        anchors.fill: parent
        radius: 26
        color: Theme.bg
        border.width: 1.5
        border.color: Qt.alpha(Theme.pink, 0.5)

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Ui.pickerOpen = false
            Keys.onReturnPressed: win.confirm()
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Backspace) win.up()
                else if (e.key === Qt.Key_Left && e.modifiers & Qt.AltModifier) win.back()
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            // ---- kenar çubuğu ----
            ColumnLayout {
                Layout.preferredWidth: 180
                Layout.fillHeight: true
                spacing: 4

                Row {
                    spacing: 8
                    Layout.bottomMargin: 10
                    Layout.leftMargin: 6
                    Mascot {
                        width: 34; height: 34
                        kind: "workspace"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Txt { text: "nya files"; size: 16; font.weight: Font.Black }
                        Txt { text: Ui.pickerPurpose === "profile" ? "profil resmi seç" : "dosya seç"; size: 11; color: Theme.pink }
                    }
                }

                Repeater {
                    model: [
                        { name: "Ev", icon: Theme.home, path: win.home },
                        { name: "Resimler", icon: Theme.folderImg, path: win.home + "/Pictures" },
                        { name: "İndirilenler", icon: Theme.download, path: win.home + "/Downloads" },
                        { name: "Masaüstü", icon: Theme.desktop, path: win.home + "/Desktop" },
                        { name: "Belgeler", icon: Theme.folder, path: win.home + "/Documents" },
                        { name: "Kök  /", icon: Theme.disk, path: "/" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool sel: win.dir === modelData.path
                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: 12
                        color: sel ? Theme.surface3 : (pm.containsMouse ? Theme.surface2 : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Rectangle { visible: parent.sel; width: 3; height: 18; radius: 2; color: Theme.pink; anchors.verticalCenter: parent.verticalCenter }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 12
                            spacing: 10
                            Icon { text: modelData.icon; size: 16; color: parent.parent.sel ? Theme.pink : Theme.purple; anchors.verticalCenter: parent.verticalCenter }
                            Txt { text: modelData.name; size: 13; color: parent.parent.sel ? Theme.text : Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.go(modelData.path) }
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: 12
                    color: Theme.surface
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        Txt { text: "sadece resimler"; size: 12; color: Theme.subtext; Layout.fillWidth: true }
                        Rectangle {
                            implicitWidth: 38; implicitHeight: 20; radius: 10
                            color: win.onlyImages ? Theme.pink : Theme.surface3
                            Rectangle {
                                width: 16; height: 16; radius: 8
                                y: 2
                                x: win.onlyImages ? 20 : 2
                                color: Theme.bg
                                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.onlyImages = !win.onlyImages }
                        }
                    }
                }
            }

            // ---- ana alan ----
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                // araç çubuğu
                RowLayout {
                    spacing: 6
                    IconButton { icon: Theme.back; size: 16; enabled: win.history.length > 0; opacity: enabled ? 1 : 0.35; onClicked: win.back() }
                    IconButton { icon: Theme.upDir; size: 16; onClicked: win.up() }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 17
                        color: Theme.surface
                        border.width: 1
                        border.color: Theme.border
                        // tıklanabilir yol parçaları
                        Flickable {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            contentWidth: crumbs.implicitWidth
                            clip: true
                            interactive: contentWidth > width
                            contentX: Math.max(0, contentWidth - width)
                            Row {
                                id: crumbs
                                height: parent.height
                                spacing: 2
                                Repeater {
                                    model: {
                                        const parts = win.dir.split("/").filter(p => p)
                                        const out = [{ name: "/", path: "/" }]
                                        let acc = ""
                                        for (const p of parts) { acc += "/" + p; out.push({ name: p, path: acc }) }
                                        return out
                                    }
                                    delegate: Row {
                                        required property var modelData
                                        required property int index
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Txt { visible: index > 1; text: "›"; color: Theme.muted; size: 13 }
                                        Txt {
                                            text: modelData.name
                                            size: 12
                                            color: cm.containsMouse ? Theme.pink : (modelData.path === win.dir ? Theme.text : Theme.subtext)
                                            MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.go(modelData.path) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    IconButton { icon: Theme.close; size: 16; fg: Theme.red; onClicked: Ui.pickerOpen = false }
                }

                // dosya ızgarası
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 18
                    color: Theme.surface
                    clip: true

                    FolderListModel {
                        id: fm
                        folder: "file://" + win.dir
                        showDirsFirst: true
                        showDotAndDotDot: false
                        showHidden: false
                        sortCaseSensitive: false
                        nameFilters: win.onlyImages ? win.imageExt.map(e => "*." + e).concat(win.imageExt.map(e => "*." + e.toUpperCase())) : []
                    }

                    GridView {
                        id: grid
                        anchors.fill: parent
                        anchors.margins: 10
                        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 128)))
                        cellHeight: 132
                        model: fm
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        delegate: Item {
                            id: fd
                            required property string fileName
                            required property string filePath
                            required property bool fileIsDir
                            readonly property bool img: !fileIsDir && win.isImage(fileName)
                            readonly property bool sel: win.selected === filePath
                            width: grid.cellWidth
                            height: grid.cellHeight

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 4
                                radius: 14
                                color: fd.sel ? Qt.alpha(Theme.pink, 0.18) : (fma.containsMouse ? Theme.surface3 : "transparent")
                                border.width: fd.sel ? 1.5 : 0
                                border.color: Theme.pink
                                Behavior on color { ColorAnimation { duration: 120 } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Icon {
                                            anchors.centerIn: parent
                                            visible: !fd.img
                                            text: fd.fileIsDir ? Theme.folder : Theme.file
                                            size: 46
                                            color: fd.fileIsDir ? Theme.purple : Theme.muted
                                        }
                                        ClippingRectangle {
                                            anchors.centerIn: parent
                                            visible: fd.img
                                            width: Math.min(parent.width, parent.height)
                                            height: width
                                            radius: 10
                                            color: Theme.surface2
                                            Image {
                                                anchors.fill: parent
                                                source: fd.img ? "file://" + fd.filePath : ""
                                                sourceSize: Qt.size(160, 160)
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                cache: true
                                            }
                                        }
                                    }
                                    Txt {
                                        Layout.fillWidth: true
                                        text: fd.fileName
                                        size: 11
                                        color: fd.sel ? Theme.pink : Theme.subtext
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideMiddle
                                    }
                                }
                            }
                            MouseArea {
                                id: fma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (fd.fileIsDir) win.go(fd.filePath)
                                    else if (fd.img) win.selected = fd.filePath
                                }
                                onDoubleClicked: if (fd.img) { win.selected = fd.filePath; win.confirm() }
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: fm.status === FolderListModel.Ready && fm.count === 0
                        spacing: 8
                        Mascot {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 110; height: 92
                            kind: "sleep"
                        }
                        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "burası bomboş (=･ω･=)"; size: 13; color: Theme.subtext }
                    }
                }

                // alt çubuk: seçim + onay
                RowLayout {
                    spacing: 10
                    ClippingRectangle {
                        implicitWidth: 44; implicitHeight: 44
                        radius: 22
                        color: Theme.surface2
                        border.width: 2
                        border.color: win.selected ? Theme.pink : Theme.border
                        Image {
                            anchors.fill: parent
                            source: win.selected ? "file://" + win.selected : ""
                            sourceSize: Qt.size(88, 88)
                            fillMode: Image.PreserveAspectCrop
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Txt { text: win.selected ? win.selected.split("/").pop() : "bir resim seç~"; size: 13; elide: Text.ElideMiddle; Layout.fillWidth: true }
                        Txt { text: fm.count + " öğe · çift tık = seç, Esc = kapat"; size: 10; color: Theme.muted }
                    }
                    Rectangle {
                        implicitWidth: 110; implicitHeight: 38; radius: 19
                        color: cancelMa.containsMouse ? Theme.surface3 : Theme.surface2
                        Txt { anchors.centerIn: parent; text: "iptal"; size: 13; color: Theme.subtext }
                        MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.pickerOpen = false }
                    }
                    Rectangle {
                        implicitWidth: 150; implicitHeight: 38; radius: 19
                        opacity: win.selected ? 1 : 0.4
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.pink }
                            GradientStop { position: 1; color: Theme.purple }
                        }
                        scale: okMa.pressed ? 0.94 : 1
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Icon { text: Theme.heart; size: 14; color: Theme.bg; anchors.verticalCenter: parent.verticalCenter }
                            Txt { text: Ui.pickerPurpose === "profile" ? "profil yap" : "seç"; size: 13; font.weight: Font.Black; color: Theme.bg; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: okMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.confirm() }
                    }
                }
            }
        }
    }
}
