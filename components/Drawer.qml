// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import "../config"

// Çerçeveden büyüyerek çıkan panel alanı.
// Kendi boyutu = isabet alanı (ters köşeler + çerçeve kısmı dahil);
// içerik "body" içinde kırpılır ve kenardan kayarak gelir.
Item {
    id: d
    property string edge: "top"       // top | left | right | bottom
    property bool open: false
    property real contentW: 100
    property real contentH: 100
    property real along: 0            // top: x, left/right: y (gövdenin başlangıcı)
    property real inner: 0            // çerçevenin iç kenarı
    property real screenW: 0          // sağ kenar için
    property real screenH: 0          // alt kenar için
    property bool keepAlive: false    // kapalıyken de görünür kalsın (hover tetiği için)
    property int duration: 520         // açılış süresi (kapanış bunun ~yarısı)
    property bool follow: false        // konum/boyut değişince kayarak takip etsin (uygulama önizlemesi)
    property real closeFactor: 0.55    // kapanış süresi = duration * closeFactor

    // açılış: esneyip oturan eğri — kapanış: hızlı ve keskin çekiliş
    property real prog: 0
    onOpenChanged: {
        progAnim.stop()
        progAnim.to = open ? 1 : 0
        progAnim.duration = open ? duration : Math.round(duration * closeFactor)
        progAnim.easing.bezierCurve = open ? Theme.curveSpatial : Theme.curveEmphAccel
        progAnim.start()
    }
    Component.onCompleted: prog = open ? 1 : 0
    NumberAnimation {
        id: progAnim
        target: d
        property: "prog"
        easing.type: Easing.BezierSpline
    }

    Behavior on along { enabled: d.follow && d.shown; NumberAnimation { duration: 340; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmphDecel } }
    Behavior on contentH { enabled: d.follow && d.shown; NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmphDecel } }

    readonly property real r: Theme.panelRadius
    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property real length: horizontal ? contentW : contentH
    readonly property real fullDepth: horizontal ? contentH : contentW
    readonly property real depth: fullDepth * prog
    readonly property bool shown: prog > 0.002

    readonly property Item slot: slider          // içerik buraya bağlanır (parent: drawer.slot)
    // tetik + panel üzerinde mi. Sol/sağ/alt çekmecelerin alanı yalnızca dışarı taşan panel
    // kadardır (bar/çerçeveyle çakışmaz — yoksa bardaki ikonların hover'ını çalıp titretir).
    readonly property bool hovered: hh.hovered

    HoverHandler { id: hh }

    visible: shown || keepAlive

    x: horizontal ? along - r : edge === "left" ? inner : inner - depth
    y: edge === "top" ? 0 : edge === "bottom" ? inner - depth : along - r
    width: horizontal ? length + 2 * r : depth
    height: edge === "top" ? inner + depth : edge === "bottom" ? depth : length + 2 * r

    Item {
        id: body
        clip: true
        x: d.horizontal ? d.r : 0
        y: d.edge === "top" ? d.inner : d.edge === "bottom" ? 0 : d.r
        width: d.horizontal ? d.length : d.depth
        height: d.horizontal ? d.depth : d.length

        Item {
            id: slider
            width: d.contentW
            height: d.contentH
            x: d.edge === "left" ? body.width - d.contentW : 0
            y: d.edge === "top" ? body.height - d.contentH : 0
            // içerik çerçevenin biraz arkasından gelir, kapanırken önce kaybolur
            opacity: Math.max(0, Math.min(1, (d.prog - 0.18) * 1.9))
            scale: 0.96 + 0.04 * Math.min(1, d.prog)
            transformOrigin: d.edge === "top" ? Item.Top : d.edge === "bottom" ? Item.Bottom : d.edge === "left" ? Item.Left : Item.Right
        }
    }
}
