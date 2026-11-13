// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Shapes

// Ekran kenarına yapışık panel şekli: dışa doğru yuvarlak köşeler +
// kenarla birleştiği yerde içe dönük (ters) yuvarlak köşeler.
// Kenar boyunca "u", kenardan içeri doğru "v" ekseniyle tanımlanır.
ShapePath {
    id: p
    property string edge: "top"    // top | left | right | bottom
    property real start: 0         // kenar boyunca başlangıç
    property real length: 0        // kenar boyunca uzunluk
    property real inner: 0         // çerçevenin iç kenarının koordinatı
    property real depth: 0         // panelin içeri taşma miktarı (animasyonlu)
    property real overlap: 10      // çerçeveye gömülen kısım (dikiş görünmesin)
    property real radius: 22

    readonly property real rf: Math.max(0.01, Math.min(radius, depth))
    readonly property real rc: Math.max(0.01, Math.min(radius, depth / 2, length / 2))
    // sol ve alt kenarda eksenler yansıdığı için yay yönleri ters döner
    readonly property bool flip: edge === "left" || edge === "bottom"
    readonly property int concave: flip ? PathArc.Clockwise : PathArc.Counterclockwise
    readonly property int convex: flip ? PathArc.Counterclockwise : PathArc.Clockwise

    function mx(u, v) { return edge === "top" || edge === "bottom" ? u : edge === "left" ? inner + v : inner - v }
    function my(u, v) { return edge === "top" ? inner + v : edge === "bottom" ? inner - v : u }

    readonly property real a: start
    readonly property real b: start + length

    strokeWidth: -1
    fillRule: ShapePath.WindingFill

    startX: mx(a - rf, -overlap); startY: my(a - rf, -overlap)
    PathLine { x: p.mx(p.b + p.rf, -p.overlap); y: p.my(p.b + p.rf, -p.overlap) }
    PathLine { x: p.mx(p.b + p.rf, 0); y: p.my(p.b + p.rf, 0) }
    PathArc  { x: p.mx(p.b, p.rf); y: p.my(p.b, p.rf); radiusX: p.rf; radiusY: p.rf; direction: p.concave }
    PathLine { x: p.mx(p.b, p.depth - p.rc); y: p.my(p.b, p.depth - p.rc) }
    PathArc  { x: p.mx(p.b - p.rc, p.depth); y: p.my(p.b - p.rc, p.depth); radiusX: p.rc; radiusY: p.rc; direction: p.convex }
    PathLine { x: p.mx(p.a + p.rc, p.depth); y: p.my(p.a + p.rc, p.depth) }
    PathArc  { x: p.mx(p.a, p.depth - p.rc); y: p.my(p.a, p.depth - p.rc); radiusX: p.rc; radiusY: p.rc; direction: p.convex }
    PathLine { x: p.mx(p.a, p.rf); y: p.my(p.a, p.rf) }
    PathArc  { x: p.mx(p.a - p.rf, 0); y: p.my(p.a - p.rf, 0); radiusX: p.rf; radiusY: p.rf; direction: p.concave }
    PathLine { x: p.mx(p.a - p.rf, -p.overlap); y: p.my(p.a - p.rf, -p.overlap) }
}
