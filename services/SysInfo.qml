pragma Singleton
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // performans sekmesi açıkken GPU ve disk de okunur
    property bool perfActive: false

    property real cpu: 0
    property var cpuHist: []
    property real cpuTemp: 0
    property int cpuMhz: 0
    property string cpuModel: ""
    property string osId: ""
    property string osName: "Linux"
    property int cores: 0

    property real memTotal: 0   // kB
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0

    property real uptime: 0

    property string iface: ""
    property real rxRate: 0     // B/s
    property real txRate: 0
    property real rxTotal: 0
    property real txTotal: 0
    property var rxHist: []
    property var txHist: []

    property var gpu: ({ ok: false, name: "", temp: 0, util: 0, memUsed: 0, memTotal: 0, power: 0, fan: 0 })
    property var gpuHist: []
    property var disks: []          // fiziksel diskler (lsblk)
    property var diskIo: ({})       // { sda: {r, w} } B/s
    property var _ioLast: null

    property var _cpuLast: null
    property var _netLast: null

    function push(arr, v) {
        const a = arr.slice()
        a.push(v)
        while (a.length > 40) a.shift()
        return a
    }

    function bytes(b) {
        const u = ["B", "KB", "MB", "GB", "TB"]
        let i = 0
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++ }
        return (b >= 100 || i === 0 ? b.toFixed(0) : b.toFixed(1)) + " " + u[i]
    }
    function rate(b) { return bytes(b) + "/s" }
    function duration(sec) {
        const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60)
        if (d > 0) return d + "g " + h + "s"
        if (h > 0) return h + "s " + m + "dk"
        return m + "dk"
    }

    function parse(text) {
        const mem = {}
        let io = null
        for (const line of text.trim().split("\n")) {
            const p = line.trim().split(/\s+/)
            switch (p[0]) {
            case "STAT": {
                const n = p.slice(2).map(Number)
                const idle = n[3] + n[4]
                const total = n.reduce((a, b) => a + b, 0)
                if (_cpuLast && total > _cpuLast.total)
                    cpu = 1 - (idle - _cpuLast.idle) / (total - _cpuLast.total)
                _cpuLast = { idle: idle, total: total }
                cpuHist = push(cpuHist, cpu)
                break
            }
            case "MEM": mem[p[1]] = Number(p[2]); break
            case "DISKIO": if (!io) io = {}; io[p[1]] = { r: Number(p[2]), w: Number(p[3]) }; break
            case "UP": uptime = Number(p[1]); break
            case "TEMP": cpuTemp = Number(p[1]) / 1000; break
            case "MHZ": cpuMhz = Number(p[1]); break
            case "IFACE": iface = p[1] || ""; break
            case "NET": {
                const rx = Number(p[1]), tx = Number(p[2]), now = Date.now()
                if (_netLast && now > _netLast.t) {
                    const dt = (now - _netLast.t) / 1000
                    rxRate = Math.max(0, (rx - _netLast.rx) / dt)
                    txRate = Math.max(0, (tx - _netLast.tx) / dt)
                }
                _netLast = { rx: rx, tx: tx, t: now }
                rxTotal = rx; txTotal = tx
                rxHist = push(rxHist, rxRate)
                txHist = push(txHist, txRate)
                break
            }
            }
        }
        if (io) {
            const now = Date.now(), rates = {}
            if (_ioLast) {
                const dt = (now - _ioLast.t) / 1000
                for (const k in io) if (_ioLast.v[k])
                    rates[k] = { r: Math.max(0, (io[k].r - _ioLast.v[k].r) * 512 / dt), w: Math.max(0, (io[k].w - _ioLast.v[k].w) * 512 / dt) }
            }
            _ioLast = { t: now, v: io }
            diskIo = rates
        }
        memTotal = mem.MemTotal || 0
        memUsed = memTotal - (mem.MemAvailable || 0)
        swapTotal = mem.SwapTotal || 0
        swapUsed = swapTotal - (mem.SwapFree || 0)
    }

    Process {
        id: main
        command: ["sh", Quickshell.shellPath("scripts/sysinfo.sh")]
        stdout: StdioCollector { onStreamFinished: root.parse(this.text) }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: main.running = true }

    Process {
        running: true
        command: ["sh", "-c", ". /etc/os-release 2>/dev/null; echo \"$ID\"; echo \"${PRETTY_NAME:-${NAME:-Linux}}\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.trim().split("\n")
                root.osId = l[0] || ""
                root.osName = l[1] || "Linux"
            }
        }
    }

    Process {
        command: ["sh", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2; nproc"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.trim().split("\n")
                root.cpuModel = (l[0] || "").trim().replace(/\(tm\)|\(r\)/gi, "").replace(/\s+/g, " ")
                root.cores = Number(l[1] || 0)
            }
        }
    }

    Process {
        id: gpuProc
        command: ["sh", Quickshell.shellPath("scripts/gpu.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split(",").map(x => x.trim())
                if (!p[0]) return
                const num = x => x === "" || isNaN(Number(x)) ? -1 : Number(x)
                root.gpu = {
                    ok: true, name: p[0].replace(/^NVIDIA /, ""),
                    temp: num(p[1]), util: num(p[2]) >= 0 ? num(p[2]) / 100 : -1,
                    memUsed: num(p[3]), memTotal: num(p[4]), power: num(p[5]), fan: num(p[6])
                }
                root.gpuHist = root.push(root.gpuHist, Math.max(0, root.gpu.util))
            }
        }
    }
    Timer { interval: 2000; running: root.perfActive; repeat: true; triggeredOnStart: true; onTriggered: gpuProc.running = true }

    Process {
        id: diskProc
        command: ["lsblk", "-J", "-b", "-o", "NAME,SIZE,MODEL,TYPE,ROTA,TRAN,MOUNTPOINTS,FSUSED,FSSIZE"]
        stdout: StdioCollector {
            onStreamFinished: {
                let j
                try { j = JSON.parse(this.text) } catch (e) { return }
                const out = []
                for (const d of j.blockdevices) {
                    if (d.type !== "disk" || !d.size || /^(zram|loop|ram)/.test(d.name)) continue
                    const parts = []
                    let used = 0, total = 0
                    const walk = n => {
                        const mps = (n.mountpoints || []).filter(m => m && m !== "[SWAP]")
                        if (mps.length && n.fssize) {
                            parts.push({ name: n.name, mount: mps[0], used: Number(n.fsused), size: Number(n.fssize) })
                            used += Number(n.fsused); total += Number(n.fssize)
                        }
                        for (const c of (n.children || [])) walk(c)
                    }
                    walk(d)
                    out.push({
                        name: d.name, model: (d.model || "").trim(), size: Number(d.size),
                        ssd: d.rota === false || d.rota === "0", tran: (d.tran || "").toUpperCase(),
                        used: used, fsTotal: total, parts: parts
                    })
                }
                root.disks = out
            }
        }
    }
    Timer { interval: 15000; running: root.perfActive; repeat: true; triggeredOnStart: true; onTriggered: diskProc.running = true }
}
