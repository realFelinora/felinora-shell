pragma Singleton
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import Quickshell
import Quickshell.Io
import QtQuick
import "../config"

Singleton {
    id: root

    property string type: "none"        // ethernet | wifi | none
    property string connection: ""
    property string device: ""
    property string connectivity: ""     // full | limited | portal | none
    readonly property bool online: type !== "none" && connectivity === "full"
    property string ip: ""
    property string gateway: ""
    property string linkSpeed: ""
    property string mac: ""
    property string ssid: ""
    property int signal: 0
    property string freq: ""
    property string vpn: ""
    property real ping: -1
    property string dns: ""
    property bool hasWifiDevice: false
    property var wifiList: []
    property bool scanning: false

    readonly property string icon: {
        if (type === "ethernet") return Theme.ethernet
        if (type === "wifi") return Theme.wifiLevels[Math.min(3, Math.floor(signal / 25))]
        return Theme.wifiOff
    }
    readonly property string methodLabel: type === "ethernet" ? "Kablolu · Ethernet"
                                        : type === "wifi" ? "Kablosuz · Wi-Fi" : "Bağlantı yok"

    function splitNm(line) {
        return line.replace(/\\:/g, "\u0001").split(":").map(s => s.replace(/\u0001/g, ":"))
    }

    function parse(text) {
        let t = "none", conn = "", dev = "", wifiDev = false
        let w = null, v = ""
        for (const line of text.split("\n")) {
            const sp = line.indexOf(" ")
            const tag = sp < 0 ? line : line.slice(0, sp)
            const val = sp < 0 ? "" : line.slice(sp + 1).trim()
            switch (tag) {
            case "DEV": {
                const p = splitNm(val)
                if (p[1] === "wifi") wifiDev = true
                if (t === "none" && p[2] === "connected" && (p[1] === "ethernet" || p[1] === "wifi")) {
                    t = p[1]; dev = p[0]; conn = p[3]
                }
                break
            }
            case "CONN": connectivity = val; break
            case "GW": gateway = val; break
            case "IP": ip = val; break
            case "SPEED": linkSpeed = val && Number(val) > 0 ? val + " Mb/s" : ""; break
            case "MAC": mac = val; break
            case "WIFI": w = splitNm(val); break
            case "VPN": v = v || val; break
            case "PING": ping = val ? Number(val) : -1; break
            case "DNS": dns = val; break
            }
        }
        type = t; connection = conn; device = dev; hasWifiDevice = wifiDev; vpn = v
        if (w) { ssid = w[1]; signal = Number(w[2]); freq = w[3] } else { ssid = ""; signal = 0; freq = "" }
    }

    Process {
        id: proc
        command: ["sh", Quickshell.shellPath("scripts/net.sh")]
        stdout: StdioCollector { onStreamFinished: root.parse(this.text) }
    }
    Timer { interval: 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: proc.running = true }

    function refresh() { proc.running = true }

    function scan() {
        if (!hasWifiDevice) return
        scanning = true
        scanProc.running = true
    }
    Process {
        id: scanProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}, out = []
                for (const line of this.text.trim().split("\n")) {
                    const p = root.splitNm(line)
                    if (!p[1] || seen[p[1]]) continue
                    seen[p[1]] = true
                    out.push({ active: p[0] === "*", ssid: p[1], signal: Number(p[2]), secure: !!p[3] })
                }
                out.sort((a, b) => b.signal - a.signal)
                root.wifiList = out
                root.scanning = false
            }
        }
    }

    function connect(ssid) {
        Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", ssid])
    }
}
