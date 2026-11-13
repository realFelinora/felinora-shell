// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import Quickshell

// her ekran için: kenar boşlukları + tek parça shell penceresi
Variants {
    model: Quickshell.screens

    Scope {
        id: scope
        required property var modelData

        Exclusions { screen: scope.modelData }
        ContentWindow { screen: scope.modelData }
    }
}
