// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt.labs.folderlistmodel
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../config"
import "../components"

// ฅ^•ﻌ•^ฅ  File Manager — temalı dosya yöneticisi (normal pencere; tema değişince renkleri yumuşakça geçer)
// aç: qs -c felinora-shell ipc call felinora files [yol]   (README → "Dosya yöneticisi")
LazyLoader {
    id: loader
    active: Ui.filesOpen

    FloatingWindow {
        id: win
        title: "File Manager — " + win.dirName
        implicitWidth: 1180
        implicitHeight: 720
        minimumSize: Qt.size(760, 460)
        color: Theme.bg
        visible: true
        onVisibleChanged: if (!visible) Ui.filesOpen = false

        // ================= durum =================
        readonly property string home: Quickshell.env("HOME")
        readonly property string trashDir: home + "/.local/share/Trash/files"
        readonly property string ops: Quickshell.shellPath("scripts/fileops.sh")
        property string dir: Ui.filesStart || home
        Connections { target: Ui; function onFilesStartChanged() { if (Ui.filesStart) win.go(Ui.filesStart) } }
        readonly property string dirName: dir === "/" ? "/" : dir === home ? "Ev" : dir === trashDir ? "Çöp" : dir.split("/").pop()
        readonly property bool inTrash: dir === trashDir
        property var backStack: []
        property var fwdStack: []
        property var sel: ({})            // seçili yollar: { yol: true }
        property int selCount: 0
        property int anchorIdx: -1        // shift ile aralık seçimi için
        property int curIdx: -1           // klavye imleci
        property bool grid: true
        property bool showHidden: false
        property bool preview: true
        property int sortMode: 0          // 0 ad, 1 tarih, 2 boyut, 3 tür
        property bool sortDesc: false
        property string query: ""
        property string renaming: ""
        property var clip: ({ mode: "", paths: [] })
        property int token: 0             // klasör değişince giriş animasyonu için
        property string freeText: ""
        // config.json → files.alwaysHidden: bu yollar listede HİÇ görünmez (Ctrl+H ile de);
        // yol çubuğuna yazıp içine girilebilir. Arayüzden kapatılamaz.
        readonly property var alwaysHidden: { const m = {}; Config.filesHidden.forEach(p => m[p.replace(/\/+$/, "")] = true); return m }
        property var hiddenNames: ({})    // bu klasörün .hidden dosyasındaki adlar (Dolphin da aynısını kullanır)
        onHiddenNamesChanged: fm.invalidate()
        onShowHiddenChanged: fm.invalidate()
        function loadHidden() { hidRead.running = false; hidRead.running = true }
        function isHiddenName(n) { return n.startsWith(".") || hiddenNames[n] === true }
        function hideSel(on) {
            const s = selected(); if (!s.length) return
            const names = s.map(p => p.replace(/^.*\//, ""))
            run([on ? "hide" : "unhide", dir].concat(names),
                on ? (names.length > 1 ? names.length + " öğe gizlendi" : "gizlendi") + " ฅ^•ω•^ฅ  (Ctrl+H ile görünür)" : "artık görünüyor")
            if (on && !showHidden) clearSel()
        }

        readonly property var sortNames: ["ad", "tarih", "boyut", "tür"]

        function go(path, remember) {
            if (!path) return
            path = path.replace(/\/+$/, "") || "/"
            if (path === dir) return
            if (remember !== false) { backStack = backStack.concat([dir]); fwdStack = [] }
            dir = path
            afterMove()
        }
        function afterMove() {
            clearSel(); query = ""; renaming = ""; curIdx = -1; token++; hiddenNames = ({})
            df.running = false; df.running = true
            loadHidden()
            keys.forceActiveFocus()
        }
        function back() { if (!backStack.length) return; fwdStack = fwdStack.concat([dir]); dir = backStack[backStack.length - 1]; backStack = backStack.slice(0, -1); afterMove() }
        function forward() { if (!fwdStack.length) return; backStack = backStack.concat([dir]); dir = fwdStack[fwdStack.length - 1]; fwdStack = fwdStack.slice(0, -1); afterMove() }
        function up() { if (dir === "/") return; const p = dir.replace(/\/[^\/]+$/, ""); go(p === "" ? "/" : p) }

        // ---- seçim ----
        function clearSel() { sel = ({}); selCount = 0; anchorIdx = -1 }
        function setSel(paths) { paths = paths.filter(p => !!p); const s = {}; paths.forEach(p => s[p] = true); sel = s; selCount = paths.length }
        function selected() { return Object.keys(sel) }
        function pathAt(i) { return fm.get(i, "filePath") }
        function clickItem(i, mods) {
            const p = pathAt(i)
            if (mods & Qt.ControlModifier) {
                const s = Object.assign({}, sel)
                if (s[p]) delete s[p]; else s[p] = true
                sel = s; selCount = Object.keys(s).length; anchorIdx = i
            } else if ((mods & Qt.ShiftModifier) && anchorIdx >= 0) {
                const a = Math.min(anchorIdx, i), b = Math.max(anchorIdx, i), out = []
                for (let k = a; k <= b; k++) out.push(pathAt(k))
                setSel(out)
            } else {
                setSel([p]); anchorIdx = i
            }
            curIdx = i
        }
        function selectAll() { const out = []; for (let k = 0; k < fm.count; k++) out.push(pathAt(k)); setSel(out) }

        // ---- açma ----
        function openIdx(i) {
            if (i < 0 || i >= fm.count) return
            if (fm.get(i, "fileIsDir")) go(pathAt(i))
            else Quickshell.execDetached(["xdg-open", pathAt(i)])
        }

        // ---- işlemler ----
        function run(args, okMsg) {
            const p = opProc.createObject(win, { okMsg: okMsg || "" })
            p.command = [ops].concat(args)
            p.running = true
        }
        function copySel(cut) {
            const s = selected(); if (!s.length) return
            clip = { mode: cut ? "move" : "copy", paths: s }
            // diğer uygulamalar da yapıştırabilsin
            Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$@" | sed "s|^|file://|" | wl-copy -t text/uri-list', "sh"].concat(s))
            toast((cut ? "kesildi: " : "kopyalandı: ") + s.length + " öğe")
        }
        function paste() {
            if (inTrash) return
            if (clip.paths.length) {
                run([clip.mode, dir].concat(clip.paths), clip.mode === "move" ? "taşındı~" : "yapıştırıldı~")
                if (clip.mode === "move") clip = { mode: "", paths: [] }
            } else run(["clip", dir], "yapıştırıldı~")
        }
        // ---- sürükle-bırak ----
        // sol tuşla sürükle → klasöre taşı (Ctrl basılıysa kopyala); sağ tuşla sürükle → bırakınca "taşı / kopyala" menüsü
        property bool dragging: false
        property var dragPaths: []
        property int dragBtn: Qt.LeftButton
        property point dragPos: Qt.point(0, 0)
        property string dropTarget: ""
        property var sideItems: []
        function dragBegin(paths, btn) { dragPaths = paths; dragBtn = btn; dropTarget = ""; dragging = true; ctx.shown = false }
        function dragMove(x, y) {
            dragPos = Qt.point(x, y)
            dropTarget = targetAt(x, y)
        }
        function targetAt(x, y) {
            const ok = t => t && t !== win.dir && dragPaths.indexOf(t) < 0 && !dragPaths.some(p => t.startsWith(p + "/"))
            for (const it of sideItems) {
                if (!it || !it.visible) continue
                const q = keys.mapToItem(it, x, y)
                if (q.x >= 0 && q.y >= 0 && q.x < it.width && q.y < it.height) return ok(it.path) ? it.path : ""
            }
            const v = win.grid ? gridView : listView
            const q = keys.mapToItem(v, x, y)
            if (q.x < 0 || q.y < 0 || q.x >= v.width || q.y >= v.height) return ""
            const c = v.itemAt(q.x + v.contentX, q.y + v.contentY)
            return c && c.fileIsDir && ok(c.filePath) ? c.filePath : ""
        }
        function dragEnd(mods) {
            if (!dragging) return
            dragging = false
            const t = dropTarget, paths = dragPaths; dropTarget = ""
            if (!t) return
            if (dragBtn === Qt.RightButton) { dropMenu.openAt(dragPos.x, dragPos.y, t, paths); return }
            dropDo(t, paths, (mods & Qt.ControlModifier) ? "copy" : "move")
        }
        function dropDo(t, paths, mode) {
            const name = t === trashDir ? "Çöp" : t.split("/").pop()
            if (t === trashDir) run(["trash"].concat(paths), paths.length + " öğe çöpe atıldı")
            else run([mode, t].concat(paths), (paths.length > 1 ? paths.length + " öğe " : "") + name + (mode === "copy" ? " klasörüne kopyalandı~" : " klasörüne taşındı~"))
            if (mode === "move") clearSel()
        }

        function trashSel() {
            const s = selected(); if (!s.length) return
            if (inTrash) { confirm.ask(s.length + " öğe kalıcı olarak silinsin mi?", () => run(["delete"].concat(s), "silindi")); return }
            run(["trash"].concat(s), s.length + " öğe çöpe atıldı")
            clearSel()
        }
        function deleteSel() {
            const s = selected(); if (!s.length) return
            confirm.ask(s.length + " öğe kalıcı olarak silinsin mi? (geri alınamaz)", () => { run(["delete"].concat(s), "silindi"); clearSel() })
        }
        function startRename() { const s = selected(); if (s.length === 1) renaming = s[0] }
        function commitRename(path, name) {
            renaming = ""
            if (name && name !== path.split("/").pop()) run(["rename", path, name], "yeniden adlandırıldı")
            keys.forceActiveFocus()
        }
        function newFolder() { run(["mkdir", dir, "Yeni klasör"], "klasör oluşturuldu") }
        function newFile() { run(["touch", dir, "Yeni dosya.txt"], "dosya oluşturuldu") }
        function terminalHere() { Quickshell.execDetached(["kitty", "--directory", dir]) }
        function copyPath() {
            const s = selected(); const t = s.length ? s.join("\n") : dir
            Quickshell.execDetached(["wl-copy", t]); toast("yol kopyalandı")
        }

        // ---- birlikte aç ----
        readonly property string owScript: Quickshell.shellPath("scripts/openwith.py")
        function openWith() {
            const s = selected(); if (s.length !== 1) return
            owDlg.file = s[0]; owDlg.apps = []; owDlg.recent = []; owDlg.mime = ""; owDlg.always = false; owDlg.cmd = ""; owDlg.shown = true
            owInput.forceActiveFocus()
            owQuery.command = ["env", "FELINORA_PINNED=" + Config.filesPinned.join(";"), "python3", owScript, "apps", s[0]]
            owQuery.running = false; owQuery.running = true
        }
        function launchWith(id, always) {
            Quickshell.execDetached(["python3", owScript, "open", id, owDlg.file])
            if (always) {
                Quickshell.execDetached(["python3", owScript, "default", id, owDlg.mime])
                toast("artık " + owDlg.mime.split("/").pop() + " dosyaları bununla açılacak~")
            }
            owDlg.shown = false
            keys.forceActiveFocus()
        }
        // terminale yazar gibi: "subl", "nvim", "ristretto" … → KOMUT DOSYA
        function runCmd(cmd, always) {
            cmd = cmd.trim(); if (!cmd) return
            const p = opProc.createObject(win, { okMsg: always ? "açılıyor~ artık " + owDlg.mime.split("/").pop() + " dosyaları bununla açılacak" : "açılıyor~ ฅ^•ω•^ฅ" })
            p.command = ["python3", owScript, "run", cmd, owDlg.file].concat(always && owDlg.mime ? [owDlg.mime] : [])
            p.running = true
            owDlg.shown = false
            keys.forceActiveFocus()
        }

        function toast(t) { toastBox.text = t; toastBox.shown = true; toastTimer.restart() }

        // ---- biçimlendirme ----
        function human(n) {
            if (n < 1024) return n + " B"
            const u = ["KB", "MB", "GB", "TB"]; let i = -1
            do { n /= 1024; i++ } while (n >= 1024 && i < u.length - 1)
            return n.toFixed(n < 10 ? 1 : 0) + " " + u[i]
        }
        function when(d) {
            if (!d) return ""
            const now = new Date(), diff = (now - d) / 1000
            if (diff < 60) return "az önce"
            if (diff < 3600) return Math.floor(diff / 60) + " dk önce"
            if (d.toDateString() === now.toDateString()) return "bugün " + Qt.formatTime(d, "hh:mm")
            if (diff < 86400 * 6) return Math.floor(diff / 86400) + " gün önce"
            return Qt.formatDate(d, "d MMM yyyy")
        }
        readonly property var imgExt: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "avif", "ico", "tiff"]
        function ext(n) { const i = n.lastIndexOf("."); return i > 0 ? n.slice(i + 1).toLowerCase() : "" }
        function isImg(n) { return imgExt.indexOf(ext(n)) >= 0 }
        function kind(n, isDir) {
            if (isDir) return "klasör"
            const e = ext(n)
            if (isImg(n)) return "resim"
            if (["mp4", "mkv", "webm", "avi", "mov"].indexOf(e) >= 0) return "video"
            if (["mp3", "flac", "ogg", "wav", "m4a", "opus"].indexOf(e) >= 0) return "ses"
            if (["zip", "tar", "gz", "xz", "7z", "rar", "zst", "bz2"].indexOf(e) >= 0) return "arşiv"
            if (e === "pdf") return "PDF"
            if (["sh", "py", "js", "ts", "qml", "lua", "c", "cpp", "h", "rs", "go", "java", "json", "conf", "toml", "yaml", "yml", "ini", "css", "html"].indexOf(e) >= 0) return "kod"
            if (["txt", "md", "log"].indexOf(e) >= 0) return "metin"
            return e ? e.toUpperCase() + " dosyası" : "dosya"
        }
        readonly property var dirIcons: ({ "Desktop": "user-desktop", "Masaüstü": "user-desktop", "Documents": "folder-documents", "Belgeler": "folder-documents",
            "Downloads": "folder-download", "İndirilenler": "folder-download", "Music": "folder-music", "Müzik": "folder-music",
            "Pictures": "folder-pictures", "Resimler": "folder-pictures", "Videos": "folder-videos", "Videolar": "folder-videos",
            ".config": "folder-configure", "Projects": "folder-development", "projects": "folder-development", "Templates": "folder-templates",
            "Public": "folder-publicshare", "Games": "folder-games" })
        function iconFor(n, isDir) {
            if (isDir) return Quickshell.iconPath(dirIcons[n] || "folder", "folder")
            const e = ext(n)
            const m = { "mp4": "video-x-generic", "mkv": "video-x-generic", "webm": "video-x-generic", "avi": "video-x-generic", "mov": "video-x-generic",
                "mp3": "audio-x-generic", "flac": "audio-x-generic", "ogg": "audio-x-generic", "wav": "audio-x-generic", "m4a": "audio-x-generic", "opus": "audio-x-generic",
                "pdf": "application-pdf", "zip": "application-zip", "tar": "application-x-tar", "gz": "application-x-compressed-tar", "xz": "application-x-xz-compressed-tar",
                "7z": "application-x-7z-compressed", "rar": "application-x-rar", "zst": "application-x-zstd-compressed-tar", "iso": "application-x-cd-image",
                "txt": "text-x-generic", "md": "text-markdown", "log": "text-x-log", "sh": "application-x-shellscript", "py": "text-x-python",
                "js": "text-x-javascript", "qml": "text-x-qml", "lua": "text-x-lua", "c": "text-x-csrc", "cpp": "text-x-c++src", "h": "text-x-chdr",
                "rs": "text-rust", "go": "text-x-go", "java": "text-x-java", "json": "application-json", "html": "text-html", "css": "text-css",
                "conf": "text-x-makefile", "toml": "text-x-generic", "desktop": "application-x-desktop", "jar": "application-x-java-archive",
                "exe": "application-x-ms-dos-executable", "AppImage": "application-x-executable", "deb": "application-x-deb", "torrent": "application-x-bittorrent",
                "ttf": "font-x-generic", "otf": "font-x-generic", "docx": "x-office-document", "odt": "x-office-document", "xlsx": "x-office-spreadsheet",
                "pptx": "x-office-presentation", "svg": "image-svg+xml" }
            return Quickshell.iconPath(m[e] || (isImg(n) ? "image-x-generic" : "text-x-generic"), "text-x-generic")
        }

        // ================= modeller ve süreçler =================
        FolderListModel {
            id: src
            folder: "file://" + win.dir
            showHidden: win.showHidden
            showDirsFirst: true
            showDotAndDotDot: false
            caseSensitive: false
            nameFilters: win.query ? ["*" + win.query + "*"] : []
            sortField: [FolderListModel.Name, FolderListModel.Time, FolderListModel.Size, FolderListModel.Type][win.sortMode]
            sortReversed: win.sortMode === 1 || win.sortMode === 2 ? !win.sortDesc : win.sortDesc
        }
        // gizlenen dosyaları süzen katman; görünümler ve fm.get() bunu kullanır
        SortFilterProxyModel {
            id: fm
            model: src
            property int count: 0
            readonly property int status: src.status
            function get(i, role) { return src.get(mapToSource(index(i, 0)).row, role) }
            function indexOf(url) { const r = src.indexOf(url); return r < 0 ? -1 : mapFromSource(src.index(r, 0)).row }
            function recount() { count = rowCount(); if (win.curIdx >= count) win.curIdx = count - 1 }
            onRowsInserted: recount()
            onRowsRemoved: recount()
            onModelReset: recount()
            onLayoutChanged: recount()
            filters: FunctionFilter {
                function filter(fileName: string): bool {
                    if (win.alwaysHidden[win.dir + "/" + fileName]) return false
                    return win.showHidden || !win.hiddenNames[fileName]
                }
            }
        }
        Process {
            id: hidRead
            command: ["sh", "-c", 'cat -- "$1/.hidden" 2>/dev/null; true', "sh", win.dir]
            stdout: StdioCollector {
                onStreamFinished: {
                    const m = {}
                    this.text.split("\n").forEach(l => { if (l.trim()) m[l] = true })
                    win.hiddenNames = m
                }
            }
        }

        Component {
            id: opProc
            Process {
                id: pr
                property string okMsg: ""
                stderr: StdioCollector { id: err }
                onExited: code => {
                    win.loadHidden()
                    if (code === 0) { if (pr.okMsg) win.toast(pr.okMsg) }
                    else win.toast("olmadı (=；ω；=) " + (err.text.trim().split("\n")[0] || ""))
                    pr.destroy()
                }
            }
        }

        Process {
            id: owQuery
            stdout: StdioCollector {
                onStreamFinished: {
                    try { const d = JSON.parse(this.text); owDlg.mime = d.mime; owDlg.def = d.default; owDlg.apps = d.apps; owDlg.recent = d.recent || [] }
                    catch (e) { owDlg.shown = false; win.toast("uygulamalar okunamadı (=；ω；=)") }
                }
            }
        }

        Process {
            id: df
            command: ["df", "-B1", "--output=avail,size", win.dir]
            stdout: StdioCollector {
                onStreamFinished: {
                    const l = this.text.trim().split("\n").pop().trim().split(/\s+/)
                    win.freeText = l.length === 2 ? win.human(+l[0]) + " boş / " + win.human(+l[1]) : ""
                }
            }
        }
        Component.onCompleted: { df.running = true; drives.running = true; loadHidden(); keys.forceActiveFocus() }

        // bağlı diskler (kenar çubuğu)
        property var driveList: []
        Process {
            id: drives
            command: ["findmnt", "-rnb", "-o", "TARGET,SIZE,USED,LABEL", "-t", "ext4,btrfs,xfs,f2fs,ntfs3,ntfs,fuseblk,vfat,exfat"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const out = []
                    this.text.trim().split("\n").forEach(l => {
                        const f = l.split(" ")
                        if (f.length < 3) return
                        const t = f[0].replace(/\\x20/g, " ")
                        if (t.startsWith("/boot") || t.startsWith("/efi") || t.startsWith("/var") || t.startsWith("/snap")) return
                        const label = (f[3] || "").replace(/\\x20/g, " ")
                        out.push({ path: t, name: t === "/" ? "Sistem" : (label || t.split("/").pop()), size: +f[1], used: +f[2] })
                    })
                    win.driveList = out
                }
            }
        }
        Timer { interval: 8000; running: true; repeat: true; onTriggered: { drives.running = true; df.running = true } }

        // ---- şifreli kasalar (gocryptfs vb.): açılınca sol tarafta ayrı bölümde görünür ----
        property var vaultList: []
        Process {
            id: vaults
            running: true
            command: ["findmnt", "-rnb", "-o", "TARGET,SIZE,USED,FSTYPE", "-t", "fuse.gocryptfs,fuse.cryfs,fuse.securefs,fuse.encfs"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const out = []
                    this.text.trim().split("\n").forEach(l => {
                        const f = l.split(" ")
                        if (f.length < 4) return
                        const t = f[0].replace(/\\x20/g, " ")
                        out.push({ path: t, name: t.split("/").pop(), size: +f[1], used: +f[2], kind: f[3].replace("fuse.", "") })
                    })
                    if (JSON.stringify(out) !== JSON.stringify(win.vaultList)) win.vaultList = out
                }
            }
        }
        Timer { interval: 2000; running: true; repeat: true; onTriggered: vaults.running = true }
        function lockVault(path) {
            // kasanın içindeysen önce dışarı çık, yoksa "meşgul" der
            if (dir === path || dir.startsWith(path + "/")) go(path.replace(/\/[^\/]+$/, "") || "/")
            const p = opProc.createObject(win, { okMsg: "kasa kilitlendi ฅ^•ω•^ฅ" })
            p.command = ["sh", "-c", 'sleep 0.3; fusermount3 -u -- "$1" 2>/dev/null || fusermount -u -- "$1"', "sh", path]
            p.running = true
            p.exited.connect(() => { vaults.running = true })
        }

        // ================= arayüz =================
        Item {
            id: keys
            anchors.fill: parent
            focus: true

            Keys.onPressed: e => {
                const ctrl = e.modifiers & Qt.ControlModifier, alt = e.modifiers & Qt.AltModifier, shift = e.modifiers & Qt.ShiftModifier
                const cols = win.grid ? Math.max(1, Math.floor(gridView.width / gridView.cellWidth)) : 1
                const move = d => {
                    if (!fm.count) return
                    const n = Math.max(0, Math.min(fm.count - 1, (win.curIdx < 0 ? (d > 0 ? -1 : fm.count) : win.curIdx) + d))
                    win.clickItem(n, shift ? Qt.ShiftModifier : 0)
                    if (!shift) win.anchorIdx = n
                    ;(win.grid ? gridView : listView).positionViewAtIndex(n, GridView.Contain)
                }
                if (ctrl && e.key === Qt.Key_C) win.copySel(false)
                else if (ctrl && e.key === Qt.Key_X) win.copySel(true)
                else if (ctrl && e.key === Qt.Key_V) win.paste()
                else if (ctrl && e.key === Qt.Key_A) win.selectAll()
                else if (ctrl && (e.modifiers & Qt.ShiftModifier) && e.key === Qt.Key_H) win.hideSel(!win.selected().every(p => win.hiddenNames[p.replace(/^.*\//, "")] === true))
                else if (ctrl && e.key === Qt.Key_H) win.showHidden = !win.showHidden
                else if (ctrl && e.key === Qt.Key_L) crumbs.edit()
                else if (ctrl && e.key === Qt.Key_F) searchInput.forceActiveFocus()
                else if (ctrl && shift && e.key === Qt.Key_N) win.newFolder()
                else if (ctrl && e.key === Qt.Key_W) Ui.filesOpen = false
                else if (ctrl && e.key === Qt.Key_1) win.grid = true
                else if (ctrl && e.key === Qt.Key_2) win.grid = false
                else if (e.key === Qt.Key_F2) win.startRename()
                else if (e.key === Qt.Key_F4) win.terminalHere()
                else if (e.key === Qt.Key_Delete) shift ? win.deleteSel() : win.trashSel()
                else if (e.key === Qt.Key_Backspace || (alt && e.key === Qt.Key_Up)) win.up()
                else if (alt && e.key === Qt.Key_Left) win.back()
                else if (alt && e.key === Qt.Key_Right) win.forward()
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (win.selCount === 1) win.openIdx(win.curIdx) }
                else if (e.key === Qt.Key_Escape) { if (win.dragging) { win.dragging = false; win.dropTarget = "" } else if (dropMenu.shown) dropMenu.shown = false; else if (owDlg.shown) owDlg.shown = false; else if (confirm.shown) confirm.shown = false; else if (ctx.shown) ctx.shown = false; else if (win.query) win.query = ""; else if (win.selCount) win.clearSel(); else Ui.filesOpen = false }
                else if (e.key === Qt.Key_Right) move(1)
                else if (e.key === Qt.Key_Left) move(-1)
                else if (e.key === Qt.Key_Down) move(cols)
                else if (e.key === Qt.Key_Up) move(-cols)
                else if (e.key === Qt.Key_Home) move(-fm.count)
                else if (e.key === Qt.Key_End) move(fm.count)
                else if (e.text && /^[^\x00-\x1F\x7F]$/.test(e.text) && !ctrl && !alt) { searchInput.text += e.text; searchInput.forceActiveFocus() }
                else return
                e.accepted = true
            }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ---------------- kenar çubuğu ----------------
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 224
                color: Theme.frameColor
                Behavior on color { ColorAnimation { duration: 500 } }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 12
                    contentHeight: side.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: side
                        width: parent.width
                        spacing: 2

                        // başlık
                        RowLayout {
                            Layout.bottomMargin: 14
                            Layout.leftMargin: 4
                            spacing: 10
                            Mascot { kind: "workspace"; Layout.preferredWidth: 36; Layout.preferredHeight: 36 }
                            ColumnLayout {
                                spacing: -2
                                Txt { text: "File Manager"; size: 18; font.weight: Font.Black }
                                Txt { text: "dosyalarım"; size: 11; color: Theme.pink }
                            }
                        }

                        SideLabel { text: "yerler" }
                        Repeater {
                            model: [
                                { name: "Ev", icon: Theme.home, path: win.home },
                                { name: "Masaüstü", icon: Theme.desktop, path: win.home + "/Desktop" },
                                { name: "Belgeler", icon: Theme.file, path: win.home + "/Documents" },
                                { name: "İndirilenler", icon: Theme.download, path: win.home + "/Downloads" },
                                { name: "Resimler", icon: Theme.image, path: win.home + "/Pictures" },
                                { name: "Müzik", icon: Theme.music, path: win.home + "/Music" },
                                { name: "Videolar", icon: Theme.play, path: win.home + "/Videos" },
                                { name: "Çöp", icon: Theme.cp(0xf0a7a), path: win.trashDir }
                            ]
                            delegate: SideItem { required property var modelData; label: modelData.name; glyph: modelData.icon; path: modelData.path }
                        }

                        SideLabel { text: "diskler"; Layout.topMargin: 12 }
                        Repeater {
                            model: win.driveList
                            delegate: SideItem {
                                required property var modelData
                                label: modelData.name; glyph: Theme.disk; path: modelData.path
                                usage: modelData.size > 0 ? modelData.used / modelData.size : -1
                                sub: win.human(modelData.size - modelData.used) + " boş"
                            }
                        }

                        SideLabel { visible: win.vaultList.length > 0; text: "şifreli kasalar"; Layout.topMargin: 12 }
                        Repeater {
                            model: win.vaultList
                            delegate: SideItem {
                                required property var modelData
                                label: modelData.name; glyph: Theme.lockOpen; path: modelData.path
                                sub: modelData.kind
                                actGlyph: Theme.lock; actTip: "kilitle"
                                onAct: win.lockVault(modelData.path)
                            }
                        }
                    }
                }
            }

            // ---------------- ana alan ----------------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // üst çubuk
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 12
                    Layout.bottomMargin: 6
                    spacing: 6

                    IconButton { icon: Theme.left; enabled: win.backStack.length > 0; opacity: enabled ? 1 : 0.35; onClicked: win.back() }
                    IconButton { icon: Theme.right; enabled: win.fwdStack.length > 0; opacity: enabled ? 1 : 0.35; onClicked: win.forward() }
                    IconButton { icon: Theme.upDir; enabled: win.dir !== "/"; opacity: enabled ? 1 : 0.35; onClicked: win.up() }

                    // yol çubuğu (tıkla → yaz)
                    Rectangle {
                        id: crumbs
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 19
                        color: Theme.surface
                        border.width: pathInput.activeFocus ? 1.5 : 1
                        border.color: pathInput.activeFocus ? Theme.pink : Theme.border
                        Behavior on color { ColorAnimation { duration: 500 } }
                        property bool editing: false
                        function edit() { editing = true; pathInput.text = win.dir; pathInput.selectAll(); pathInput.forceActiveFocus() }

                        MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: crumbs.edit() }

                        Flickable {
                            id: crumbFlick
                            visible: !crumbs.editing
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            contentWidth: crumbRow.implicitWidth
                            clip: true
                            flickableDirection: Flickable.HorizontalFlick
                            onContentWidthChanged: contentX = Math.max(0, contentWidth - width)
                            Row {
                                id: crumbRow
                                height: parent.height
                                spacing: 2
                                Repeater {
                                    model: {
                                        const parts = win.dir.split("/").filter(x => x)
                                        const out = [{ name: "/", path: "/" }]
                                        let acc = ""
                                        parts.forEach(p => { acc += "/" + p; out.push({ name: acc === win.home ? "~" : p, path: acc }) })
                                        // ev klasörünün üstünü gizle
                                        const h = out.findIndex(o => o.path === win.home)
                                        return h > 0 ? out.slice(h) : out
                                    }
                                    delegate: Row {
                                        required property var modelData
                                        required property int index
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Icon { visible: index > 0; text: Theme.right; size: 12; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            implicitWidth: ct.implicitWidth + 16; implicitHeight: 26; radius: 13
                                            readonly property bool last: modelData.path === win.dir
                                            color: last ? Qt.alpha(Theme.pink, 0.16) : cma.containsMouse ? Theme.surface3 : "transparent"
                                            Behavior on color { ColorAnimation { duration: 140 } }
                                            Txt { id: ct; anchors.centerIn: parent; text: modelData.name; size: 13; color: parent.last ? Theme.pink : Theme.subtext; font.weight: parent.last ? Font.Black : Font.DemiBold }
                                            MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.go(modelData.path) }
                                        }
                                    }
                                }
                            }
                        }
                        TextInput {
                            id: pathInput
                            visible: crumbs.editing
                            anchors.fill: parent
                            anchors.leftMargin: 16; anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            selectionColor: Qt.alpha(Theme.pink, 0.4)
                            font.family: Theme.mono; font.pixelSize: 13
                            clip: true
                            onActiveFocusChanged: if (!activeFocus) crumbs.editing = false
                            Keys.onReturnPressed: { const t = text.replace(/^~/, win.home); crumbs.editing = false; win.go(t) }
                            Keys.onEscapePressed: { crumbs.editing = false; keys.forceActiveFocus() }
                        }
                    }

                    // arama
                    Rectangle {
                        implicitWidth: searchInput.activeFocus || win.query ? 230 : 150
                        Behavior on implicitWidth { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmphDecel } }
                        implicitHeight: 38
                        radius: 19
                        color: Theme.surface
                        border.width: searchInput.activeFocus ? 1.5 : 1
                        border.color: searchInput.activeFocus ? Theme.pink : Theme.border
                        Behavior on color { ColorAnimation { duration: 500 } }
                        Icon { id: sIcon; x: 12; anchors.verticalCenter: parent.verticalCenter; text: Theme.search; size: 15; color: Theme.purple }
                        TextInput {
                            id: searchInput
                            anchors.left: sIcon.right; anchors.leftMargin: 8
                            anchors.right: parent.right; anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.text
                            selectionColor: Qt.alpha(Theme.pink, 0.4)
                            font.family: Theme.font; font.pixelSize: 13
                            clip: true
                            onTextChanged: win.query = text
                            Keys.onEscapePressed: { text = ""; keys.forceActiveFocus() }
                            Keys.onReturnPressed: { if (fm.count) { win.clickItem(0, 0); keys.forceActiveFocus() } }
                            Keys.onDownPressed: { if (fm.count) { win.clickItem(0, 0); keys.forceActiveFocus() } }
                            Txt { visible: !parent.text; text: "ara~"; size: 13; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Connections { target: win; function onQueryChanged() { if (searchInput.text !== win.query) searchInput.text = win.query } }
                    }

                    Rectangle { width: 1; height: 22; color: Theme.border; Layout.leftMargin: 2; Layout.rightMargin: 2 }
                    IconButton { icon: win.showHidden ? Theme.cp(0xf0208) : Theme.cp(0xf0209); active: win.showHidden; onClicked: win.showHidden = !win.showHidden }
                    // sıralama: tıkla → sonraki, sağ tık → yön
                    Rectangle {
                        implicitWidth: sortRow.implicitWidth + 20; implicitHeight: 34; radius: 17
                        color: sortMa.containsMouse ? Theme.surface3 : Theme.surface
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Row {
                            id: sortRow; anchors.centerIn: parent; spacing: 6
                            Icon { text: win.sortDesc ? Theme.down : Theme.up; size: 14; color: Theme.pink; anchors.verticalCenter: parent.verticalCenter }
                            Txt { text: win.sortNames[win.sortMode]; size: 12; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: sortMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: m => { if (m.button === Qt.RightButton) win.sortDesc = !win.sortDesc; else win.sortMode = (win.sortMode + 1) % 4 }
                        }
                    }
                    // görünüm
                    Rectangle {
                        implicitWidth: 74; implicitHeight: 34; radius: 17
                        color: Theme.surface
                        Rectangle {
                            width: 34; height: 30; radius: 15; y: 2
                            x: win.grid ? 2 : 38
                            Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }
                            gradient: Gradient { GradientStop { position: 0; color: Theme.pink } GradientStop { position: 1; color: Theme.purple } }
                        }
                        Row {
                            anchors.fill: parent; anchors.margins: 2
                            Item { width: 36; height: 30; Icon { anchors.centerIn: parent; text: Theme.cp(0xf0570); size: 15; color: win.grid ? Theme.bg : Theme.subtext }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.grid = true } }
                            Item { width: 36; height: 30; Icon { anchors.centerIn: parent; text: Theme.cp(0xf0572); size: 15; color: !win.grid ? Theme.bg : Theme.subtext }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.grid = false } }
                        }
                    }
                    IconButton { icon: Theme.cp(0xf06fe); active: win.preview; onClicked: win.preview = !win.preview }
                }

                // içerik + önizleme
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Rectangle {
                        id: content
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: 12
                        Layout.rightMargin: win.preview ? 6 : 12
                        Layout.bottomMargin: 6
                        radius: Theme.radius
                        color: Theme.surface
                        Behavior on color { ColorAnimation { duration: 500 } }
                        clip: true

                        // boş alana tıklama / sağ tık (hücreler kendi tıklamalarını alır)
                        TapHandler {
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onTapped: (ev, button) => {
                                keys.forceActiveFocus()
                                if (button === Qt.RightButton) { const p = content.mapToItem(keys, ev.position.x, ev.position.y); ctx.openAt(p.x, p.y, false) }
                                else win.clearSel()
                            }
                        }

                        GridView {
                            id: gridView
                            visible: win.grid
                            anchors.fill: parent
                            anchors.margins: 10
                            model: fm
                            clip: true
                            cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 128)))
                            cellHeight: 138
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: true
                            delegate: FileCell { gridMode: true; width: gridView.cellWidth; height: gridView.cellHeight }
                            // add/displaced geçişleri yok: pencere boyutlanırken yarıda kalıp hücreleri
                            // eski yerlerinde bırakıyordu (üst üste binme). Giriş animasyonunu FileCell yapıyor.
                            onWidthChanged: relayout.restart()
                            onCellWidthChanged: relayout.restart()
                            Timer { id: relayout; interval: 90; onTriggered: gridView.forceLayout() }
                        }

                        ColumnLayout {
                            visible: !win.grid
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4
                            // sütun başlıkları
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 48; Layout.rightMargin: 14
                                Txt { text: "ad"; size: 11; color: Theme.muted; Layout.fillWidth: true }
                                Txt { text: "değiştirilme"; size: 11; color: Theme.muted; Layout.preferredWidth: 130 }
                                Txt { text: "boyut"; size: 11; color: Theme.muted; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
                            }
                            ListView {
                                id: listView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: fm
                                clip: true
                                spacing: 2
                                boundsBehavior: Flickable.StopAtBounds
                                delegate: FileCell { gridMode: false; width: listView.width; height: 40 }
                            }
                        }

                        // boş klasör / arama sonucu yok
                        Column {
                            anchors.centerIn: parent
                            spacing: 10
                            visible: fm.status === FolderListModel.Ready && fm.count === 0
                            opacity: visible ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 240 } }
                            Mascot { kind: "sleep"; width: 120; height: 100; anchors.horizontalCenter: parent.horizontalCenter }
                            Txt {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: win.query ? "\"" + win.query + "\" bulunamadı (=･ω･=)?" : win.inTrash ? "çöp bomboş, tertemiz~" : "burası bomboş (=･ω･=)"
                                size: 14; color: Theme.subtext
                            }
                        }
                    }

                    // ---------------- önizleme paneli ----------------
                    Rectangle {
                        id: pv
                        Layout.fillHeight: true
                        Layout.preferredWidth: win.preview ? 270 : 0
                        Layout.rightMargin: win.preview ? 12 : 0
                        Layout.bottomMargin: 6
                        Behavior on Layout.preferredWidth { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmphDecel } }
                        visible: Layout.preferredWidth > 1
                        radius: Theme.radius
                        color: Theme.surface
                        Behavior on color { ColorAnimation { duration: 500 } }
                        clip: true

                        readonly property string one: win.selCount === 1 ? (win.selected()[0] || "") : ""
                        readonly property int oneIdx: one && fm.count >= 0 ? fm.indexOf("file://" + one) : -1
                        readonly property string oneName: one ? String(one).split("/").pop() : ""
                        readonly property bool oneDir: oneIdx >= 0 && fm.get(oneIdx, "fileIsDir")
                        readonly property real totalSize: {
                            let t = 0; const s = win.sel
                            for (let i = 0; i < fm.count; i++) if (s[fm.get(i, "filePath")] && !fm.get(i, "fileIsDir")) t += fm.get(i, "fileSize")
                            return t
                        }

                        ColumnLayout {
                            width: 246
                            x: 12; y: 14
                            spacing: 10

                            // büyük önizleme
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 200
                                radius: 14
                                color: Theme.surface2
                                clip: true
                                Image {
                                    id: bigImg
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    visible: pv.one !== "" && win.isImg(pv.oneName)
                                    source: visible ? "file://" + pv.one : ""
                                    sourceSize: Qt.size(480, 400)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    opacity: status === Image.Ready ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                                Image {
                                    anchors.centerIn: parent
                                    width: 96; height: 96
                                    visible: !bigImg.visible && pv.one !== ""
                                    source: visible ? win.iconFor(pv.oneName, pv.oneDir) : ""
                                    sourceSize: Qt.size(192, 192)
                                    // klasör ikonları temanın rengine boyanır (tema değişince yumuşakça geçer)
                                    layer.enabled: pv.oneDir
                                    layer.effect: MultiEffect { colorization: 1.0; colorizationColor: Theme.pink; brightness: 0.06; saturation: 0.15 }
                                }
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    visible: pv.one === ""
                                    Mascot { kind: win.selCount > 1 ? "spin" : "workspace"; width: 72; height: 72; anchors.horizontalCenter: parent.horizontalCenter }
                                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: win.selCount > 1 ? win.selCount + " öğe seçili" : win.dirName; size: 15; font.weight: Font.Black }
                                }
                            }

                            Txt {
                                Layout.fillWidth: true
                                text: pv.one ? pv.oneName : win.selCount > 1 ? "toplam " + win.human(pv.totalSize) : fm.count + " öğe"
                                size: 15; font.weight: Font.Black
                                wrapMode: Text.WrapAnywhere; maximumLineCount: 3; elide: Text.ElideRight
                            }
                            // bilgi satırları
                            Repeater {
                                model: pv.oneIdx >= 0 ? [
                                    { k: "tür", v: win.kind(pv.oneName, pv.oneDir) },
                                    { k: "boyut", v: pv.oneDir ? "—" : win.human(fm.get(pv.oneIdx, "fileSize")) },
                                    { k: "değişti", v: Qt.formatDateTime(fm.get(pv.oneIdx, "fileModified"), "d MMM yyyy  hh:mm") },
                                    { k: "konum", v: win.dir.replace(win.home, "~") }
                                ] : [
                                    { k: "konum", v: win.dir.replace(win.home, "~") },
                                    { k: "disk", v: win.freeText || "—" }
                                ]
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Txt { text: modelData.k; size: 12; color: Theme.muted; Layout.preferredWidth: 58 }
                                    Txt { text: modelData.v !== undefined ? String(modelData.v) : ""; size: 12; color: Theme.subtext; Layout.fillWidth: true; elide: Text.ElideMiddle }
                                }
                            }
                            // hızlı işlemler
                            Flow {
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                spacing: 6
                                visible: win.selCount > 0
                                Pill { text: "aç"; glyph: Theme.folderOpen; visible: win.selCount === 1; onClicked: win.openIdx(pv.oneIdx) }
                                Pill { text: "birlikte aç"; glyph: Theme.apps; visible: win.selCount === 1 && !pv.oneDir; onClicked: win.openWith() }
                                Pill { text: "kopyala"; glyph: Theme.copy; onClicked: win.copySel(false) }
                                Pill { text: "kes"; glyph: Theme.cp(0xf0190); onClicked: win.copySel(true) }
                                Pill { text: "ad"; glyph: Theme.tag; visible: win.selCount === 1; onClicked: win.startRename() }
                                Pill { text: win.inTrash ? "sil" : "çöpe"; glyph: Theme.cp(0xf0a7a); danger: true; onClicked: win.trashSel() }
                            }
                        }
                    }
                }

                // durum çubuğu
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 18; Layout.rightMargin: 18
                    Layout.bottomMargin: 8; Layout.topMargin: 2
                    spacing: 14
                    Txt { text: fm.count + " öğe" + (win.selCount ? "  ·  " + win.selCount + " seçili" : ""); size: 12; color: Theme.subtext }
                    Txt { visible: win.clip.paths.length > 0; text: (win.clip.mode === "move" ? "✂ " : "⧉ ") + win.clip.paths.length + " öğe panoda"; size: 12; color: Theme.pink }
                    Item { Layout.fillWidth: true }
                    Txt { text: win.freeText; size: 12; color: Theme.muted }
                    Txt { visible: win.inTrash && fm.count > 0; text: "çöpü boşalt"; size: 12; color: Theme.red
                          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: confirm.ask("Çöp tamamen boşaltılsın mı?", () => win.run(["emptytrash"], "çöp boşaltıldı")) } }
                }
            }
        }

        // ================= sürükleme hayaleti =================
        Rectangle {
            id: ghost
            z: 50
            visible: opacity > 0
            opacity: win.dragging ? 0.95 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            x: win.dragPos.x + 14; y: win.dragPos.y + 10
            width: ghostRow.implicitWidth + 24; height: 38; radius: 19
            color: Theme.surface2
            border.width: 1.5
            border.color: win.dropTarget ? Theme.pink : Theme.border
            scale: win.dropTarget ? 1.06 : 1
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
            RowLayout {
                id: ghostRow
                anchors.centerIn: parent
                spacing: 8
                Icon { text: win.dragPaths.length > 1 ? Theme.copy : Theme.file; size: 15; color: Theme.pink }
                Txt {
                    size: 12
                    color: Theme.text
                    text: {
                        const what = win.dragPaths.length > 1 ? win.dragPaths.length + " öğe" : String(win.dragPaths[0] || "").split("/").pop()
                        if (!win.dropTarget) return what
                        const to = win.dropTarget === win.trashDir ? "Çöp" : win.dropTarget.split("/").pop()
                        const verb = win.dropTarget === win.trashDir ? "çöpe at" : win.dragBtn === Qt.RightButton ? "→ " + to + "…" : "→ " + to
                        return what + "  " + verb
                    }
                }
            }
        }

        // ================= bırakma menüsü (sağ tuşla sürükleyince) =================
        MouseArea {
            anchors.fill: parent
            z: 60
            visible: dropMenu.shown
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: dropMenu.shown = false
            onWheel: w => w.accepted = true   // tekerlek arkadaki listeye geçmesin
        }
        Rectangle {
            id: dropMenu
            z: 61
            property bool shown: false
            property string target: ""
            property var paths: []
            property real ax: 0
            property real ay: 0
            function openAt(px, py, t, ps) { target = t; paths = ps; ax = px; ay = py; shown = true }
            x: Math.max(8, Math.min(ax, win.width - width - 8))
            y: ay + height > win.height - 8 ? Math.max(8, ay - height) : ay
            width: 230
            height: dmCol.implicitHeight + 12
            radius: 14
            color: Theme.surface2
            border.width: 1
            border.color: Theme.border
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.92
            transformOrigin: Item.TopLeft
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "black"; shadowBlur: 0.8; shadowOpacity: 0.6; shadowVerticalOffset: 4 }
            Column {
                id: dmCol
                x: 6; y: 6
                width: parent.width - 12
                Txt { width: parent.width; leftPadding: 10; topPadding: 4; bottomPadding: 6; size: 11; color: Theme.muted; elide: Text.ElideMiddle
                      text: (dropMenu.paths.length > 1 ? dropMenu.paths.length + " öğe" : "") + " → " + (dropMenu.target === win.trashDir ? "Çöp" : dropMenu.target.split("/").pop()) }
                CtxItem { text: "Buraya taşı"; glyph: Theme.cp(0xf0190); shownIf: dropMenu.target !== win.trashDir; onRun: { dropMenu.shown = false; win.dropDo(dropMenu.target, dropMenu.paths, "move") } }
                CtxItem { text: "Buraya kopyala"; glyph: Theme.copy; shownIf: dropMenu.target !== win.trashDir; onRun: { dropMenu.shown = false; win.dropDo(dropMenu.target, dropMenu.paths, "copy") } }
                CtxItem { text: "Çöpe at"; glyph: Theme.cp(0xf0a7a); danger: true; shownIf: dropMenu.target === win.trashDir; onRun: { dropMenu.shown = false; win.dropDo(dropMenu.target, dropMenu.paths, "move") } }
                CtxSep {}
                CtxItem { text: "Vazgeç"; glyph: Theme.close; onRun: dropMenu.shown = false }
            }
        }

        // ================= sağ tık menüsü =================
        MouseArea {
            anchors.fill: parent
            visible: ctx.shown
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: ctx.shown = false
            onWheel: w => w.accepted = true   // tekerlek arkadaki listeye geçmesin
        }
        Rectangle {
            id: ctx
            property bool shown: false
            property bool onItem: false
            // konum bağlamalı: menünün boyu (Column) sonradan hesaplandığı için açılırken sabitlemek
            // ekranın dışına taşırıyordu. Aşağı sığmazsa imlecin üstüne açılır.
            property real ax: 0
            property real ay: 0
            function openAt(px, py, item) { onItem = item; ax = px; ay = py; shown = true }
            x: Math.max(8, Math.min(ax, win.width - width - 8))
            y: ay + height > win.height - 8 ? Math.max(8, ay - height) : ay
            transformOrigin: ay + height > win.height - 8 ? Item.BottomLeft : Item.TopLeft
            width: 210
            height: ctxCol.implicitHeight + 12
            radius: 14
            color: Theme.surface2
            border.width: 1
            border.color: Theme.border
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.92
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "black"; shadowBlur: 0.8; shadowOpacity: 0.6; shadowVerticalOffset: 4 }

            Column {
                id: ctxCol
                x: 6; y: 6
                width: parent.width - 12
                CtxItem { text: "Aç"; glyph: Theme.folderOpen; shownIf: ctx.onItem && win.selCount === 1; onRun: win.openIdx(win.curIdx) }
                CtxItem { text: "Birlikte aç…"; glyph: Theme.apps; shownIf: ctx.onItem && win.selCount === 1 && !pv.oneDir; onRun: win.openWith() }
                CtxItem { text: "Kopyala"; glyph: Theme.copy; key: "Ctrl+C"; shownIf: ctx.onItem; onRun: win.copySel(false) }
                CtxItem { text: "Kes"; glyph: Theme.cp(0xf0190); key: "Ctrl+X"; shownIf: ctx.onItem; onRun: win.copySel(true) }
                CtxItem { text: "Yapıştır"; glyph: Theme.cp(0xf0192); key: "Ctrl+V"; shownIf: !win.inTrash; onRun: win.paste() }
                CtxItem { text: "Yeniden adlandır"; glyph: Theme.tag; key: "F2"; shownIf: ctx.onItem && win.selCount === 1; onRun: win.startRename() }
                CtxItem { text: "Gizle"; glyph: Theme.cp(0xf0209); key: "Ctrl+⇧+H"; shownIf: ctx.onItem && !win.inTrash && win.selected().some(p => !win.isHiddenName(p.replace(/^.*\//, ""))); onRun: win.hideSel(true) }
                CtxItem { text: "Gizlemeyi kaldır"; glyph: Theme.cp(0xf0208); key: "Ctrl+⇧+H"; shownIf: ctx.onItem && win.selected().some(p => win.hiddenNames[p.replace(/^.*\//, "")] === true); onRun: win.hideSel(false) }
                CtxItem { text: "Yolu kopyala"; glyph: Theme.cp(0xf0337); onRun: win.copyPath() }
                CtxSep {}
                CtxItem { text: "Yeni klasör"; glyph: Theme.cp(0xf0257); key: "Ctrl+⇧+N"; shownIf: !ctx.onItem && !win.inTrash; onRun: win.newFolder() }
                CtxItem { text: "Yeni metin dosyası"; glyph: Theme.cp(0xf0752); shownIf: !ctx.onItem && !win.inTrash; onRun: win.newFile() }
                CtxItem { text: "Terminalde aç"; glyph: Theme.terminal; key: "F4"; onRun: win.terminalHere() }
                CtxItem { text: win.showHidden ? "Gizlileri sakla" : "Gizlileri göster"; glyph: Theme.cp(0xf0208); key: "Ctrl+H"; shownIf: !ctx.onItem; onRun: win.showHidden = !win.showHidden }
                CtxSep { visible: ctx.onItem }
                CtxItem { text: win.inTrash ? "Kalıcı sil" : "Çöpe at"; glyph: Theme.cp(0xf0a7a); key: "Del"; danger: true; shownIf: ctx.onItem; onRun: win.trashSel() }
                CtxItem { text: "Kalıcı sil"; glyph: Theme.alert; key: "⇧+Del"; danger: true; shownIf: ctx.onItem && !win.inTrash; onRun: win.deleteSel() }
            }
        }

        // ================= onay penceresi =================
        Rectangle {
            id: confirm
            property var action: null
            property string text: ""
            property bool shown: false
            function ask(t, a) { text = t; action = a; shown = true }
            anchors.fill: parent
            color: Qt.alpha("black", shown ? 0.45 : 0)
            Behavior on color { ColorAnimation { duration: 180 } }
            visible: shown || color.a > 0.01
            MouseArea { anchors.fill: parent; onClicked: confirm.shown = false; onWheel: w => w.accepted = true }
            Rectangle {
                anchors.centerIn: parent
                width: 380; height: 170; radius: 20
                color: Theme.surface2
                border.width: 1; border.color: Qt.alpha(Theme.red, 0.5)
                scale: confirm.shown ? 1 : 0.9
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }
                MouseArea { anchors.fill: parent; onWheel: w => w.accepted = true }
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 20; spacing: 12
                    RowLayout { spacing: 10
                        Icon { text: Theme.alert; size: 22; color: Theme.red }
                        Txt { text: confirm.text; size: 14; wrapMode: Text.Wrap; Layout.fillWidth: true } }
                    Item { Layout.fillHeight: true }
                    RowLayout { Layout.alignment: Qt.AlignRight; spacing: 8
                        Pill { text: "vazgeç"; onClicked: confirm.shown = false }
                        Pill { text: "evet, sil"; danger: true; filled: true; onClicked: { confirm.shown = false; if (confirm.action) confirm.action() } } }
                }
            }
            Keys.onEscapePressed: shown = false
        }

        // ================= birlikte aç =================
        Rectangle {
            id: owDlg
            property bool shown: false
            property string file: ""
            property string mime: ""
            property string def: ""
            property var apps: []
            property var recent: []
            property string cmd: ""
            property bool always: false
            // yazılan metne göre süzülmüş liste + bölüm başlıkları
            readonly property var rows: {
                const q = cmd.trim().toLowerCase()
                const f = apps.filter(a => !q || a.name.toLowerCase().includes(q) || (a.exec || "").toLowerCase().includes(q) || a.id.toLowerCase().includes(q))
                const good = f.filter(a => a.match > 0), other = f.filter(a => !a.match), out = []
                if (good.length) out.push({ hdr: "önerilen" }), good.forEach(a => out.push(a))
                if (other.length) out.push({ hdr: "her zaman burada" }), other.forEach(a => out.push(a))
                return out
            }
            anchors.fill: parent
            color: Qt.alpha("black", shown ? 0.45 : 0)
            Behavior on color { ColorAnimation { duration: 180 } }
            visible: shown || color.a > 0.01
            MouseArea { anchors.fill: parent; onClicked: owDlg.shown = false; onWheel: w => w.accepted = true }
            Rectangle {
                anchors.centerIn: parent
                width: 460; height: Math.min(620, parent.height - 60); radius: 22
                color: Theme.surface2
                border.width: 1; border.color: Theme.border
                scale: owDlg.shown ? 1 : 0.92
                opacity: owDlg.shown ? 1 : 0
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }
                Behavior on opacity { NumberAnimation { duration: 160 } }
                MouseArea { anchors.fill: parent; onWheel: w => w.accepted = true }
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 18; spacing: 10
                    RowLayout {
                        spacing: 10
                        Icon { text: Theme.apps; size: 20 }
                        ColumnLayout { spacing: 0; Layout.fillWidth: true
                            Txt { text: "Birlikte aç"; size: 17; font.weight: Font.Black }
                            Txt { text: owDlg.file.split("/").pop() + (owDlg.mime ? "  ·  " + owDlg.mime : ""); size: 11; color: Theme.subtext; elide: Text.ElideMiddle; Layout.fillWidth: true } }
                        IconButton { icon: Theme.close; onClicked: owDlg.shown = false }
                    }
                    // komut kutusu: yaz → listeyi süzer, Enter → terminaldeki gibi çalıştırır
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 42; radius: 21
                        color: Theme.surface
                        border.width: owInput.activeFocus ? 1.5 : 1
                        border.color: owInput.activeFocus ? Theme.pink : Theme.border
                        Behavior on border.color { ColorAnimation { duration: 140 } }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 6; spacing: 10
                            Icon { text: Theme.terminal; size: 16; color: owInput.activeFocus ? Theme.pink : Theme.subtext }
                            Item {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                TextInput {
                                    id: owInput
                                    anchors.fill: parent
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Theme.text
                                    selectionColor: Qt.alpha(Theme.pink, 0.4)
                                    font.family: Theme.font; font.pixelSize: 13
                                    clip: true
                                    text: owDlg.cmd
                                    onTextEdited: owDlg.cmd = text
                                    Keys.onReturnPressed: win.runCmd(text, owDlg.always)
                                    Keys.onEnterPressed: win.runCmd(text, owDlg.always)
                                    Keys.onEscapePressed: { owDlg.shown = false; keys.forceActiveFocus() }
                                }
                                Txt { anchors.verticalCenter: parent.verticalCenter; visible: !owInput.text; text: "komut yaz… (subl, nvim, ristretto, file-roller)"; size: 13; color: Theme.muted }
                            }
                            Rectangle {
                                visible: owInput.text.trim() !== ""
                                implicitWidth: runT.implicitWidth + 22; implicitHeight: 30; radius: 15
                                color: runMa.containsMouse ? Theme.pink : Qt.alpha(Theme.pink, 0.2)
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Txt { id: runT; anchors.centerIn: parent; text: "çalıştır ↵"; size: 12; font.weight: Font.Black; color: runMa.containsMouse ? Theme.bg : Theme.pink }
                                MouseArea { id: runMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.runCmd(owInput.text, owDlg.always) }
                            }
                        }
                    }
                    // son kullanılan komutlar
                    Flow {
                        Layout.fillWidth: true
                        visible: owDlg.recent.length > 0
                        spacing: 6
                        Repeater {
                            model: owDlg.recent
                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: rcT.implicitWidth + 20; implicitHeight: 26; radius: 13
                                color: rcMa.containsMouse ? Qt.alpha(Theme.pink, 0.2) : Theme.surface3
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Txt { id: rcT; anchors.centerIn: parent; text: "› " + modelData; size: 11; color: rcMa.containsMouse ? Theme.pink : Theme.subtext }
                                MouseArea { id: rcMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.runCmd(modelData, owDlg.always) }
                            }
                        }
                    }
                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true; spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        model: owDlg.rows
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool head: modelData.hdr !== undefined
                            width: ListView.view.width; height: head ? 28 : 52; radius: 14
                            readonly property bool isDef: !head && modelData.id === owDlg.def
                            Txt { visible: parent.head; anchors.left: parent.left; anchors.leftMargin: 8; anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                                  text: parent.head ? modelData.hdr : ""; size: 11; color: Theme.muted; font.weight: Font.Black; font.capitalization: Font.AllUppercase; font.letterSpacing: 1 }
                            color: appMa.containsMouse ? Qt.alpha(Theme.pink, 0.14) : isDef ? Theme.surface3 : "transparent"
                            border.width: appMa.containsMouse ? 1 : 0; border.color: Qt.alpha(Theme.pink, 0.6)
                            Behavior on color { ColorAnimation { duration: 120 } }
                            RowLayout {
                                visible: !parent.head
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
                                Image { Layout.preferredWidth: 30; Layout.preferredHeight: 30; sourceSize: Qt.size(60, 60)
                                        source: parent.parent.head ? "" : Quickshell.iconPath(modelData.icon || "", "application-x-executable"); asynchronous: true }
                                ColumnLayout { spacing: 0; Layout.fillWidth: true
                                    Txt { text: modelData.name || ""; size: 14; font.weight: Font.Bold; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Txt { visible: text !== ""; text: modelData.comment || ""; size: 11; color: Theme.muted; Layout.fillWidth: true; elide: Text.ElideRight } }
                                Rectangle { visible: parent.parent.isDef; implicitWidth: dt.implicitWidth + 14; implicitHeight: 22; radius: 11; color: Qt.alpha(Theme.pink, 0.2)
                                    Txt { id: dt; anchors.centerIn: parent; text: "varsayılan"; size: 10; color: Theme.pink; font.weight: Font.Black } }
                            }
                            MouseArea { id: appMa; enabled: !parent.head; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.launchWith(modelData.id, owDlg.always) }
                        }
                        Txt { anchors.centerIn: parent; visible: owDlg.mime !== "" && owDlg.rows.length === 0; text: owDlg.cmd ? "listede yok, Enter ile komut olarak çalıştır ↵" : "bunu açabilen uygulama yok (=･ω･=)?"; size: 13; color: Theme.subtext }
                        Txt { anchors.centerIn: parent; visible: owDlg.mime === ""; text: "uygulamalar aranıyor..."; size: 13; color: Theme.subtext }
                    }
                    // her zaman bununla aç
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 44; radius: 14
                        color: alMa.containsMouse ? Theme.surface3 : Theme.surface
                        Behavior on color { ColorAnimation { duration: 120 } }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 10
                            Rectangle {
                                implicitWidth: 38; implicitHeight: 22; radius: 11
                                color: owDlg.always ? Theme.pink : Theme.surface3
                                Behavior on color { ColorAnimation { duration: 160 } }
                                Rectangle { width: 16; height: 16; radius: 8; y: 3; x: owDlg.always ? 19 : 3; color: owDlg.always ? Theme.bg : Theme.subtext
                                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack } } }
                            }
                            Txt { text: "her zaman bununla aç" + (owDlg.mime ? " (" + owDlg.mime.split("/").pop() + ")" : ""); size: 13; Layout.fillWidth: true }
                        }
                        MouseArea { id: alMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: owDlg.always = !owDlg.always }
                    }
                }
            }
        }

        // ================= bildirim =================
        Rectangle {
            id: toastBox
            property string text: ""
            property bool shown: false
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - (shown ? 70 : 20)
            Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }
            opacity: shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            width: toastRow.implicitWidth + 32; height: 38; radius: 19
            gradient: Gradient { orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.pink } GradientStop { position: 1; color: Theme.purple } }
            Row { id: toastRow; anchors.centerIn: parent; spacing: 8
                Icon { text: Theme.paw; size: 15; color: Theme.bg; anchors.verticalCenter: parent.verticalCenter }
                Txt { text: toastBox.text; size: 13; color: Theme.bg; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter } }
            Timer { id: toastTimer; interval: 2200; onTriggered: toastBox.shown = false }
        }

        // ================= parçalar =================
        component SideLabel: Txt { size: 11; color: Theme.muted; font.weight: Font.Black; Layout.leftMargin: 10; Layout.bottomMargin: 4; font.capitalization: Font.AllUppercase; font.letterSpacing: 1 }

        component SideItem: Rectangle {
            id: si
            property string label
            property string glyph
            property string path
            property real usage: -1
            property string sub: ""
            property string actGlyph: ""          // sağda küçük düğme (ör. kasayı kilitle)
            property string actTip: ""
            signal act()
            readonly property bool here: win.dir === path || (actGlyph !== "" && win.dir.startsWith(path + "/"))
            readonly property bool dropHot: win.dragging && win.dropTarget === path
            Component.onCompleted: win.sideItems = win.sideItems.concat([si])
            Component.onDestruction: win.sideItems = win.sideItems.filter(x => x !== si)
            border.width: dropHot ? 1.5 : 0
            border.color: Theme.pink
            Layout.fillWidth: true
            implicitHeight: usage >= 0 ? 52 : 38
            radius: 12
            color: dropHot ? Qt.alpha(Theme.pink, 0.26) : here ? Qt.alpha(Theme.pink, 0.14) : sma.containsMouse ? Theme.surface2 : "transparent"
            Behavior on color { ColorAnimation { duration: 160 } }
            Rectangle { visible: si.here; width: 3; height: 18; radius: 2; color: Theme.pink; x: 2; anchors.verticalCenter: parent.verticalCenter }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: si.actGlyph !== "" ? 38 : 10; spacing: 10
                Icon { text: si.glyph; size: 17; color: si.here ? Theme.pink : Theme.purple }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    RowLayout {
                        Layout.fillWidth: true
                        Txt { text: si.label; size: 13; color: si.here ? Theme.text : Theme.subtext; Layout.fillWidth: true; elide: Text.ElideRight }
                        Txt { visible: si.sub !== ""; text: si.sub; size: 10; color: Theme.muted }
                    }
                    Rectangle {
                        visible: si.usage >= 0
                        Layout.fillWidth: true; implicitHeight: 4; radius: 2; color: Theme.surface3
                        Rectangle { width: parent.width * Math.max(0, Math.min(1, si.usage)); height: parent.height; radius: 2
                            color: si.usage > 0.9 ? Theme.red : Theme.pink
                            Behavior on width { NumberAnimation { duration: 400 } } }
                    }
                }
            }
            MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.go(si.path) }
            Rectangle {
                visible: si.actGlyph !== ""
                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                width: 26; height: 26; radius: 13
                color: ama.containsMouse ? Qt.alpha(Theme.pink, 0.22) : sma.containsMouse || si.here ? Theme.surface3 : "transparent"
                Behavior on color { ColorAnimation { duration: 140 } }
                scale: ama.pressed ? 0.88 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }
                Icon { anchors.centerIn: parent; text: si.actGlyph; size: 14; color: ama.containsMouse ? Theme.pink : Theme.subtext }
                MouseArea { id: ama; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: si.act() }
            }
        }

        component Pill: Rectangle {
            id: pl
            property string text
            property string glyph: ""
            property bool danger: false
            property bool filled: false
            signal clicked()
            implicitWidth: plRow.implicitWidth + 22; implicitHeight: 30; radius: 15
            color: filled ? (danger ? Theme.red : Theme.pink) : plMa.containsMouse ? (danger ? Qt.alpha(Theme.red, 0.18) : Theme.surface3) : Theme.surface3
            border.width: filled ? 0 : 1
            border.color: plMa.containsMouse ? (danger ? Theme.red : Theme.pink) : "transparent"
            scale: plMa.pressed ? 0.94 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 140 } }
            Row { id: plRow; anchors.centerIn: parent; spacing: 6
                Icon { visible: pl.glyph !== ""; text: pl.glyph; size: 13; color: pl.filled ? Theme.bg : pl.danger ? Theme.red : Theme.pink; anchors.verticalCenter: parent.verticalCenter }
                Txt { text: pl.text; size: 12; color: pl.filled ? Theme.bg : Theme.text; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter } }
            MouseArea { id: plMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pl.clicked() }
        }

        component CtxItem: Rectangle {
            id: ci
            property string text
            property string glyph
            property string key: ""
            property bool danger: false
            property bool shownIf: true
            signal run()
            visible: shownIf
            width: parent ? parent.width : 0
            height: visible ? 34 : 0
            radius: 9
            color: ciMa.containsMouse ? (danger ? Qt.alpha(Theme.red, 0.16) : Qt.alpha(Theme.pink, 0.14)) : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                Icon { text: ci.glyph; size: 15; color: ci.danger ? Theme.red : Theme.pink }
                Txt { text: ci.text; size: 13; color: ci.danger ? Theme.red : Theme.text; Layout.fillWidth: true }
                Txt { text: ci.key; size: 10; color: Theme.muted }
            }
            MouseArea { id: ciMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { ctx.shown = false; ci.run() } }
        }
        component CtxSep: Rectangle { width: parent ? parent.width : 0; height: visible ? 9 : 0; color: "transparent"
            Rectangle { anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Theme.border } }

        // dosya hücresi (ızgara + liste)
        component FileCell: Item {
            id: fc
            required property int index
            required property string fileName
            required property string filePath
            required property bool fileIsDir
            required property var fileSize
            required property var fileModified
            property bool gridMode: true
            readonly property bool picked: win.sel[filePath] === true
            readonly property bool cursor: win.curIdx === index
            readonly property bool img: !fileIsDir && win.isImg(fileName)
            readonly property bool cut: win.clip.mode === "move" && win.clip.paths.indexOf(filePath) >= 0
            readonly property bool hidden: win.isHiddenName(fileName)
            readonly property bool dropHot: win.dragging && win.dropTarget === filePath
            readonly property bool dragged: win.dragging && win.dragPaths.indexOf(filePath) >= 0

            // klasöre girince sırayla beliren hücreler
            property int born: win.token
            opacity: 0
            Component.onCompleted: popIn.start()
            onBornChanged: popIn.restart()
            SequentialAnimation {
                id: popIn
                PropertyAction { target: fc; property: "opacity"; value: 0 }
                PauseAnimation { duration: Math.max(0, Math.min(fc.index, 24)) * 14 }
                ParallelAnimation {
                    NumberAnimation { target: fc; property: "opacity"; to: 1; duration: 220 }
                    NumberAnimation { target: cellTr; property: "y"; from: 10; to: 0; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmphDecel }
                }
            }
            transform: Translate { id: cellTr }

            Rectangle {
                id: bgRect
                anchors.fill: parent
                anchors.margins: fc.gridMode ? 4 : 0
                radius: fc.gridMode ? 16 : 10
                color: fc.dropHot ? Qt.alpha(Theme.pink, 0.28) : fc.picked ? Qt.alpha(Theme.pink, 0.17) : cellMa.containsMouse && !win.dragging ? Theme.surface2 : "transparent"
                border.width: fc.dropHot ? 2 : fc.picked || fc.cursor ? 1.5 : 0
                border.color: fc.dropHot ? Theme.pink : fc.picked ? Qt.alpha(Theme.pink, 0.75) : Qt.alpha(Theme.purple, 0.5)
                Behavior on color { ColorAnimation { duration: 140 } }
                scale: fc.dropHot ? 1.05 : cellMa.pressed && !win.dragging ? 0.96 : 1
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                opacity: fc.cut || fc.dragged ? 0.45 : fc.hidden ? 0.7 : 1
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }

            // ---- ızgara görünümü ----
            Column {
                visible: fc.gridMode
                anchors.horizontalCenter: parent.horizontalCenter
                y: 12
                width: parent.width - 16
                spacing: 8
                opacity: bgRect.opacity
                Item {
                    width: 72; height: 72
                    anchors.horizontalCenter: parent.horizontalCenter
                    scale: cellMa.containsMouse ? 1.08 : 1
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpatial } }
                    ClippingRectangle {
                        id: thumbFrame
                        anchors.fill: parent
                        visible: fc.img
                        radius: 12
                        color: Theme.surface3
                        Image {
                            anchors.fill: parent
                            source: fc.img && fc.gridMode ? "file://" + fc.filePath : ""
                            sourceSize: Qt.size(144, 144)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }
                    }
                    Image {
                        anchors.fill: parent
                        visible: !fc.img
                        source: fc.gridMode && !fc.img ? win.iconFor(fc.fileName, fc.fileIsDir) : ""
                        sourceSize: Qt.size(144, 144)
                        asynchronous: true
                        // klasör ikonları temanın rengine boyanır (tema değişince yumuşakça geçer)
                        layer.enabled: fc.fileIsDir
                        layer.effect: MultiEffect { colorization: 1.0; colorizationColor: Theme.pink; brightness: 0.06; saturation: 0.15 }
                    }
                }
                Item {
                    width: parent.width; height: 34
                    Txt {
                        visible: win.renaming !== fc.filePath
                        anchors.fill: parent
                        text: fc.fileName
                        size: 12
                        color: fc.picked ? Theme.text : Theme.subtext
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 2
                        elide: Text.ElideMiddle
                    }
                }
            }

            // ---- liste görünümü ----
            RowLayout {
                visible: !fc.gridMode
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 14
                spacing: 12
                opacity: bgRect.opacity
                Item {
                    Layout.preferredWidth: 26; Layout.preferredHeight: 26
                    Image {
                        anchors.fill: parent
                        source: !fc.gridMode ? (fc.img ? "file://" + fc.filePath : win.iconFor(fc.fileName, fc.fileIsDir)) : ""
                        sourceSize: Qt.size(52, 52)
                        fillMode: fc.img ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                        asynchronous: true
                        // klasör ikonları temanın rengine boyanır (tema değişince yumuşakça geçer)
                        layer.enabled: fc.fileIsDir
                        layer.effect: MultiEffect { colorization: 1.0; colorizationColor: Theme.pink; brightness: 0.06; saturation: 0.15 }
                    }
                }
                Txt { visible: win.renaming !== fc.filePath; text: fc.fileName; size: 13; color: fc.picked ? Theme.text : Theme.subtext; Layout.fillWidth: true; elide: Text.ElideMiddle }
                Item { visible: win.renaming === fc.filePath; Layout.fillWidth: true }
                Txt { text: win.when(fc.fileModified); size: 12; color: Theme.muted; Layout.preferredWidth: 130 }
                Txt { text: fc.fileIsDir ? "—" : win.human(fc.fileSize); size: 12; color: Theme.muted; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
            }

            // ---- yeniden adlandırma kutusu ----
            Rectangle {
                visible: win.renaming === fc.filePath
                x: fc.gridMode ? 6 : 46
                y: fc.gridMode ? parent.height - 46 : 5
                width: fc.gridMode ? parent.width - 12 : parent.width - 260
                height: 30; radius: 8
                color: Theme.bg
                border.width: 1.5; border.color: Theme.pink
                z: 5
                TextInput {
                    id: ren
                    anchors.fill: parent; anchors.margins: 6
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: fc.gridMode ? TextInput.AlignHCenter : TextInput.AlignLeft
                    color: Theme.text; selectionColor: Qt.alpha(Theme.pink, 0.4)
                    font.family: Theme.font; font.pixelSize: 12
                    clip: true
                    onVisibleChanged: if (visible) {
                        text = fc.fileName
                        const dot = fc.fileIsDir ? -1 : text.lastIndexOf(".")
                        forceActiveFocus(); select(0, dot > 0 ? dot : text.length)
                    }
                    Keys.onReturnPressed: win.commitRename(fc.filePath, text)
                    Keys.onEscapePressed: { win.renaming = ""; keys.forceActiveFocus() }
                    onActiveFocusChanged: if (!activeFocus && win.renaming === fc.filePath) win.commitRename(fc.filePath, text)
                }
            }

            MouseArea {
                id: cellMa
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: win.dragging ? Qt.DragMoveCursor : Qt.PointingHandCursor
                preventStealing: true          // sürüklerken liste kaymasın, dosya sürüklensin
                property point pressAt
                property bool moved: false
                onPressed: m => { pressAt = Qt.point(m.x, m.y); moved = false }
                onPositionChanged: m => {
                    if (!pressed || win.renaming === fc.filePath) return
                    if (!moved && Math.hypot(m.x - pressAt.x, m.y - pressAt.y) > 10) {
                        moved = true
                        if (!fc.picked) win.clickItem(fc.index, 0)
                        win.dragBegin(win.selected(), (pressedButtons & Qt.RightButton) ? Qt.RightButton : Qt.LeftButton)
                    }
                    if (moved) { const p = fc.mapToItem(keys, m.x, m.y); win.dragMove(p.x, p.y) }
                }
                onReleased: m => { if (moved) win.dragEnd(m.modifiers) }
                onCanceled: { if (moved) { win.dragging = false; win.dropTarget = "" } }
                onClicked: m => {
                    if (moved) return
                    keys.forceActiveFocus()
                    if (m.button === Qt.RightButton) {
                        if (!fc.picked) win.clickItem(fc.index, 0)
                        const p = fc.mapToItem(keys, m.x, m.y)
                        ctx.openAt(p.x, p.y, true)
                    } else win.clickItem(fc.index, m.modifiers)
                }
                onDoubleClicked: m => { if (m.button === Qt.LeftButton && !moved) win.openIdx(fc.index) }
            }
        }
    }
}
