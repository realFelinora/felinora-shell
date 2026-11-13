// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../config"
import "../components"
import "../services"

// konum + bugün / saatlik / 7 günlük
Item {
    id: root

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var months: ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
    readonly property var days: ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"]
    readonly property var shortDays: ["Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"]
    readonly property var cur: Weather.current

    function dayLabel(dateStr, i) {
        if (i === 0) return "Bugün"
        if (i === 1) return "Yarın"
        const d = new Date(dateStr + "T12:00:00")
        return days[d.getDay()]
    }
    function shortDate(dateStr) {
        const d = new Date(dateStr + "T12:00:00")
        return d.getDate() + " " + months[d.getMonth()].slice(0, 3)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 192
            Layout.fillHeight: false
            spacing: 12

            // ---- konum & tarih ----
            Card {
                Layout.preferredWidth: 290
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 2
                    RowLayout {
                        spacing: 6
                        Icon { text: Theme.mapPin; size: 18 }
                        Txt { text: Weather.city ? Weather.city + ", " + Weather.country : "konum bulunuyor..."; size: 14; font.weight: Font.Bold; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                    Item { Layout.fillHeight: true }
                    Txt { text: root.days[clock.date.getDay()]; size: 34; font.weight: Font.Black; color: Theme.pink }
                    Txt { text: clock.date.getDate() + " " + root.months[clock.date.getMonth()] + " " + clock.date.getFullYear(); size: 18; font.weight: Font.Bold }
                    Txt { text: "ayın " + clock.date.getDate() + ". günü · " + Qt.formatDateTime(clock.date, "hh:mm AP"); size: 12; color: Theme.subtext }
                    Item { Layout.fillHeight: true }
                    Txt { text: "veri: Open-Meteo.com (CC BY 4.0)"; size: 9; color: Theme.muted }
                    Txt {
                        Layout.fillWidth: true
                        text: root.cur ? Weather.mood(root.cur.code, root.cur.temp) : ""
                        size: 12
                        color: Theme.purple
                        wrapMode: Text.Wrap
                    }
                }
            }

            // ---- şu an ----
            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 20

                    Icon {
                        text: root.cur ? Weather.icon(root.cur.code, root.cur.isDay) : Theme.cloud
                        size: 92
                        color: Theme.pink
                        Layout.preferredWidth: 120
                        transform: Translate { id: bob }
                        SequentialAnimation {
                            loops: Animation.Infinite
                            running: Ui.dashboardOpen && Ui.dashTab === 3
                            NumberAnimation { target: bob; property: "y"; to: -5; duration: 1600; easing.type: Easing.InOutSine }
                            NumberAnimation { target: bob; property: "y"; to: 5; duration: 1600; easing.type: Easing.InOutSine }
                        }
                    }
                    ColumnLayout {
                        spacing: 0
                        Txt { text: root.cur ? Math.round(root.cur.temp) + "°C" : "--°C"; size: 56; font.weight: Font.Black }
                        Txt { text: root.cur ? Weather.desc(root.cur.code) : "..."; size: 18; color: Theme.pink; font.weight: Font.Bold }
                        Txt {
                            text: Weather.daily.length ? "en yüksek " + Math.round(Weather.daily[0].max) + "° · en düşük " + Math.round(Weather.daily[0].min) + "°" : ""
                            size: 12; color: Theme.subtext
                        }
                    }
                    Item { Layout.fillWidth: true }
                    GridLayout {
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 8
                        Stat { icon: Theme.thermo; label: "Hissedilen"; value: root.cur ? Math.round(root.cur.feels) + "°C" : "-" }
                        Stat { icon: Theme.humidity; label: "Nem"; value: root.cur ? root.cur.humidity + "%" : "-" }
                        Stat { icon: Theme.wind; label: "Rüzgar"; value: root.cur ? Math.round(root.cur.wind) + " km/h" : "-" }
                        Stat { icon: Theme.drop; label: "Yağış ihtimali"; value: Weather.daily.length ? Weather.daily[0].rain + "%" : "-" }
                        Stat { icon: Theme.sunrise; label: "Gün doğumu"; value: Weather.daily.length ? Weather.daily[0].sunrise : "-" }
                        Stat { icon: Theme.sunset; label: "Gün batımı"; value: Weather.daily.length ? Weather.daily[0].sunset : "-" }
                    }
                }
            }
        }

        // ---- saatlik ----
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 0
                Repeater {
                    model: Weather.hourly
                    delegate: ColumnLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 1
                        Txt { Layout.alignment: Qt.AlignHCenter; text: index === 0 ? "şimdi" : Qt.formatDateTime(modelData.time, "h AP"); size: 10; color: index === 0 ? Theme.pink : Theme.subtext }
                        Icon { Layout.alignment: Qt.AlignHCenter; text: Weather.icon(modelData.code, modelData.time.getHours() >= 7 && modelData.time.getHours() < 19); size: 18; color: Theme.lavender }
                        Txt { Layout.alignment: Qt.AlignHCenter; text: Math.round(modelData.temp) + "°"; size: 13; mono: true; font.weight: Font.Bold }
                    }
                }
            }
        }

        // ---- 7 gün ----
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            Repeater {
                model: Weather.daily
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 18
                    color: index === 0 ? Theme.surface2 : Theme.surface
                    border.width: index === 0 ? 1.5 : 1
                    border.color: index === 0 ? Theme.pink : Theme.border

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        Txt { Layout.alignment: Qt.AlignHCenter; text: root.dayLabel(modelData.date, index); size: 13; font.weight: Font.Black; color: index === 0 ? Theme.pink : Theme.text }
                        Txt { Layout.alignment: Qt.AlignHCenter; text: root.shortDate(modelData.date); size: 10; color: Theme.muted }
                        Icon { Layout.alignment: Qt.AlignHCenter; text: Weather.icon(modelData.code, true); size: 26; color: Theme.lavender; Layout.topMargin: 2; Layout.bottomMargin: 2 }
                        Txt { Layout.alignment: Qt.AlignHCenter; text: Weather.desc(modelData.code); size: 10; color: Theme.subtext }
                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 6
                            Txt { text: Math.round(modelData.max) + "°C"; size: 14; mono: true; font.weight: Font.Bold; color: Theme.pink }
                            Txt { text: Math.round(modelData.min) + "°"; size: 12; mono: true; color: Theme.purple; anchors.bottom: parent.bottom }
                        }
                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 3
                            Icon { text: Theme.drop; size: 10; color: Theme.lavender }
                            Txt { text: modelData.rain + "%"; size: 10; color: Theme.subtext }
                        }
                    }
                }
            }
        }
    }

    component Stat: Rectangle {
        id: st
        property string icon
        property string label
        property string value
        implicitWidth: 150
        implicitHeight: 50
        radius: 14
        color: Theme.surface2
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            spacing: 8
            Icon { text: st.icon; size: 18; color: Theme.purple; Layout.preferredWidth: 20 }
            ColumnLayout {
                spacing: 0
                Txt { text: st.label; size: 10; color: Theme.muted }
                Txt { text: st.value; size: 14; mono: true; font.weight: Font.Bold }
            }
        }
    }
}
