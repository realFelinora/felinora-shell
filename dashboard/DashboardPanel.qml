// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 realFelinora — Felinora-shell
import QtQuick
import QtQuick.Layouts
import "../config"
import "../components"
import "../services"

// üst ortadan inen menü içeriği: sekmeler + sayfalar
Item {
    id: root
    readonly property int contentH: 470
    implicitWidth: 1000
    implicitHeight: contentH + 40 + 14 + 18 + 20

    // performans verisini sadece o sekme açıkken oku
    Binding { target: SysInfo; property: "perfActive"; value: Ui.dashboardOpen && Ui.dashTab === 2 }

    component Page: Item {
        id: pg
        required property int index
        readonly property int offset: index - Ui.dashTab
        width: pages.width
        height: pages.height
        property real shift: offset * 60
        property real alpha: offset === 0 ? 1 : 0
        x: shift
        opacity: alpha
        scale: offset === 0 ? 1 : 0.97
        visible: opacity > 0.01
        Behavior on shift { NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmphDecel } }
        Behavior on alpha { NumberAnimation { duration: pg.offset === 0 ? 320 : 180; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveStandard } }
        Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmphDecel } }
    }

    function key(e) {
        if (e.key === Qt.Key_Escape) Ui.dashboardOpen = false
        else if (e.key === Qt.Key_Left) Ui.dashTab = (Ui.dashTab + 4) % 5
        else if (e.key === Qt.Key_Right) Ui.dashTab = (Ui.dashTab + 1) % 5
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 18
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.bottomMargin: 20
        spacing: 14

        Tabs { Layout.alignment: Qt.AlignHCenter }

        // sayfalar: gidilen yöne doğru kayarak + solarak değişir
        Item {
            id: pages
            Layout.fillWidth: true
            Layout.preferredHeight: root.contentH
            clip: true
            Page { index: 0; DashTab { anchors.fill: parent } }
            Page { index: 1; MediaTab { anchors.fill: parent } }
            Page { index: 2; PerfTab { anchors.fill: parent } }
            Page { index: 3; WeatherTab { anchors.fill: parent } }
            Page { index: 4; ThemeTab { anchors.fill: parent } }
        }
    }
}
