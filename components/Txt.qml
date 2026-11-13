// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import "../config"

Text {
    property real size: 13
    property bool mono: false
    color: Theme.text
    font.family: mono ? Theme.mono : Theme.font
    font.pixelSize: size
    font.weight: Font.DemiBold
}
