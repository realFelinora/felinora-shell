// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../config"
import "../components"
import "../leftbar"
import "../dashboard"
import "../session"
import "../launcher"

// caelestia shell'den esinlenilen düzen: çerçeve + sol bar + tüm paneller tek pencerede, tek şekil olarak çizilir.
// Paneller çerçeveden ters yuvarlak köşelerle "büyüyerek" çıkar.
PanelWindow {
    id: win

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "felinora-shell"
    WlrLayershell.keyboardFocus: Ui.sessionOpen || Ui.launcherOpen ? WlrKeyboardFocus.Exclusive
                               : Ui.dashboardOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property int t: Theme.frame
    readonly property int bw: Theme.barWidth

    // yalnızca çerçeve, bar ve açık paneller tıklanabilir; geri kalanı alttaki pencerelere geçer
    mask: Region {
        item: barArea
        Region { item: topStrip;    intersection: Intersection.Combine }
        Region { item: rightStrip;  intersection: Intersection.Combine }
        Region { item: bottomStrip; intersection: Intersection.Combine }
        Region { item: dash;        intersection: Intersection.Combine }
        Region { item: session;     intersection: Intersection.Combine }
        Region { item: net;         intersection: Intersection.Combine }
        Region { item: app;         intersection: Intersection.Combine }
        Region { item: launcher;    intersection: Intersection.Combine }
        Region { item: scrim;       intersection: Intersection.Combine }
    }

    // dışarı tıklayınca internet panelini kapat
    // (çıkış menüsünün kendi karartması + Esc'si var; klavye odağıyla çakışmasın diye burada değil)
    HyprlandFocusGrab {
        windows: [win]
        active: Ui.netOpen && !Ui.sessionOpen
        onCleared: Ui.netOpen = false
    }

    Item { id: topStrip;    width: win.width; height: win.t }
    Item { id: rightStrip;  x: win.width - win.t; width: win.t; height: win.height }
    Item { id: bottomStrip; y: win.height - win.t; width: win.width; height: win.t }

    // ---- çıkış menüsü karartması ----
    Rectangle {
        id: scrim
        z: -3
        width: Ui.sessionOpen || Ui.launcherOpen ? win.width : 0
        height: Ui.sessionOpen || Ui.launcherOpen ? win.height : 0
        color: "black"
        opacity: Ui.sessionOpen ? 0.45 : Ui.launcherOpen ? 0.25 : 0
        Behavior on opacity { NumberAnimation { duration: 280 } }
        MouseArea { anchors.fill: parent; onClicked: { Ui.sessionOpen = false; Ui.launcherOpen = false } }
    }

    // ---- arka plan: çerçeve + panel şekilleri ----
    // 0: gölge (yarım çözünürlükte bulanık siyah kopya — ucuz)   1: keskin şekil
    Component {
        id: shadowFx
        MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 20
            brightness: -1.0
        }
    }
    Repeater {
        model: 2
        delegate: Item {
            required property int index
            readonly property bool isShadow: index === 0
            width: win.width
            height: win.height
            // sıra açıkça: gölge en altta, keskin şekil onun üstünde, bar/panel içerikleri (z 0) en üstte
            z: isShadow ? -2 : -1
            y: isShadow ? 3 : 0
            opacity: isShadow ? 0.8 : 1
            layer.enabled: isShadow
            layer.textureSize: Qt.size(Math.round(win.width / 2), Math.round(win.height / 2))
            layer.effect: isShadow ? shadowFx : null

            Shape {
                anchors.fill: parent
                preferredRendererType: parent.isShadow ? Shape.GeometryRenderer : Shape.CurveRenderer
                readonly property bool isShadow: parent.isShadow

                // ekran boyunca dikey degrade: üstte ana vurgu, ortada düz, altta ikinci vurgu
                LinearGradient {
                    id: frameGrad
                    x1: 0; y1: 0
                    x2: 0; y2: win.height
                    GradientStop { position: 0.0; color: Theme.frameTop }
                    GradientStop { position: 0.45; color: Theme.frameColor }
                    GradientStop { position: 1.0; color: Theme.frameBottom }
                }

                FramePath {
                    fillColor: Theme.frameColor
                    fillGradient: isShadow ? null : frameGrad
                    w: win.width; h: win.height
                    left: win.bw; t: win.t; r: Theme.frameRadius
                }
                EdgePath {
                    fillColor: Theme.frameColor
                    fillGradient: isShadow ? null : frameGrad
                    edge: "top"; start: dash.along; length: dash.length
                    inner: win.t; depth: dash.depth; radius: Theme.panelRadius
                }
                EdgePath {
                    fillColor: Theme.frameColor
                    fillGradient: isShadow ? null : frameGrad
                    edge: "right"; start: session.along; length: session.length
                    inner: win.width - win.t; depth: session.depth; radius: Theme.panelRadius
                }
                EdgePath {
                    fillColor: Theme.frameColor
                    fillGradient: isShadow ? null : frameGrad
                    edge: "left"; start: net.along; length: net.length
                    inner: win.bw; depth: net.depth; radius: Theme.panelRadius
                }
                EdgePath {
                    fillColor: Theme.frameColor
                    fillGradient: isShadow ? null : frameGrad
                    edge: "left"; start: app.along; length: app.length
                    inner: win.bw; depth: app.depth; radius: Theme.panelRadius
                }
                EdgePath {
                    fillColor: Theme.frameColor
                    fillGradient: isShadow ? null : frameGrad
                    edge: "bottom"; start: launcher.along; length: launcher.length
                    inner: win.height - win.t; depth: launcher.depth; radius: Theme.panelRadius
                }
            }
        }
    }

    // ---- sol bar ----
    Item {
        id: barArea
        width: win.bw
        height: win.height
        Bar {
            id: bar
            anchors.fill: parent
            appPanel: appContent
        }
    }

    // ---- üst orta: dashboard (üst kenarda menü genişliği boyunca gezinince açılır) ----
    Drawer {
        id: dash
        edge: "top"
        open: Ui.dashboardOpen
        keepAlive: true
        duration: 580
        closeFactor: 0.42
        inner: win.t
        contentW: dashContent.implicitWidth
        contentH: dashContent.implicitHeight
        along: (win.width - contentW) / 2

        onHoveredChanged: {
            if (hovered) { dashClose.stop(); if (!Ui.dashboardOpen) dashOpen.restart() }
            else { dashOpen.stop(); dashClose.restart() }
        }
    }
    DashboardPanel { id: dashContent; parent: dash.slot; anchors.fill: parent }
    Timer { id: dashOpen; interval: 120; onTriggered: Ui.dashboardOpen = true }
    Timer {
        id: dashClose
        interval: 140
        onTriggered: if (!dash.hovered && !Ui.pickerOpen) Ui.dashboardOpen = false
    }
    Connections {
        target: Ui
        function onPickerOpenChanged() { if (!Ui.pickerOpen) dashClose.restart() }
    }

    // ---- sağ orta: çıkış menüsü ----
    Drawer {
        id: session
        edge: "right"
        open: Ui.sessionOpen
        inner: win.width - win.t
        screenW: win.width
        contentW: sessionContent.implicitWidth
        contentH: sessionContent.implicitHeight
        along: (win.height - contentH) / 2
        duration: 480
    }
    SessionPanel { id: sessionContent; parent: session.slot; anchors.fill: parent }

    // ---- soldan: internet paneli (butonun hizasında) ----
    Drawer {
        id: net
        edge: "left"
        open: Ui.netOpen
        inner: win.bw
        contentW: netContent.implicitWidth
        contentH: netContent.implicitHeight
        along: {
            const b = bar.netButton
            const bottom = b.mapToItem(null, 0, b.height).y + 6
            return Math.max(win.t + Theme.panelRadius, Math.min(bottom, win.height - win.t - Theme.panelRadius) - contentH)
        }
        duration: 460
    }
    NetPanel { id: netContent; parent: net.slot; anchors.fill: parent }

    // ---- soldan: uygulama önizlemesi (ikonun hizasında) ----
    Drawer {
        id: app
        edge: "left"
        open: appContent.open
        inner: win.bw
        contentW: appContent.implicitWidth
        contentH: appContent.implicitHeight
        along: Math.max(win.t + Theme.panelRadius,
                        Math.min(win.height - win.t - Theme.panelRadius - contentH, appContent.targetY - contentH / 2))
        duration: 400
        follow: true
    }
    AppPanel { id: appContent; parent: app.slot; anchors.fill: parent; overPanel: app.hovered }

    // ---- alttan: program başlatıcı ----
    Drawer {
        id: launcher
        edge: "bottom"
        open: Ui.launcherOpen
        duration: 560
        closeFactor: 0.45
        inner: win.height - win.t
        screenH: win.height
        contentW: launcherContent.implicitWidth
        contentH: launcherContent.implicitHeight
        along: (win.width + win.bw - win.t - contentW) / 2
    }
    LauncherPanel { id: launcherContent; parent: launcher.slot; anchors.fill: parent }

    // ---- klavye ----
    Item {
        anchors.fill: parent
        focus: Ui.sessionOpen || Ui.dashboardOpen
        Keys.onPressed: e => {
            if (Ui.sessionOpen) {
                if (e.key === Qt.Key_Escape) Ui.sessionOpen = false
                else sessionContent.key(e.key)
            } else if (Ui.dashboardOpen) dashContent.key(e)
        }
    }
}
