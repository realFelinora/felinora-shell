// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../config"

// pencerelerin çerçevenin altına girmemesi için kenarlarda boşluk ayırır
Scope {
    id: root
    required property var screen

    Zone { anchors.left: true;   exclusiveZone: Theme.barWidth }
    Zone { anchors.top: true;    exclusiveZone: Theme.frame }
    Zone { anchors.right: true;  exclusiveZone: Theme.frame }
    Zone { anchors.bottom: true; exclusiveZone: Theme.frame }

    component Zone: PanelWindow {
        screen: root.screen
        color: "transparent"
        implicitWidth: 1
        implicitHeight: 1
        mask: Region {}
        WlrLayershell.namespace: "felinora-exclusion"
    }
}
