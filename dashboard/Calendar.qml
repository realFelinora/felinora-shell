// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../config"
import "../components"

// ay ileri/geri gidebilen takvim (Pazartesi başlangıçlı)
Card {
    id: cal

    SystemClock { id: clock; precision: SystemClock.Hours }
    readonly property var today: clock.date
    property int year: today.getFullYear()
    property int month: today.getMonth()

    readonly property var monthNames: ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
    readonly property var dayNames: ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
    readonly property var longDays: ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"]

    function shift(d) {
        let m = month + d, y = year
        if (m < 0) { m = 11; y-- } else if (m > 11) { m = 0; y++ }
        month = m; year = y
    }
    function reset() { year = today.getFullYear(); month = today.getMonth() }

    readonly property var cells: {
        const first = new Date(year, month, 1)
        const offset = (first.getDay() + 6) % 7
        const out = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(year, month, 1 - offset + i)
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === month,
                isToday: d.toDateString() === today.toDateString(),
                weekend: i % 7 >= 5
            })
        }
        return out
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            IconButton { icon: Theme.left; size: 18; implicitWidth: 28; implicitHeight: 28; onClicked: cal.shift(-1) }
            Txt {
                text: cal.monthNames[cal.month] + " " + cal.year
                size: 16
                font.weight: Font.Black
                Layout.preferredWidth: 130
                horizontalAlignment: Text.AlignHCenter
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cal.reset() }
            }
            IconButton { icon: Theme.right; size: 18; implicitWidth: 28; implicitHeight: 28; onClicked: cal.shift(1) }
            Item { Layout.fillWidth: true }
            Icon { text: Theme.calendar; size: 14; color: Theme.purple }
            Txt {
                text: cal.today.getDate() + " " + cal.monthNames[cal.today.getMonth()] + " " + cal.today.getFullYear() + ", " + cal.longDays[cal.today.getDay()]
                size: 12
                color: Theme.pink
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            rowSpacing: 2
            columnSpacing: 2

            Repeater {
                model: cal.dayNames
                delegate: Txt {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    size: 11
                    font.weight: Font.Black
                    color: index >= 5 ? Theme.pink : Theme.purple
                }
            }

            Repeater {
                model: cal.cells
                delegate: Item {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 2
                        height: width
                        radius: width / 2
                        color: modelData.isToday ? Theme.pink : (dm.containsMouse ? Theme.surface3 : "transparent")
                    }
                    Txt {
                        anchors.centerIn: parent
                        text: modelData.day
                        mono: true
                        size: 12
                        font.weight: modelData.isToday ? Font.Black : Font.DemiBold
                        color: modelData.isToday ? Theme.bg
                             : !modelData.inMonth ? Theme.muted
                             : modelData.weekend ? Theme.pinkSoft : Theme.text
                        opacity: modelData.inMonth ? 1 : 0.5
                    }
                    MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true }
                }
            }
        }
    }
}
