// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../config"
import "../components"

// program başlatıcı — alt kenardan çıkar
//   (boş)  uygulamalar, en sık açılanlar önde
//   =      hesap makinesi (Enter: sonucu panoya kopyala)
//   >      komut çalıştır (Shift+Enter: terminalde)
//   ?      web'de ara
//   :      tema değiştir
Item {
    id: root
    implicitWidth: 880
    implicitHeight: 540

    readonly property string query: input.text
    readonly property string mode: query.startsWith("=") ? "calc"
                                 : query.startsWith(">") ? "cmd"
                                 : query.startsWith("?") ? "web"
                                 : query.startsWith(":") ? "theme" : "apps"
    readonly property string term: mode === "apps" ? query.trim() : query.slice(1).trim()
    readonly property var modes: [
        { id: "apps",  prefix: "",  label: "Uygulamalar", icon: Theme.apps },
        { id: "calc",  prefix: "=", label: "Hesap",       icon: Theme.calc },
        { id: "cmd",   prefix: ">", label: "Komut",       icon: Theme.terminal },
        { id: "web",   prefix: "?", label: "Web",         icon: Theme.web },
        { id: "theme", prefix: ":", label: "Tema",        icon: Theme.palette }
    ]

    property bool fresh: false      // açılışta kademeli giriş animasyonu
    Timer { id: freshTimer; interval: 500; onTriggered: root.fresh = false }

    Connections {
        target: Ui
        function onLauncherOpenChanged() {
            if (Ui.launcherOpen) {
                input.text = ""
                list.currentIndex = 0
                root.fresh = true
                freshTimer.restart()
                Qt.callLater(() => input.forceActiveFocus())
            }
        }
    }

    // ---------- arama ----------
    function lower(s) { return (s || "").toLocaleLowerCase("tr-TR") }
    function subseq(hay, needle) {
        let i = 0
        for (let c of hay) if (c === needle[i]) { i++; if (i === needle.length) return true }
        return false
    }
    function score(e, q) {
        const n = lower(e.name)
        let s
        if (n === q) s = 1000
        else if (n.startsWith(q)) s = 800
        else if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q))) s = 600
        else if (n.includes(q)) s = 450
        else if (lower(e.genericName).includes(q)) s = 300
        else if ((e.keywords || []).some(k => lower(k).includes(q))) s = 220
        else if (lower(e.comment).includes(q)) s = 140
        else if (subseq(n, q)) s = 90
        else return -1
        return s + Math.min(150, (Prefs.launches[e.id] || 0) * 12)
    }

    function calc(expr) {
        const e = expr.replace(/,/g, ".").replace(/×/g, "*").replace(/÷/g, "/").replace(/\^/g, "**")
        if (!e || !/^[0-9+\-*/().%\s]+$/.test(e)) return null
        try {
            const v = Function('"use strict"; return (' + e + ')')()
            if (typeof v === "number" && isFinite(v)) return Math.round(v * 1e10) / 1e10
        } catch (err) {}
        return null
    }

    readonly property var apps: {
        const out = []
        const all = DesktopEntries.applications.values
        for (let i = 0; i < all.length; i++) if (!all[i].noDisplay) out.push(all[i])
        return out
    }

    readonly property var results: {
        const q = lower(term)
        if (mode === "apps") {
            let list
            if (!q) {
                list = apps.slice().sort((a, b) => ((Prefs.launches[b.id] || 0) - (Prefs.launches[a.id] || 0)) || a.name.localeCompare(b.name, "tr"))
            } else {
                list = apps.map(e => ({ e: e, s: score(e, q) })).filter(x => x.s >= 0).sort((a, b) => b.s - a.s).map(x => x.e)
            }
            return list.slice(0, 50).map(e => ({ kind: "app", entry: e }))
        }
        if (mode === "calc") {
            const v = calc(term)
            return term ? [{ kind: "calc", value: v, expr: term }] : [{ kind: "calc", value: null, expr: "" }]
        }
        if (mode === "cmd") {
            if (!term) return [{ kind: "hint", text: "çalıştırılacak komutu yaz" }]
            return [{ kind: "cmd", cmd: term, terminal: false }, { kind: "cmd", cmd: term, terminal: true }]
        }
        if (mode === "web") {
            if (!term) return [{ kind: "hint", text: "aranacak şeyi yaz" }]
            return [{ kind: "web", q: term, site: "Google" }, { kind: "web", q: term, site: "YouTube" }, { kind: "web", q: term, site: "Vikipedi" }]
        }
        return Theme.themes.filter(t => !q || lower(t.name).includes(q) || lower(t.desc).includes(q)).map(t => ({ kind: "theme", t: t }))
    }
    readonly property var current: results.length ? results[Math.min(list.currentIndex, results.length - 1)] : null
    onResultsChanged: list.currentIndex = 0

    function iconOf(e) { return Quickshell.iconPath(e.icon, "application-x-executable") }

    function activate(item, alt) {
        if (!item) return
        switch (item.kind) {
        case "app": {
            const e = item.entry
            Prefs.countLaunch(e.id)
            if (e.runInTerminal) Quickshell.execDetached([Config.terminal, "-e"].concat(e.command))
            else e.execute()
            Ui.launcherOpen = false
            break
        }
        case "calc":
            if (item.value === null) return
            Quickshell.execDetached(["wl-copy", String(item.value)])
            Ui.launcherOpen = false
            break
        case "cmd":
            if (item.terminal || alt) Quickshell.execDetached([Config.terminal, "-e", "sh", "-c", item.cmd + "; printf '\\n[bitti, kapatmak için Enter]'; read _"])
            else Quickshell.execDetached(["sh", "-c", item.cmd])
            Ui.launcherOpen = false
            break
        case "web": {
            const q = encodeURIComponent(item.q)
            const url = item.site === "YouTube" ? "https://www.youtube.com/results?search_query=" + q
                      : item.site === "Vikipedi" ? "https://tr.wikipedia.org/w/index.php?search=" + q
                      : "https://www.google.com/search?q=" + q
            Quickshell.execDetached(["xdg-open", url])
            Ui.launcherOpen = false
            break
        }
        case "theme":
            Prefs.theme = item.t.id      // açık kalır: temaları tek tek deneyebilirsin
            break
        }
    }

    function cycleMode(dir) {
        const i = modes.findIndex(m => m.id === mode)
        const next = modes[(i + dir + modes.length) % modes.length]
        input.text = next.prefix + term
        input.cursorPosition = input.text.length
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        anchors.topMargin: 20
        spacing: 12

        // ---------- arama çubuğu ----------
        Rectangle {
            id: bar
            Layout.fillWidth: true
            implicitHeight: 56
            radius: 28
            color: Theme.surface2
            border.width: 2
            border.color: input.activeFocus ? Qt.alpha(Theme.pink, 0.75) : Theme.border
            Behavior on border.color { ColorAnimation { duration: 200 } }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.pink
                shadowBlur: 0.9
                shadowOpacity: input.activeFocus ? 0.35 : 0
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }

            Icon {
                id: modeIcon
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: root.modes.find(m => m.id === root.mode).icon
                size: 22
                // mod değişince küçük bir dönüş
                property string last: text
                onTextChanged: { if (modeIcon.text !== modeIcon.last) { modeIcon.last = modeIcon.text; spinIcon.restart() } }
                RotationAnimation on rotation { id: spinIcon; running: false; from: -90; to: 0; duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial }
            }

            TextInput {
                id: input
                anchors.left: modeIcon.right
                anchors.leftMargin: 14
                anchors.right: countChip.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                selectionColor: Qt.alpha(Theme.pink, 0.4)
                selectedTextColor: Theme.text
                font.family: Theme.font
                font.pixelSize: 18
                font.weight: Font.DemiBold
                clip: true
                cursorDelegate: Rectangle {
                    width: 2
                    color: Theme.pink
                    radius: 1
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: input.activeFocus
                        NumberAnimation { to: 1; duration: 0 }
                        PauseAnimation { duration: 520 }
                        NumberAnimation { to: 0.1; duration: 200 }
                        PauseAnimation { duration: 280 }
                        NumberAnimation { to: 1; duration: 200 }
                    }
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length === 0
                    text: "ne açalım?   = hesap  ·  > komut  ·  ? web  ·  : tema"
                    size: 16
                    color: Theme.muted
                }

                Keys.onPressed: e => {
                    const n = root.results.length
                    if (e.key === Qt.Key_Escape) { Ui.launcherOpen = false; e.accepted = true }
                    else if (e.key === Qt.Key_Down || (e.key === Qt.Key_J && e.modifiers & Qt.ControlModifier)) { if (n) list.currentIndex = (list.currentIndex + 1) % n; e.accepted = true }
                    else if (e.key === Qt.Key_Up || (e.key === Qt.Key_K && e.modifiers & Qt.ControlModifier)) { if (n) list.currentIndex = (list.currentIndex - 1 + n) % n; e.accepted = true }
                    else if (e.key === Qt.Key_Tab) { root.cycleMode(1); e.accepted = true }
                    else if (e.key === Qt.Key_Backtab) { root.cycleMode(-1); e.accepted = true }
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.activate(root.current, e.modifiers & Qt.ShiftModifier); e.accepted = true }
                }
            }

            Rectangle {
                id: countChip
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: countTxt.implicitWidth + 20
                implicitHeight: 30
                radius: 15
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.pink }
                    GradientStop { position: 1; color: Theme.purple }
                }
                Txt {
                    id: countTxt
                    anchors.centerIn: parent
                    text: root.mode === "apps" ? root.results.length + " uygulama" : root.modes.find(m => m.id === root.mode).label
                    size: 12
                    font.weight: Font.Black
                    color: Theme.bg
                }
            }
        }

        // ---------- mod çipleri ----------
        Row {
            spacing: 8
            Repeater {
                model: root.modes
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool sel: root.mode === modelData.id
                    width: chipRow.implicitWidth + 22
                    height: 30
                    radius: 15
                    color: sel ? Qt.alpha(Theme.pink, 0.18) : (chipMa.containsMouse ? Theme.surface3 : Theme.surface)
                    border.width: 1
                    border.color: sel ? Theme.pink : Theme.border
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on border.color { ColorAnimation { duration: 160 } }
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6
                        Icon { text: chip.modelData.icon; size: 13; color: chip.sel ? Theme.pink : Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                        Txt { text: chip.modelData.label; size: 12; color: chip.sel ? Theme.text : Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                        Txt { visible: chip.modelData.prefix !== ""; text: chip.modelData.prefix; size: 11; mono: true; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: chipMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { input.text = chip.modelData.prefix + root.term; input.forceActiveFocus() }
                    }
                }
            }
        }

        // ---------- liste + detay ----------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Item {
                Layout.preferredWidth: 480
                Layout.fillHeight: true

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    spacing: 4
                    model: root.results
                    boundsBehavior: Flickable.StopAtBounds
                    highlightFollowsCurrentItem: false
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    // kayan seçim vurgusu
                    highlight: Rectangle {
                        width: list.width
                        height: 58
                        radius: 16
                        y: list.currentItem ? list.currentItem.y : 0
                        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.alpha(Theme.pink, 0.22) }
                            GradientStop { position: 1; color: Qt.alpha(Theme.purple, 0.06) }
                        }
                        border.width: 1
                        border.color: Qt.alpha(Theme.pink, 0.45)
                        Rectangle {
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 4; height: 24; radius: 2
                            color: Theme.pink
                        }
                    }

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool sel: ListView.isCurrentItem
                        width: list.width
                        height: 58

                        // açılışta kademeli giriş
                        opacity: 0
                        transform: Translate { id: rowShift; x: 0 }
                        Component.onCompleted: {
                            if (root.fresh && index < 10) { rowShift.x = 26; enterAnim.start() }
                            else opacity = 1
                        }
                        SequentialAnimation {
                            id: enterAnim
                            PauseAnimation { duration: row.index * 28 }
                            ParallelAnimation {
                                NumberAnimation { target: row; property: "opacity"; to: 1; duration: 220 }
                                NumberAnimation { target: rowShift; property: "x"; to: 0; duration: 380; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 14
                            spacing: 14

                            Item {
                                implicitWidth: 36; implicitHeight: 36
                                scale: row.sel ? 1.12 : 1
                                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }
                                IconImage {
                                    anchors.fill: parent
                                    visible: row.modelData.kind === "app"
                                    source: row.modelData.kind === "app" ? root.iconOf(row.modelData.entry) : ""
                                    asynchronous: true
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    visible: row.modelData.kind !== "app"
                                    radius: 12
                                    color: Theme.surface3
                                    Icon {
                                        anchors.centerIn: parent
                                        size: 18
                                        text: row.modelData.kind === "calc" ? Theme.calc
                                            : row.modelData.kind === "cmd" ? Theme.terminal
                                            : row.modelData.kind === "web" ? Theme.web
                                            : row.modelData.kind === "theme" ? Theme.palette : Theme.search
                                    }
                                    // tema satırı: renk noktası
                                    Rectangle {
                                        visible: row.modelData.kind === "theme"
                                        anchors.fill: parent
                                        radius: 12
                                        gradient: Gradient {
                                            GradientStop { position: 0; color: row.modelData.kind === "theme" ? row.modelData.t.accent : "transparent" }
                                            GradientStop { position: 1; color: row.modelData.kind === "theme" ? row.modelData.t.accent2 : "transparent" }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Txt {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    size: 15
                                    font.weight: row.sel ? Font.Black : Font.Bold
                                    color: row.sel ? Theme.text : Qt.alpha(Theme.text, 0.88)
                                    text: {
                                        const m = row.modelData
                                        if (m.kind === "app") return m.entry.name
                                        if (m.kind === "calc") return m.value !== null ? "= " + m.value : (m.expr ? "geçersiz ifade" : "bir işlem yaz (ör. 12*7+3)")
                                        if (m.kind === "cmd") return m.terminal ? "Terminalde çalıştır" : "Çalıştır"
                                        if (m.kind === "web") return m.site + "'da ara"
                                        if (m.kind === "theme") return m.t.name + (Prefs.theme === m.t.id ? "  ✓" : "")
                                        return m.text
                                    }
                                }
                                Txt {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    size: 11
                                    color: Theme.subtext
                                    visible: text !== ""
                                    text: {
                                        const m = row.modelData
                                        if (m.kind === "app") return m.entry.comment || m.entry.genericName || ""
                                        if (m.kind === "calc") return m.expr
                                        if (m.kind === "cmd") return m.cmd
                                        if (m.kind === "web") return m.q
                                        if (m.kind === "theme") return m.t.desc
                                        return ""
                                    }
                                }
                            }

                            // sık açılan
                            Row {
                                visible: row.modelData.kind === "app" && (Prefs.launches[row.modelData.entry.id] || 0) >= 3
                                spacing: 3
                                Icon { text: Theme.fire; size: 12; color: Theme.warn; anchors.verticalCenter: parent.verticalCenter }
                                Txt { text: row.modelData.kind === "app" ? (Prefs.launches[row.modelData.entry.id] || 0) : ""; size: 10; mono: true; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: list.currentIndex = row.index
                            onClicked: root.activate(row.modelData, false)
                        }
                    }

                    // boş sonuç
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: root.results.length === 0
                        Mascot {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 110; height: 90
                            kind: "sleep"
                        }
                        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "bulunamadı (=･ω･=)?"; size: 13; color: Theme.subtext }
                    }
                }
            }

            // ---------- detay kartı ----------
            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // seçim değişince detay hafifçe yenilenir
                Item {
                    id: detail
                    anchors.fill: parent
                    anchors.margins: 20
                    property var item: root.current
                    onItemChanged: detailAnim.restart()
                    SequentialAnimation {
                        id: detailAnim
                        ParallelAnimation {
                            NumberAnimation { target: detail; property: "opacity"; from: 0.35; to: 1; duration: 260 }
                            NumberAnimation { target: detailShift; property: "y"; from: 10; to: 0; duration: 340; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmphDecel }
                        }
                    }
                    transform: Translate { id: detailShift }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10
                        visible: detail.item !== null

                        // büyük ikon / sembol
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 6
                            implicitWidth: 104; implicitHeight: 104

                            Rectangle {
                                anchors.centerIn: parent
                                width: 104; height: 104; radius: 52
                                gradient: Gradient {
                                    GradientStop { position: 0; color: Qt.alpha(Theme.pink, 0.22) }
                                    GradientStop { position: 1; color: Qt.alpha(Theme.purple, 0.08) }
                                }
                                RotationAnimation on rotation { from: 0; to: 360; duration: 12000; loops: Animation.Infinite; running: Ui.launcherOpen }
                                border.width: 1
                                border.color: Qt.alpha(Theme.pink, 0.35)
                            }
                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 72
                                visible: detail.item && detail.item.kind === "app"
                                source: detail.item && detail.item.kind === "app" ? root.iconOf(detail.item.entry) : ""
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    shadowEnabled: true
                                    shadowColor: Theme.pink
                                    shadowBlur: 1.0
                                    shadowOpacity: 0.55
                                    shadowHorizontalOffset: 0
                                    shadowVerticalOffset: 3
                                }
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: detail.item && detail.item.kind !== "app" && detail.item.kind !== "theme"
                                size: 46
                                text: !detail.item ? "" : detail.item.kind === "calc" ? Theme.calc
                                    : detail.item.kind === "cmd" ? Theme.terminal
                                    : detail.item.kind === "web" ? Theme.web : Theme.search
                            }
                            // tema: büyük renk diski
                            Row {
                                anchors.centerIn: parent
                                visible: detail.item && detail.item.kind === "theme"
                                spacing: -10
                                Repeater {
                                    model: detail.item && detail.item.kind === "theme" ? [detail.item.t.accent, detail.item.t.accent2, detail.item.t.tint] : []
                                    Rectangle {
                                        required property var modelData
                                        width: 34; height: 34; radius: 17
                                        color: modelData
                                        border.width: 2
                                        border.color: Theme.surface
                                    }
                                }
                            }
                        }

                        Txt {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            size: detail.item && detail.item.kind === "calc" ? 34 : 20
                            mono: detail.item !== null && detail.item.kind === "calc"
                            font.weight: Font.Black
                            color: detail.item && detail.item.kind === "calc" ? Theme.pink : Theme.text
                            text: {
                                const m = detail.item
                                if (!m) return ""
                                if (m.kind === "app") return m.entry.name
                                if (m.kind === "calc") return m.value !== null ? String(m.value) : "?"
                                if (m.kind === "cmd") return m.terminal ? "Terminalde" : "Arka planda"
                                if (m.kind === "web") return m.site
                                if (m.kind === "theme") return m.t.name
                                return "ipucu"
                            }
                        }
                        Txt {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            size: 13
                            color: Theme.pink
                            visible: text !== ""
                            elide: Text.ElideRight
                            text: {
                                const m = detail.item
                                if (!m) return ""
                                if (m.kind === "app") return m.entry.genericName || ""
                                if (m.kind === "calc") return m.expr ? m.expr + " =" : ""
                                if (m.kind === "cmd") return m.cmd
                                if (m.kind === "web") return "“" + m.q + "”"
                                if (m.kind === "theme") return m.t.desc
                                return m.text
                            }
                        }
                        Txt {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            size: 12
                            color: Theme.subtext
                            visible: text !== ""
                            text: detail.item && detail.item.kind === "app" ? (detail.item.entry.comment || "") : ""
                        }

                        // kategoriler
                        Flow {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 5
                            visible: detail.item && detail.item.kind === "app"
                            Repeater {
                                model: detail.item && detail.item.kind === "app" ? detail.item.entry.categories.filter(c => !/^(GTK|Qt|KDE|GNOME|X-)/.test(c)).slice(0, 4) : []
                                Rectangle {
                                    required property var modelData
                                    width: ct.implicitWidth + 16; height: 22; radius: 11
                                    color: Theme.surface3
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Icon { text: Theme.tag; size: 10; color: Theme.purple; anchors.verticalCenter: parent.verticalCenter }
                                        Txt { id: ct; text: modelData; size: 10; color: Theme.lavender; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // alt bilgi
                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 6
                            visible: detail.item && detail.item.kind === "app" && (Prefs.launches[detail.item.entry.id] || 0) > 0
                            Icon { text: Theme.fire; size: 13; color: Theme.warn; anchors.verticalCenter: parent.verticalCenter }
                            Txt {
                                text: detail.item && detail.item.kind === "app" ? (Prefs.launches[detail.item.entry.id] || 0) + " kez açıldı" : ""
                                size: 11; color: Theme.subtext
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: actRow.implicitWidth + 28
                            implicitHeight: 38
                            radius: 19
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.pink }
                                GradientStop { position: 1; color: Theme.purple }
                            }
                            scale: actMa.pressed ? 0.94 : (actMa.containsMouse ? 1.04 : 1)
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }
                            Row {
                                id: actRow
                                anchors.centerIn: parent
                                spacing: 6
                                Icon {
                                    text: detail.item && detail.item.kind === "calc" ? Theme.copy : detail.item && detail.item.kind === "theme" ? Theme.palette : Theme.rocket
                                    size: 15; color: Theme.bg
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Txt {
                                    text: {
                                        const m = detail.item
                                        if (!m) return ""
                                        if (m.kind === "calc") return "kopyala"
                                        if (m.kind === "theme") return "uygula"
                                        if (m.kind === "web") return "ara"
                                        if (m.kind === "cmd") return "çalıştır"
                                        return "aç"
                                    }
                                    size: 13; font.weight: Font.Black; color: Theme.bg
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea { id: actMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.activate(detail.item, false) }
                        }
                    }
                }
            }
        }

        // ---------- kısayol ipuçları ----------
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16
            Repeater {
                model: [
                    { k: Theme.upDown, t: "seç" },
                    { k: Theme.returnKey, t: "aç" },
                    { k: "Tab", t: "mod" },
                    { k: "Shift+↵", t: "terminalde" },
                    { k: "Esc", t: "kapat" }
                ]
                delegate: Row {
                    required property var modelData
                    spacing: 5
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(22, kt.implicitWidth + 10); height: 20; radius: 6
                        color: Theme.surface3
                        Txt { id: kt; anchors.centerIn: parent; text: modelData.k; size: 10; mono: true; color: Theme.lavender; font.family: Theme.iconFont }
                    }
                    Txt { anchors.verticalCenter: parent.verticalCenter; text: modelData.t; size: 11; color: Theme.muted }
                }
            }
        }
    }
}
