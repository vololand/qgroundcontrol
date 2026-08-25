import QtQuick
import QtQuick.Layouts

import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Palette

Rectangle {
    // id를 root 대신 고유 이름 사용 (inline component DataLabel 내부에서 id 충돌/스코프 이슈 방지)
    id: droneMetricsRoot
    implicitHeight: mainLayout.implicitHeight + (mainLayout.anchors.margins * 2)
    color: qgcPal.window
    radius: ScreenTools.defaultFontPointSize * 0.5

    border.width: 1
    border.color: "#333"

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    // CustomFlyView에서 선택된 로컬기기(QGC Vehicle) 데이터를 주입
    property var    vehicle:       null     // QGC Vehicle 객체 (flightMode 신호 직접 수신용)
    property real   lat:           0        // degree
    property real   lon:           0        // degree
    property real   altM:          0        // m
    property real   speedMps:      0        // m/s
    property real   headingDeg:    0        // deg (0~360)
    property real   batteryPct:    -1       // % (-1 = 미수신)
    property real   batteryVolt:   -1       // V  (-1 = 미수신)
    property int    gpsFixType:    0        // 0=NoGPS, 1=NoFix, 2=2D, 3=3D, 4=DGPS, 5=RTKFloat, 6=RTKFixed
    property int    gpsSatCount:   0
    property real   flightDistM:   0        // m (계획된 미션 총 거리)
    property string flightTimeStr: "--:--:--" // 무장 이후 경과 시간 (hobbsMeter와 다름)

    // 비행 모드 표시: 직접 바인딩만으로는 APM 연결 직후 "Unknown" 고착·갱신 누락이 있어 명시 동기화 + 짧은 폴링
    property string _flightModeDisplay: "--"
    property int    _modeCatchTicks:    0

    function _syncFlightModeFromVehicle() {
        _flightModeDisplay = vehicle ? vehicle.flightMode : "--"
    }

    onVehicleChanged: {
        modeCatchTimer.stop()
        if (!vehicle) {
            _flightModeDisplay = "--"
            return
        }
        _syncFlightModeFromVehicle()
        // HEARTBEAT 반영 전까지 flightMode가 Unknown일 수 있음 → 최대 ~3초 재읽기
        _modeCatchTicks = 30
        modeCatchTimer.start()
    }

    Connections {
        target: droneMetricsRoot.vehicle
        function onFlightModeChanged() { droneMetricsRoot._syncFlightModeFromVehicle() }
    }

    Timer {
        id: modeCatchTimer
        interval: 100
        repeat: true
        onTriggered: {
            droneMetricsRoot._syncFlightModeFromVehicle()
            droneMetricsRoot._modeCatchTicks--
            var fm = droneMetricsRoot.vehicle ? droneMetricsRoot.vehicle.flightMode : ""
            if (droneMetricsRoot._modeCatchTicks <= 0 || (fm.length > 0 && fm !== "Unknown"))
                stop()
        }
    }

    function _gpsFixStr(fixType) {
        switch (fixType) {
            case 0: return qsTr("No GPS")
            case 1: return qsTr("No Fix")
            case 2: return qsTr("2D Fix")
            case 3: return qsTr("3D Fix")
            case 4: return qsTr("DGPS")
            case 5: return qsTr("RTK Float")
            case 6: return qsTr("RTK Fixed")
            default: return qsTr("Unknown")
        }
    }

    function _batteryStr() {
        if (droneMetricsRoot.batteryPct >= 0) return droneMetricsRoot.batteryPct.toFixed(0) + " %"
        if (droneMetricsRoot.batteryVolt >= 0) return droneMetricsRoot.batteryVolt.toFixed(1) + " V"
        return "--"
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPointSize
        spacing: ScreenTools.defaultFontPointSize * 0.5

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: ScreenTools.defaultFontPixelHeight * 0.35
            columnSpacing: ScreenTools.defaultFontPixelWidth * 1.8

            component DataLabel : QGCLabel {
                Layout.fillWidth: true
                font.family: ScreenTools.fixedFontFamily
                font.pointSize: ScreenTools.defaultFontPointSize
                color: qgcPal.text
            }

            // --- 1행 ---
            QGCLabel { text: qsTr("위도:") }
            DataLabel { text: droneMetricsRoot.lat.toFixed(6) }

            QGCLabel { text: qsTr("경도:") }
            DataLabel { text: droneMetricsRoot.lon.toFixed(6) }

            // --- 2행 ---
            QGCLabel { text: qsTr("고도:") }
            DataLabel { text: droneMetricsRoot.altM.toFixed(1) + " m" }

            QGCLabel { text: qsTr("속도:") }
            DataLabel { text: droneMetricsRoot.speedMps.toFixed(1) + " m/s" }

            // --- 3행 ---
            QGCLabel { text: qsTr("방향:") }
            DataLabel { text: droneMetricsRoot.headingDeg.toFixed(1) + " °" }

            QGCLabel { text: qsTr("배터리:") }
            DataLabel { text: droneMetricsRoot._batteryStr() }

            // --- 4행 ---
            QGCLabel { text: qsTr("GPS:") }
            DataLabel { text: droneMetricsRoot._gpsFixStr(droneMetricsRoot.gpsFixType) + " (" + droneMetricsRoot.gpsSatCount + ")" }

            QGCLabel { text: qsTr("전체 거리:") }
            DataLabel { text: droneMetricsRoot.flightDistM.toFixed(1) + " m" }

            // --- 5행 ---
            QGCLabel { text: qsTr("비행 시간:") }
            DataLabel { text: droneMetricsRoot.flightTimeStr }

            QGCLabel { text: qsTr("비행 모드:") }
            DataLabel { text: droneMetricsRoot._flightModeDisplay }
        }
    }
}
