/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightDisplay

// RowLayout {

//     property string deviceName: ""

//     TelemetryValuesBar {
//         Layout.alignment:       Qt.AlignBottom
//         extraWidth:             instrumentPanel.extraValuesWidth
//         settingsGroup:          factValueGrid.telemetryBarSettingsGroup
//         specificVehicleForCard: null // Tracks active vehicle
//     }

//     FlyViewInstrumentPanel {
//         id:                 instrumentPanel
//         //Layout.alignment:   Qt.AlignBottom
//         visible:            QGroundControl.corePlugin.options.flyView.showInstrumentPanel && _showSingleVehicleUI
//     }
// }

Item {
    id: root
    property string deviceName: ""

    // 부모로부터 받은 제약 조건 내에서 전체 크기 확보
    implicitWidth:  mainWindow.sidebarTargetWidth
    implicitHeight: instrumentPanel.height + telemetryBar.height + 10

    // 1. 위쪽: 계기판 (기준점)
    FlyViewInstrumentPanel {
        id:                 instrumentPanel
        anchors.top:        parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        // 아이콘 크기 확보를 위해 width/height 직접 지정
        width:              parent.width
        height:             150

        visible:            QGroundControl.corePlugin.options.flyView.showInstrumentPanel && _showSingleVehicleUI
    }

    // 2. 아래쪽: 텔레메트리 바 (계기판 아래에 자석처럼 붙임)
    TelemetryValuesBar {
        id:                 telemetryBar

        // 중요: 계기판의 하단(bottom)에 이 요소의 상단(top)을 붙임
        anchors.top:        instrumentPanel.bottom
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.topMargin:  11 // 두 요소 사이의 물리적 간격

        height:             50

        Layout.preferredWidth: parent.width

        extraWidth:             instrumentPanel.extraValuesWidth
        settingsGroup:          factValueGrid.telemetryBarSettingsGroup
        specificVehicleForCard: null
    }
}
