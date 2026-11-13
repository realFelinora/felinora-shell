// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Shapes

// Ekranı saran çerçeve: dış dikdörtgen eksi iç yuvarlatılmış dikdörtgen
ShapePath {
    id: f
    property real w: 0
    property real h: 0
    property real left: 56     // sol bar genişliği
    property real t: 8         // üst/sağ/alt kalınlık
    property real r: 24        // iç köşe yarıçapı

    strokeWidth: -1
    fillRule: ShapePath.OddEvenFill

    startX: 0; startY: 0
    PathLine { x: f.w; y: 0 }
    PathLine { x: f.w; y: f.h }
    PathLine { x: 0; y: f.h }
    PathLine { x: 0; y: 0 }

    PathMove { x: f.left + f.r; y: f.t }
    PathLine { x: f.w - f.t - f.r; y: f.t }
    PathArc  { x: f.w - f.t; y: f.t + f.r; radiusX: f.r; radiusY: f.r }
    PathLine { x: f.w - f.t; y: f.h - f.t - f.r }
    PathArc  { x: f.w - f.t - f.r; y: f.h - f.t; radiusX: f.r; radiusY: f.r }
    PathLine { x: f.left + f.r; y: f.h - f.t }
    PathArc  { x: f.left; y: f.h - f.t - f.r; radiusX: f.r; radiusY: f.r }
    PathLine { x: f.left; y: f.t + f.r }
    PathArc  { x: f.left + f.r; y: f.t; radiusX: f.r; radiusY: f.r }
}
