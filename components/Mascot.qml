// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import "../config"

// Ayarlanabilir maskot resmi. config.json'da resim verilmemişse yerine ikon çizilir.
//   kind: workspace | special | spin | sleep | avatar
Item {
    id: m
    property string kind: "workspace"
    property string fallback: kind === "special" ? Theme.cat
                            : kind === "spin" ? Theme.cat
                            : kind === "sleep" ? Theme.moon
                            : kind === "avatar" ? Theme.account : Theme.paw
    property color fallbackColor: kind === "special" ? Theme.lavender : kind === "sleep" ? Theme.purple : Theme.pink
    property real fallbackSize: Math.min(width, height) * 0.62
    property bool crop: false
    readonly property string src: Config.image(kind)
    readonly property bool showImg: src !== ""

    Image {
        anchors.fill: parent
        opacity: m.showImg ? 1 : 0
        scale: m.showImg ? 1 : 0.6
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 320 } }
        Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack } }
        source: m.src
        fillMode: m.crop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
        sourceSize: Qt.size(Math.max(1, m.width * 2), Math.max(1, m.height * 2))
        asynchronous: true
        smooth: true
    }
    Icon {
        anchors.centerIn: parent
        opacity: m.showImg ? 0 : 1
        scale: m.showImg ? 0.6 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 320 } }
        Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack } }
        text: m.fallback
        size: m.fallbackSize
        color: m.fallbackColor
    }
}
