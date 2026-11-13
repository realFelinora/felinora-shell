pragma Singleton
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import Quickshell
import QtQuick
import "../config"

// open-meteo + ip konumu (anahtar gerektirmez)
Singleton {
    id: root

    property bool ready: false
    property string city: ""
    property string country: ""
    property real lat: 0
    property real lon: 0
    property var current: null   // {temp, feels, humidity, wind, code, isDay}
    property var daily: []       // [{date, code, max, min, rain, sunrise, sunset}]
    property var hourly: []      // [{time, temp, code, rain}]

    function get(url, cb) {
        const x = new XMLHttpRequest()
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status === 200) {
                try { cb(JSON.parse(x.responseText)) } catch (e) { console.warn("weather parse:", e) }
            } else console.warn("weather http", x.status, url)
        }
        x.open("GET", url)
        x.send()
    }

    // config.json'da şehir varsa onu kullan, yoksa konumu IP'den bul
    function refresh() {
        if (Config.weatherCity) {
            get("https://geocoding-api.open-meteo.com/v1/search?count=1&language=tr&name=" + encodeURIComponent(Config.weatherCity), r => {
                if (!r.results || !r.results.length) { console.warn("şehir bulunamadı:", Config.weatherCity); return }
                const c = r.results[0]
                city = c.name; country = c.country || ""; lat = c.latitude; lon = c.longitude
                fetchForecast()
            })
            return
        }
        get("http://ip-api.com/json/?fields=city,country,lat,lon", loc => {
            city = loc.city; country = loc.country; lat = loc.lat; lon = loc.lon
            fetchForecast()
        })
    }
    Connections {
        target: Config
        function onLoadedChanged() { if (Config.loaded && Config.weatherCity) root.refresh() }
    }

    function fetchForecast() {
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
            + "&hourly=temperature_2m,weather_code,precipitation_probability"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
            + "&timezone=auto&forecast_days=7&wind_speed_unit=kmh"
        get(url, d => {
            const c = d.current
            current = {
                temp: c.temperature_2m, feels: c.apparent_temperature, humidity: c.relative_humidity_2m,
                wind: c.wind_speed_10m, code: c.weather_code, isDay: c.is_day === 1
            }
            const dd = []
            for (let i = 0; i < d.daily.time.length; i++) dd.push({
                date: d.daily.time[i], code: d.daily.weather_code[i],
                max: d.daily.temperature_2m_max[i], min: d.daily.temperature_2m_min[i],
                rain: d.daily.precipitation_probability_max[i],
                sunrise: d.daily.sunrise[i].slice(11), sunset: d.daily.sunset[i].slice(11)
            })
            daily = dd
            const now = new Date()
            const hh = []
            for (let i = 0; i < d.hourly.time.length && hh.length < 12; i++) {
                const t = new Date(d.hourly.time[i])
                if (t.getTime() + 3600000 <= now.getTime()) continue
                hh.push({ time: t, temp: d.hourly.temperature_2m[i], code: d.hourly.weather_code[i], rain: d.hourly.precipitation_probability[i] })
            }
            hourly = hh
            ready = true
        })
    }

    Timer { interval: 30 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

    function desc(code) {
        if (code === 0) return "Açık"
        if (code === 1) return "Çoğunlukla açık"
        if (code === 2) return "Parçalı bulutlu"
        if (code === 3) return "Kapalı"
        if (code === 45 || code === 48) return "Sisli"
        if (code >= 51 && code <= 57) return "Çiseliyor"
        if (code >= 61 && code <= 67) return "Yağmurlu"
        if (code >= 71 && code <= 77) return "Karlı"
        if (code >= 80 && code <= 82) return "Sağanak"
        if (code >= 85 && code <= 86) return "Kar sağanağı"
        if (code >= 95) return "Gök gürültülü"
        return "?"
    }

    function icon(code, isDay) {
        const g = c => String.fromCharCode(c)
        if (code === 0) return isDay === false ? g(0xe32b) : g(0xe30d)
        if (code === 1 || code === 2) return isDay === false ? g(0xe37e) : g(0xe302)
        if (code === 3) return g(0xe312)
        if (code === 45 || code === 48) return g(0xe313)
        if (code >= 51 && code <= 57) return g(0xe31b)
        if (code >= 61 && code <= 67) return g(0xe318)
        if (code >= 71 && code <= 77) return g(0xe31a)
        if (code >= 80 && code <= 82) return g(0xe319)
        if (code >= 85 && code <= 86) return g(0xe31a)
        if (code >= 95) return g(0xe31d)
        return g(0xe312)
    }

    function mood(code, temp) {
        if (code >= 95) return "gök gürlüyor, battaniyeye gir (=ↀωↀ=)"
        if (code >= 51 && code <= 67 || code >= 80 && code <= 82) return "şemsiyeni unutma~ (=；ω；=)"
        if (code >= 71 && code <= 86) return "kar yağıyor! patiler üşür (=^･ｪ･^=)"
        if (temp <= 5) return "brr... çok soğuk (=；ェ；=)"
        if (temp >= 30) return "çok sıcak, eriyorum~ (=´ω`=)"
        if (code <= 1) return "güneşlenme vakti ☀ (=^･ω･^=)"
        return "tam kestirmelik hava (=^‥^=)"
    }
}
