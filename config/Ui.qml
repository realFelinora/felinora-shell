pragma Singleton
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import Quickshell
import QtQuick

// hangi pencere açık — her yerden erişilir
Singleton {
    property bool dashboardOpen: false
    property int dashTab: 0
    property bool sessionOpen: false
    property bool netOpen: false
    property bool launcherOpen: false
    property bool pickerOpen: false
    property string pickerPurpose: "profile"
    property bool filesOpen: false       // dosya yöneticisi (files/FileManager.qml)
    property string filesStart: ""
    function openFiles(path) { filesStart = path || ""; filesOpen = true }

    readonly property var tabs: ["dashboard", "media", "performance", "weather", "theme"]

    function openTab(name) {
        const i = tabs.indexOf(name)
        if (i >= 0) dashTab = i
        dashboardOpen = true
    }
    signal lockRequested()
    function lock() { sessionOpen = false; dashboardOpen = false; netOpen = false; launcherOpen = false; lockRequested() }
    function toggleLauncher() {
        if (!launcherOpen) { sessionOpen = false; dashboardOpen = false; netOpen = false }
        launcherOpen = !launcherOpen
    }

    function openPicker(purpose) {
        pickerPurpose = purpose
        pickerOpen = true
    }
}
