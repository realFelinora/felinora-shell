// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../config"
import "../components"
import "../services"

// her ekran için kilit yüzeyi — shell ile aynı çerçeve, aynı tema, aynı animasyonlar
WlSessionLockSurface {
    id: surf
    required property var ctx
    color: Theme.bg

    readonly property int t: Theme.frame
    readonly property int bw: Theme.barWidth

    // giriş: 0 → 1   çıkış (doğru şifre): 1 → 0
    property bool shown: false
    Component.onCompleted: enterTimer.start()
    Timer { id: enterTimer; interval: 30; onTriggered: surf.shown = true }
    readonly property bool active: shown && !ctx.exiting

    property real reveal: active ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: 650; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmphDecel } }

    // ---- şifre yazma animasyonu ----
    property real bump: 1          // kutunun zıplaması
    property real glow: 0          // her tuşta parlama
    property real spin: 0          // her harfte halkanın dönmesi
    property real failFlash: 0     // yanlış şifrede kırmızı parlama
    property int lastLen: 0
    Behavior on spin { NumberAnimation { duration: 450; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmphDecel } }
    Connections {
        target: surf.ctx
        function onBufferChanged() {
            const n = surf.ctx.buffer.length
            if (n > surf.lastLen) { surf.spin += 24; bumpAnim.restart() }
            else if (n < surf.lastLen) {
                surf.spin -= 18
                if (surf.lastLen - n === 1) ghostAnim.restart()   // tek harf silindi
            }
            surf.lastLen = n
        }
    }
    SequentialAnimation {
        id: bumpAnim
        ParallelAnimation {
            NumberAnimation { target: surf; property: "bump"; to: 1.035; duration: 70; easing.type: Easing.OutQuad }
            NumberAnimation { target: surf; property: "glow"; to: 1; duration: 70 }
        }
        ParallelAnimation {
            NumberAnimation { target: surf; property: "bump"; to: 1; duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial }
            NumberAnimation { target: surf; property: "glow"; to: 0; duration: 420; easing.type: Easing.OutCubic }
        }
    }
    SequentialAnimation {
        id: failAnim
        NumberAnimation { target: surf; property: "failFlash"; to: 1; duration: 90 }
        PauseAnimation { duration: 500 }
        NumberAnimation { target: surf; property: "failFlash"; to: 0; duration: 600 }
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property int h12: clock.hours % 12 === 0 ? 12 : clock.hours % 12
    function pad(n) { return n < 10 ? "0" + n : "" + n }
    readonly property var days: ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"]
    readonly property var months: ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]

    Item {
        id: root
        anchors.fill: parent

        // ---------- arka plan: bulanık duvar kağıdı ----------
        Image {
            id: wall
            anchors.fill: parent
            source: surf.ctx.wallpaper ? "file://" + surf.ctx.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            scale: 1 + 0.06 * surf.reveal
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: surf.reveal
                blurMax: 64
                saturation: -0.25 * surf.reveal
            }
        }
        // temanın renginde kararma + üstten vurgu ışığı
        Rectangle {
            anchors.fill: parent
            opacity: surf.reveal
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(Qt.tint(Theme.bg, Qt.alpha(Theme.pink, 0.18)), 0.62) }
                GradientStop { position: 0.5; color: Qt.alpha(Theme.bg, 0.55) }
                GradientStop { position: 1.0; color: Qt.alpha(Qt.tint(Theme.bg, Qt.alpha(Theme.purple, 0.2)), 0.7) }
            }
        }

        // ---------- çerçeve + paneller (shell ile aynı şekil) ----------
        Component {
            id: shadowFx
            MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 20; brightness: -1.0 }
        }
        Repeater {
            model: 2
            delegate: Item {
                required property int index
                readonly property bool isShadow: index === 0
                width: root.width
                height: root.height
                y: isShadow ? 3 : 0
                opacity: isShadow ? 0.8 : 1
                layer.enabled: isShadow
                layer.textureSize: Qt.size(Math.round(root.width / 2), Math.round(root.height / 2))
                layer.effect: isShadow ? shadowFx : null

                Shape {
                    anchors.fill: parent
                    preferredRendererType: parent.isShadow ? Shape.GeometryRenderer : Shape.CurveRenderer
                    readonly property bool isShadow: parent.isShadow
                    LinearGradient {
                        id: frameGrad
                        x1: 0; y1: 0; x2: 0; y2: root.height
                        GradientStop { position: 0.0; color: Theme.frameTop }
                        GradientStop { position: 0.45; color: Theme.frameColor }
                        GradientStop { position: 1.0; color: Theme.frameBottom }
                    }
                    FramePath {
                        fillColor: Theme.frameColor
                        fillGradient: isShadow ? null : frameGrad
                        w: root.width; h: root.height
                        left: surf.bw; t: surf.t; r: Theme.frameRadius
                    }
                    EdgePath {
                        fillColor: Theme.frameColor
                        fillGradient: isShadow ? null : frameGrad
                        edge: "top"; start: topDrawer.along; length: topDrawer.length
                        inner: surf.t; depth: topDrawer.depth; radius: Theme.panelRadius
                    }
                    EdgePath {
                        fillColor: Theme.frameColor
                        fillGradient: isShadow ? null : frameGrad
                        edge: "bottom"; start: bottomDrawer.along; length: bottomDrawer.length
                        inner: root.height - surf.t; depth: bottomDrawer.depth; radius: Theme.panelRadius
                    }
                }
            }
        }

        // ---------- sol bar (sadece gösterge, tıklanmaz) ----------
        Item {
            id: bar
            width: surf.bw
            height: root.height
            property real enter: surf.shown ? 1 : 0
            Behavior on enter { NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmphDecel } }
            opacity: enter
            x: -14 * (1 - enter)

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 16
                anchors.bottomMargin: 16
                spacing: 10

                // logo rozeti
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 40; implicitHeight: 48
                    Item {
                        width: 40; height: 40
                        anchors.bottom: parent.bottom
                        CatEars { earSize: 15; inset: 1; fill: Theme.surface2 }
                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: Theme.surface2
                            border.width: 2
                            border.color: Theme.pink
                            Icon { anchors.centerIn: parent; text: Theme.osIcon(SysInfo.osId); size: 22 }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // nabız atan kilit
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 40; implicitHeight: 40
                    Rectangle {
                        anchors.centerIn: parent
                        width: 38; height: 38; radius: 19
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.pink
                        SequentialAnimation on scale {
                            loops: Animation.Infinite
                            running: surf.active
                            NumberAnimation { from: 0.85; to: 1.3; duration: 1500; easing.type: Easing.OutCubic }
                            PauseAnimation { duration: 500 }
                        }
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: surf.active
                            NumberAnimation { from: 0.8; to: 0; duration: 1500; easing.type: Easing.OutCubic }
                            PauseAnimation { duration: 500 }
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 38; height: 38; radius: 19
                        color: Theme.surface
                        border.width: 1
                        border.color: Qt.alpha(Theme.pink, 0.5)
                        Icon {
                            anchors.centerIn: parent
                            text: surf.ctx.status === "success" ? Theme.lockOpen : Theme.lock
                            size: 18
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // 12 saatlik saat
                Column {
                    Layout.alignment: Qt.AlignHCenter
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: surf.pad(surf.h12); mono: true; size: 19; font.weight: Font.Bold; color: Theme.pink }
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: surf.pad(clock.minutes); mono: true; size: 19; font.weight: Font.Bold }
                    Item { width: 1; height: 4 }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 32; height: 16; radius: 8
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.pink }
                            GradientStop { position: 1; color: Theme.purple }
                        }
                        Txt { anchors.centerIn: parent; text: clock.hours < 12 ? "AM" : "PM"; size: 10; font.weight: Font.Black; color: Theme.bg }
                    }
                }
                // ağ durumu
                Column {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 2
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; text: Network.icon; size: 18; color: Network.online ? Theme.pink : Theme.muted }
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Network.type === "ethernet" ? "ETH" : Network.type === "wifi" ? "WIFI" : "OFF"
                        size: 9; font.weight: Font.Black; color: Network.online ? Theme.pink : Theme.muted
                    }
                }
            }
        }

        // ---------- üstten: büyük saat ----------
        Drawer {
            id: topDrawer
            edge: "top"
            open: surf.active
            keepAlive: false
            duration: 650
            closeFactor: 0.6
            inner: surf.t
            contentW: 440
            contentH: 168
            along: (root.width - contentW) / 2
        }
        Item {
            parent: topDrawer.slot
            anchors.fill: parent
            ColumnLayout {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 4
                spacing: 2
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10
                    Row {
                        Txt { text: surf.pad(surf.h12); mono: true; size: 78; font.weight: Font.Bold; color: Theme.pink }
                        Txt { text: ":"; mono: true; size: 78; font.weight: Font.Bold; color: Theme.purple; opacity: clock.seconds % 2 ? 0.35 : 1
                              Behavior on opacity { NumberAnimation { duration: 300 } } }
                        Txt { text: surf.pad(clock.minutes); mono: true; size: 78; font.weight: Font.Bold }
                    }
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 58; implicitHeight: 28; radius: 14
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.pink }
                            GradientStop { position: 1; color: Theme.purple }
                        }
                        Txt { anchors.centerIn: parent; text: clock.hours < 12 ? "AM" : "PM"; size: 15; font.weight: Font.Black; color: Theme.bg }
                    }
                }
                Txt {
                    Layout.alignment: Qt.AlignHCenter
                    text: surf.days[clock.date.getDay()] + ", " + clock.date.getDate() + " " + surf.months[clock.date.getMonth()]
                    size: 17
                    color: Theme.subtext
                }
            }
        }

        // ---------- alttan: hava + medya ----------
        Drawer {
            id: bottomDrawer
            edge: "bottom"
            open: surf.active
            duration: 700
            closeFactor: 0.55
            inner: root.height - surf.t
            screenH: root.height
            contentW: 680
            contentH: 112
            along: (root.width - contentW) / 2
        }
        Item {
            parent: bottomDrawer.slot
            anchors.fill: parent

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                anchors.topMargin: 14
                anchors.bottomMargin: 16
                spacing: 18

                // hava
                RowLayout {
                    spacing: 10
                    Layout.preferredWidth: 190
                    Icon {
                        text: Weather.current ? Weather.icon(Weather.current.code, Weather.current.isDay) : Theme.cloud
                        size: 40
                        color: Theme.pink
                    }
                    ColumnLayout {
                        spacing: 0
                        Txt { text: Weather.current ? Math.round(Weather.current.temp) + "°C" : "--°C"; size: 24; font.weight: Font.Black }
                        Txt { text: Weather.current ? Weather.desc(Weather.current.code) : ""; size: 12; color: Theme.pink }
                        Txt { text: Weather.city; size: 11; color: Theme.subtext }
                    }
                }

                Rectangle { implicitWidth: 1; Layout.fillHeight: true; color: Theme.border }

                // medya
                ClippingRectangle {
                    implicitWidth: 72; implicitHeight: 72
                    radius: 14
                    color: Theme.surface2
                    Image {
                        anchors.fill: parent
                        source: Player.art
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: Player.art !== ""
                    }
                    Mascot {
                        anchors.centerIn: parent
                        width: 56; height: 56
                        visible: Player.art === ""
                        kind: "sleep"
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Txt { Layout.fillWidth: true; text: Player.active ? Player.title : "şu an bir şey çalmıyor"; size: 15; font.weight: Font.Black; elide: Text.ElideRight }
                    Txt { Layout.fillWidth: true; text: Player.active ? Player.artist : "sessizlik..."; size: 12; color: Theme.pink; elide: Text.ElideRight }
                    Bar {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        implicitHeight: 4
                        visible: Player.length > 0
                        value: Player.length > 0 ? Player.position / Player.length : 0
                    }
                }
                RowLayout {
                    spacing: 4
                    visible: Player.active
                    IconButton { icon: Theme.prev; size: 18; implicitWidth: 38; implicitHeight: 38; fg: Theme.lavender; onClicked: Player.prev() }
                    IconButton { icon: Player.playing ? Theme.pause : Theme.play; size: 20; implicitWidth: 46; implicitHeight: 46; active: true; onClicked: Player.toggle() }
                    IconButton { icon: Theme.next; size: 18; implicitWidth: 38; implicitHeight: 38; fg: Theme.lavender; onClicked: Player.next() }
                }
            }
        }

        // ---------- orta: profil + şifre ----------
        ColumnLayout {
            id: center
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: surf.bw / 2 - surf.t / 2
            spacing: 14
            opacity: surf.reveal
            scale: surf.ctx.exiting ? 1.06 : 0.92 + 0.08 * surf.reveal
            Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }

            // profil resmi — her harfte halka biraz döner, kontrol sırasında hızlanır
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 156; implicitHeight: 156

                Item {
                    anchors.fill: parent
                    RotationAnimation on rotation { from: 0; to: 360; duration: surf.ctx.status === "checking" ? 1400 : 8000; loops: Animation.Infinite; running: surf.active }
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        rotation: surf.spin
                        gradient: Gradient {
                            GradientStop { position: 0; color: surf.failFlash > 0 ? Theme.red : Theme.pink }
                            GradientStop { position: 1; color: Theme.purpleDeep }
                        }
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: surf.failFlash > 0 ? Theme.red : Theme.pink
                            shadowBlur: 1.0
                            shadowOpacity: Math.min(1, 0.45 + surf.glow * 0.5 + (surf.ctx.status === "checking" ? 0.35 : 0))
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                        }
                    }
                }
                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: 5
                    radius: width / 2
                    color: Theme.surface2
                    Image {
                        anchors.fill: parent
                        source: Prefs.profile ? "file://" + Prefs.profile : ""
                        visible: Prefs.profile !== ""
                        sourceSize: Qt.size(300, 300)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                    }
                    Mascot { anchors.fill: parent; kind: "avatar"; crop: true; visible: Prefs.profile === "" }
                }
            }

            Txt {
                Layout.alignment: Qt.AlignHCenter
                text: Quickshell.env("USER")
                size: 28
                font.weight: Font.Black
            }

            // şifre kutusu
            Item {
                id: inputBox
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 380
                implicitHeight: 56
                transform: Translate { id: shakeX }
                scale: surf.bump

                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: shakeX; property: "x"; to: -14; duration: 50 }
                    NumberAnimation { target: shakeX; property: "x"; to: 12; duration: 70 }
                    NumberAnimation { target: shakeX; property: "x"; to: -9; duration: 70 }
                    NumberAnimation { target: shakeX; property: "x"; to: 6; duration: 70 }
                    NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 90 }
                }
                Connections {
                    target: surf.ctx
                    function onFailed() { shake.restart(); failAnim.restart() }
                }

                // tuşa basınca parlayan çerçeve
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.alpha(Theme.surface, 0.92)
                    border.width: 2
                    border.color: surf.failFlash > 0 || surf.ctx.status === "fail" || surf.ctx.status === "error" ? Theme.red
                                : surf.ctx.status === "success" ? Theme.pink
                                : surf.ctx.buffer.length > 0 ? Qt.alpha(Theme.pink, 0.55 + 0.45 * surf.glow) : Theme.border
                    Behavior on border.color { ColorAnimation { duration: 160 } }
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: surf.failFlash > 0 ? Theme.red : Theme.pink
                        shadowBlur: 1.0
                        shadowOpacity: Math.max(surf.glow * 0.85, surf.failFlash * 0.9, surf.ctx.status === "checking" ? 0.5 : 0)
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }
                }

                Icon {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: surf.ctx.status === "success" ? Theme.lockOpen : Theme.lock
                    size: 18
                    color: surf.failFlash > 0 || surf.ctx.status === "fail" || surf.ctx.status === "error" ? Theme.red : Theme.pink
                    rotation: surf.ctx.status === "success" ? -15 : 0
                    scale: surf.ctx.status === "success" ? 1.25 : 1
                    Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }
                    Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }
                }

                // yazılan her karakter bir pati: sıra yumuşakça kayarak ortalanır,
                // renkler pembeden mora akar, sonda yanıp sönen ince imleç
                Item {
                    id: pawsBox
                    anchors.verticalCenter: parent.verticalCenter
                    height: 24
                    width: paws.width
                    x: (inputBox.width - width) / 2
                    Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmphDecel } }

                    Row {
                        id: paws
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Repeater {
                            model: Math.min(surf.ctx.buffer.length, 18)
                            delegate: Item {
                                id: pawItem
                                required property int index
                                readonly property real mix: Math.min(1, pawItem.index / 12)
                                width: 16; height: 22
                                Icon {
                                    id: pawIcon
                                    anchors.centerIn: parent
                                    text: Theme.paw
                                    size: 14
                                    color: surf.ctx.status === "success" ? Theme.pinkSoft
                                         : Qt.rgba(Theme.pink.r + (Theme.purple.r - Theme.pink.r) * pawItem.mix,
                                                   Theme.pink.g + (Theme.purple.g - Theme.pink.g) * pawItem.mix,
                                                   Theme.pink.b + (Theme.purple.b - Theme.pink.b) * pawItem.mix, 1)
                                    Behavior on color { ColorAnimation { duration: 250 } }
                                    scale: 0
                                    opacity: 0
                                    transform: Translate { id: drop; y: -7 }
                                    Component.onCompleted: popIn.start()
                                    ParallelAnimation {
                                        id: popIn
                                        NumberAnimation { target: pawIcon; property: "opacity"; from: 0; to: 1; duration: 140 }
                                        NumberAnimation { target: pawIcon; property: "scale"; from: 0.3; to: 1; duration: 340; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial }
                                        NumberAnimation { target: drop; property: "y"; from: -7; to: 0; duration: 340; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial }
                                    }
                                    // kontrol ediliyor: sırayla yanıp sönen dalga
                                    SequentialAnimation {
                                        running: surf.ctx.status === "checking"
                                        loops: Animation.Infinite
                                        onStopped: pawIcon.opacity = 1
                                        PauseAnimation { duration: pawItem.index * 60 }
                                        NumberAnimation { target: pawIcon; property: "opacity"; to: 0.25; duration: 260; easing.type: Easing.InOutSine }
                                        NumberAnimation { target: pawIcon; property: "opacity"; to: 1; duration: 260; easing.type: Easing.InOutSine }
                                    }
                                }
                            }
                        }
                    }

                    // imleç
                    Rectangle {
                        x: paws.width + (paws.width > 0 ? 4 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2; height: 18; radius: 1
                        color: Theme.pink
                        visible: surf.ctx.buffer.length > 0 && surf.ctx.status === ""
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        SequentialAnimation on opacity {
                            running: surf.active
                            loops: Animation.Infinite
                            NumberAnimation { to: 1; duration: 0 }
                            PauseAnimation { duration: 520 }
                            NumberAnimation { to: 0.1; duration: 220 }
                            PauseAnimation { duration: 300 }
                            NumberAnimation { to: 1; duration: 220 }
                        }
                    }
                }

                // silinen pati: küçülüp kaybolan hayalet
                Icon {
                    id: ghost
                    text: Theme.paw
                    size: 14
                    color: Theme.muted
                    opacity: 0
                    x: pawsBox.x + paws.width + 4
                    anchors.verticalCenter: parent.verticalCenter
                    transform: Translate { id: ghostDrop }
                    ParallelAnimation {
                        id: ghostAnim
                        NumberAnimation { target: ghost; property: "opacity"; from: 0.8; to: 0; duration: 240 }
                        NumberAnimation { target: ghost; property: "scale"; from: 1; to: 0.2; duration: 240; easing.type: Easing.InBack }
                        NumberAnimation { target: ghostDrop; property: "y"; from: 0; to: 8; duration: 240 }
                    }
                }

                Txt {
                    anchors.centerIn: parent
                    opacity: surf.ctx.buffer.length === 0 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    text: surf.ctx.status === "checking" ? "kontrol ediliyor..."
                        : surf.ctx.status === "success" ? "hoş geldin~"
                        : "şifreni yaz~"
                    size: 14
                    color: Theme.muted
                }

                // gönder
                IconButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 40; implicitHeight: 40
                    icon: Theme.enter
                    size: 22
                    active: surf.ctx.buffer.length > 0
                    fg: surf.ctx.buffer.length > 0 ? Theme.pink : Theme.muted
                    onClicked: surf.ctx.submit()
                }
            }

            // durum satırı
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 380
                implicitHeight: 22
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    visible: surf.ctx.status === "fail" || surf.ctx.status === "error" || surf.ctx.caps
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: surf.ctx.status === "fail" || surf.ctx.status === "error" ? Theme.alert : Theme.capsLock
                        size: 14
                        color: surf.ctx.status === "fail" || surf.ctx.status === "error" ? Theme.red : Theme.warn
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: surf.ctx.status === "fail" ? "yanlış şifre, tekrar dene (=；ω；=)"
                            : surf.ctx.status === "error" ? "doğrulama hatası"
                            : "Caps Lock açık"
                        size: 12
                        color: surf.ctx.status === "fail" || surf.ctx.status === "error" ? Theme.red : Theme.warn
                    }
                }
            }
        }

        // ---------- klavye ----------
        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                if (surf.ctx.exiting) return
                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) surf.ctx.submit()
                else if (e.key === Qt.Key_Escape) surf.ctx.buffer = ""
                else if (e.key === Qt.Key_Backspace) {
                    if (e.modifiers & Qt.ControlModifier) surf.ctx.buffer = ""
                    else surf.ctx.buffer = surf.ctx.buffer.slice(0, -1)
                } else if (e.text && /^[^\x00-\x1F\x7F-\x9F]+$/.test(e.text)) {
                    surf.ctx.buffer += e.text
                }
                e.accepted = true
            }
        }
    }
}
