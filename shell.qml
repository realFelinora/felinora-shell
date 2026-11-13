//@ pragma UseQApplication
//@ pragma IconTheme Papirus
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import Quickshell
import Quickshell.Io
import QtQuick
import "config"
import "services"
import "drawers"
import "picker"
import "lock"
import "files"

// ฅ^•ﻌ•^ฅ  Felinora-shell  ฅ^•ﻌ•^ฅ
ShellRoot {
    Drawers {}
    FilePicker {}
    Lock { id: lockScreen }
    FileManager {}
    // kitty / fastfetch / cava / Qt tema eşlemesi (config.json'da açıksa)
    readonly property bool terminalSync: TerminalTheme.ready

    // kısayollar için: qs -c felinora-shell ipc call felinora <fonksiyon>
    IpcHandler {
        target: "felinora"
        function dashboard(): void { Ui.dashboardOpen = !Ui.dashboardOpen }
        function tab(name: string): void { Ui.openTab(name) }
        function session(): void { Ui.sessionOpen = !Ui.sessionOpen }
        function launcher(): void { Ui.toggleLauncher() }
        function network(): void { Ui.netOpen = !Ui.netOpen }
        function terminal(): void { TerminalTheme.apply() }
        // boş yol: dosya yöneticisini aç/kapat; yol verilirse orada açar
        function files(path: string): void { if (Ui.filesOpen && !path) Ui.filesOpen = false; else Ui.openFiles(path) }
        function theme(id: string): void { Prefs.theme = id }
        function state(): string { return JSON.stringify({ dashboard: Ui.dashboardOpen, session: Ui.sessionOpen, net: Ui.netOpen, picker: Ui.pickerOpen }) }
        function profile(): void { if (Ui.pickerOpen) Ui.pickerOpen = false; else Ui.openPicker("profile") }
    }
}
