pragma Singleton
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// çalan medya + lrclib.net üzerinden şarkı sözleri
Singleton {
    id: root

    readonly property var list: Mpris.players.values
    property var manual: null

    readonly property var player: {
        const ps = list
        if (manual && ps.indexOf(manual) >= 0) return manual
        for (let i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i]
        return ps.length > 0 ? ps[0] : null
    }

    readonly property bool active: player !== null
    readonly property string title: player ? (player.trackTitle || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string album: player ? (player.trackAlbum || "") : ""
    readonly property string art: player ? (player.trackArtUrl || "") : ""
    readonly property bool playing: player ? player.isPlaying : false
    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property bool canSeek: player ? player.canSeek : false
    readonly property string identity: player ? (player.identity || "") : ""
    property real position: 0

    Timer {
        interval: 250
        running: root.player !== null
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.player.positionChanged()
            root.position = root.player.position
        }
    }

    function toggle() { if (player) player.togglePlaying() }
    function next() { if (player) player.next() }
    function prev() { if (player) player.previous() }
    function seek(sec) { if (player && canSeek) { player.position = sec; position = sec } }

    function time(s) {
        s = Math.max(0, Math.floor(s))
        const m = Math.floor(s / 60), r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    // ---- şarkı sözleri ----
    property var lyrics: []          // [{t, s}]
    property bool synced: false
    property string lyricsState: "idle"   // loading | ok | none | idle
    property string _key: ""

    readonly property int lyricIndex: {
        if (!synced || lyrics.length === 0) return -1
        const p = position + 0.3
        let idx = -1
        for (let i = 0; i < lyrics.length; i++) {
            if (lyrics[i].t <= p) idx = i
            else break
        }
        return idx
    }

    onTitleChanged: lyricDebounce.restart()
    onArtistChanged: lyricDebounce.restart()
    Timer { id: lyricDebounce; interval: 700; onTriggered: root.fetchLyrics() }

    function parseLrc(text) {
        const out = []
        for (const line of text.split("\n")) {
            const m = line.match(/^\[(\d+):(\d+(?:\.\d+)?)\](.*)$/)
            if (m) out.push({ t: Number(m[1]) * 60 + Number(m[2]), s: m[3].trim() })
        }
        return out
    }

    function apply(d) {
        if (d && d.syncedLyrics) {
            lyrics = parseLrc(d.syncedLyrics); synced = true; lyricsState = "ok"; return true
        }
        if (d && d.plainLyrics) {
            lyrics = d.plainLyrics.split("\n").map(s => ({ t: -1, s: s })); synced = false; lyricsState = "ok"; return true
        }
        return false
    }

    function req(url, cb) {
        const x = new XMLHttpRequest()
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return
            let d = null
            if (x.status === 200) { try { d = JSON.parse(x.responseText) } catch (e) {} }
            cb(d)
        }
        x.open("GET", url)
        x.send()
    }

    function fetchLyrics() {
        const key = artist + "|" + title
        if (key === _key) return
        _key = key
        lyrics = []; synced = false
        if (!title) { lyricsState = "idle"; return }
        lyricsState = "loading"
        const t = encodeURIComponent(title), a = encodeURIComponent(artist)
        let url = "https://lrclib.net/api/get?track_name=" + t + "&artist_name=" + a
        if (album) url += "&album_name=" + encodeURIComponent(album)
        if (length > 0) url += "&duration=" + Math.round(length)
        req(url, d => {
            if (key !== _key) return
            if (apply(d)) return
            req("https://lrclib.net/api/search?track_name=" + t + "&artist_name=" + a, list => {
                if (key !== _key) return
                if (list && list.length) {
                    const best = list.find(x => x.syncedLyrics) || list[0]
                    if (apply(best)) return
                }
                lyricsState = "none"
            })
        })
    }
}
