import QtQuick 6.8
import QtQuick.Controls 6.8
import QtQuick.Layouts 6.8
import QtPositioning 6.8
import QGroundControl.ScreenTools
import QGroundControl.Toolbar

Rectangle {
    id: controlRoot
    implicitHeight: droneControlButton.implicitHeight + (_panelMargin * 2)

    color: "#252525"
    border.color: "#333"
    radius: 4

    readonly property real _panelMargin: ScreenTools.defaultFontPixelHeight * 0.45
    readonly property real _panelSpacing: ScreenTools.defaultFontPixelHeight * 0.35
    readonly property real _buttonSpacing: ScreenTools.defaultFontPixelWidth * 0.35

    // CustomFlyView에서 선택된 로컬기기(QGC Vehicle) 주입.
    // 정책: ARM 버튼은 무장만 수행 — flightMode / guided / 미션 등 비행모드는 절대 변경하지 않음.
    property var    vehicle:           null  // QGC Vehicle object
    property var    missionController: null
    property real   takeoffAltM:       10   // 이륙 목표 고도 (m, 상대고도) — 팝업에서 갱신, 서버 연동 시 동일 값 사용 가능
    // FlyView guided 슬라이더 상한과 동일 기본 (FlyView.SettingsGroup.json guidedMaximumAltitude)
    readonly property real _takeoffAltMaxM: 121.92

    // CustomFlyView가 맵 pick 모드를 시작/종료하도록 알림. (패널은 맵을 직접 잡지 않음)
    signal requestMoveMapPick()
    signal cancelMoveMapPick()

    function _takeoffAltMinM() {
        if (!controlRoot.vehicle)
            return 3.048
        return controlRoot.vehicle.minimumTakeoffAltitudeMeters()
    }

    function _openTakeoffAltitudePopup() {
        if (!controlRoot.vehicle)
            return
        takeoffAltField.text = controlRoot.takeoffAltM.toFixed(1)
        takeoffAltPopup.open()
    }

    function _applyTakeoffFromPopup() {
        if (!controlRoot.vehicle)
            return
        var lo = controlRoot._takeoffAltMinM()
        var hi = controlRoot._takeoffAltMaxM
        var t = String(takeoffAltField.text).replace(",", ".").trim()
        var v = parseFloat(t)
        if (isNaN(v))
            v = controlRoot.takeoffAltM
        v = Math.max(lo, Math.min(hi, v))
        controlRoot.takeoffAltM = v
        controlRoot.vehicle.guidedModeTakeoff(v)
        takeoffAltPopup.close()
    }

    function _openMoveMethodPopup() {
        if (!controlRoot.vehicle)
            return
        // 이전 pick이 남아 방법 선택/좌표입력과 겹치지 않도록 정리
        controlRoot.cancelMoveMapPick()
        moveMethodPopup.open()
    }

    function _openMoveCoordPopup() {
        if (!controlRoot.vehicle)
            return

        controlRoot.cancelMoveMapPick()

        var lat = controlRoot.vehicle.latitude
        var lon = controlRoot.vehicle.longitude

        moveLatField.text = isFinite(lat) ? Number(lat).toFixed(7) : ""
        moveLonField.text = isFinite(lon) ? Number(lon).toFixed(7) : ""
        moveErrorLabel.text = ""
        movePopup.open()
    }

    // 맵 클릭으로 고른 좌표를 확인 팝업에 채운다. (실행은 사용자가 Move를 누를 때만)
    function openMoveConfirmFromMap(lat, lon) {
        if (!controlRoot.vehicle)
            return
        if (!isFinite(lat) || !isFinite(lon) || lat < -90 || lat > 90 || lon < -180 || lon > 180)
            return

        moveLatField.text = Number(lat).toFixed(7)
        moveLonField.text = Number(lon).toFixed(7)
        moveErrorLabel.text = ""
        movePopup.open()
    }

    function _applyMoveFromPopup() {
        if (!controlRoot.vehicle)
            return

        var lat = parseFloat(String(moveLatField.text).replace(",", ".").trim())
        var lon = parseFloat(String(moveLonField.text).replace(",", ".").trim())

        if (isNaN(lat) || isNaN(lon) || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
            moveErrorLabel.text = qsTr("Enter a valid latitude/longitude.")
            return
        }

        moveErrorLabel.text = ""
        controlRoot.vehicle.guidedModeGotoLocation(QtPositioning.coordinate(lat, lon))
        movePopup.close()
    }

    // 이륙 고도 입력 (패널과 동일 다크 톤)
    Popup {
        id: takeoffAltPopup
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: 280
        padding: 12
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onOpened: {
            takeoffAltField.selectAll()
            takeoffAltField.forceActiveFocus()
        }

        background: Rectangle {
            color: "#2a2a2a"
            border.color: "#444"
            radius: 4
        }

        contentItem: ColumnLayout {
            id: takeoffAltPanel
            width: takeoffAltPopup.availableWidth
            spacing: 12

            Label {
                text: qsTr("Takeoff altitude (m, relative)")
                color: "#e0e0e0"
                font.pointSize: ScreenTools.defaultFontPointSize
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            TextField {
                id: takeoffAltField
                Layout.fillWidth: true
                color: "#f0f0f0"
                placeholderText: qsTr("e.g. 10")
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator {
                    bottom: 0.5
                    top: 500
                    notation: DoubleValidator.StandardNotation
                }

                background: Rectangle {
                    implicitHeight: 36
                    color: "#1e1e1e"
                    border.color: "#555"
                    radius: 3
                }
            }

            RowLayout {
                spacing: 8
                Layout.alignment: Qt.AlignRight
                Layout.fillWidth: true

                PanelButton {
                    text: qsTr("Cancel")
                    onClicked: takeoffAltPopup.close()
                }
                PanelButton {
                    text: qsTr("Takeoff")
                    onClicked: controlRoot._applyTakeoffFromPopup()
                }
            }
        }
    }

    Popup {
        id: moveMethodPopup
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: 280
        padding: 12
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: "#2a2a2a"
            border.color: "#444"
            radius: 4
        }

        contentItem: ColumnLayout {
            width: moveMethodPopup.availableWidth
            spacing: 12

            Label {
                text: qsTr("Move 방법 선택")
                color: "#e0e0e0"
                font.pointSize: ScreenTools.defaultFontPointSize
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            PanelButton {
                Layout.fillWidth: true
                text: qsTr("좌표입력")
                onClicked: {
                    moveMethodPopup.close()
                    controlRoot._openMoveCoordPopup()
                }
            }

            PanelButton {
                Layout.fillWidth: true
                text: qsTr("마우스 맵핑")
                onClicked: {
                    moveMethodPopup.close()
                    controlRoot.requestMoveMapPick()
                }
            }

            PanelButton {
                Layout.alignment: Qt.AlignRight
                text: qsTr("Cancel")
                onClicked: moveMethodPopup.close()
            }
        }
    }

    Popup {
        id: movePopup
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: 300
        padding: 12
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onOpened: {
            moveLatField.selectAll()
            moveLatField.forceActiveFocus()
        }

        background: Rectangle {
            color: "#2a2a2a"
            border.color: "#444"
            radius: 4
        }

        contentItem: ColumnLayout {
            width: movePopup.availableWidth
            spacing: 12

            Label {
                text: qsTr("Move vehicle to a target coordinate")
                color: "#e0e0e0"
                font.pointSize: ScreenTools.defaultFontPointSize
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            TextField {
                id: moveLatField
                Layout.fillWidth: true
                color: "#f0f0f0"
                placeholderText: qsTr("Latitude")
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator {
                    bottom: -90
                    top: 90
                    notation: DoubleValidator.StandardNotation
                }

                background: Rectangle {
                    implicitHeight: 36
                    color: "#1e1e1e"
                    border.color: "#555"
                    radius: 3
                }
            }

            TextField {
                id: moveLonField
                Layout.fillWidth: true
                color: "#f0f0f0"
                placeholderText: qsTr("Longitude")
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator {
                    bottom: -180
                    top: 180
                    notation: DoubleValidator.StandardNotation
                }

                background: Rectangle {
                    implicitHeight: 36
                    color: "#1e1e1e"
                    border.color: "#555"
                    radius: 3
                }
            }

            Label {
                id: moveErrorLabel
                color: "#ff8a80"
                visible: text.length > 0
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 8
                Layout.alignment: Qt.AlignRight
                Layout.fillWidth: true

                PanelButton {
                    text: qsTr("Cancel")
                    onClicked: movePopup.close()
                }

                PanelButton {
                    text: qsTr("Move")
                    onClicked: controlRoot._applyMoveFromPopup()
                }
            }
        }
    }

    // ── 기체 상태 편의 property (enabled 조건 중복 방지) ────────────────────────
    readonly property bool _hasVehicle:           vehicle !== null
    readonly property bool _isArmed:              _hasVehicle && vehicle.armed
    readonly property bool _isFlying:             _hasVehicle && vehicle.flying
    readonly property bool _guidedOk:             _hasVehicle && vehicle.guidedModeSupported
    readonly property var  _healthReport:         _hasVehicle ? vehicle.healthAndArmingCheckReport : null
    readonly property bool _healthReportSupported:_healthReport && _healthReport.supported
    readonly property bool _canArm:               _hasVehicle && (!_healthReportSupported || _healthReport.canArm)
    readonly property bool _canTakeoff:           _hasVehicle && (!_healthReportSupported || _healthReport.canTakeoff)
    readonly property bool _canStartMission:      _hasVehicle && (!_healthReportSupported || _healthReport.canStartMission)
    readonly property bool _missionAvailable:     missionController ? missionController.containsItems : false
    readonly property string _flightMode:         _hasVehicle ? String(vehicle.flightMode || "") : ""
    readonly property bool _inMissionMode:        _hasVehicle && _modeEqualsCurrent(vehicle.missionFlightMode)
    readonly property bool _inLandMode:           _hasVehicle && _modeEqualsCurrent(vehicle.landFlightMode)
    readonly property bool _inRTLMode:            _hasVehicle && _modeEqualsCurrent(vehicle.rtlFlightMode)
    readonly property bool _inPauseMode:          _hasVehicle && _modeEqualsCurrent(vehicle.pauseFlightMode)

    // ── 빠른 모드 버튼: UI는 기존 유지. 전환은 ModeIndicator와 동일하게 «flightModes에 있는 문자열만» 할당.
    //    후보 이름은 전부 Vehicle(=FirmwarePlugin) 속성만 사용. 플러그인 setFlightMode와 동일하게 대소문자 무시 매칭.
    function _modeInFlightModesList(v, hint) {
        if (!v || !hint || hint.length === 0)
            return ""
        var modes = v.flightModes
        var i
        var m
        var hintL = hint.toLowerCase()
        for (i = 0; i < modes.length; i++) {
            m = modes[i]
            if (m.toLowerCase() === hintL)
                return m
        }
        return ""
    }

    function _modeFromVehicleHints(v, hints) {
        if (!v || !hints)
            return ""
        var hi
        for (hi = 0; hi < hints.length; hi++) {
            var found = controlRoot._modeInFlightModesList(v, hints[hi])
            if (found.length > 0)
                return found
        }
        return ""
    }

    function _modeEqualsCurrent(modeStr) {
        var target = String(modeStr || "")
        return _flightMode.length > 0 && target.length > 0 && _flightMode.toLowerCase() === target.toLowerCase()
    }

    // AltHold: Vehicle에 전용 속성 없음 → 목록만 스캔(항목은 플러그인이 채운 flightModes)
    function _altHoldFromFlightModesOnly(v) {
        if (!v)
            return ""
        var modes = v.flightModes
        var i
        var m
        var ml
        for (i = 0; i < modes.length; i++) {
            m = modes[i]
            ml = m.trim().toLowerCase()
            if (ml === "althold" || ml === "alt hold")
                return m
        }
        for (i = 0; i < modes.length; i++) {
            m = modes[i]
            ml = m.toLowerCase()
            if (ml.indexOf("altitude") >= 0 && ml.indexOf("hold") >= 0)
                return m
        }
        for (i = 0; i < modes.length; i++) {
            m = modes[i]
            if (m.trim().toLowerCase() === "altitude")
                return m
        }
        return ""
    }

    function _positionLikeFromFlightModesOnly(v) {
        if (!v)
            return ""
        var modes = v.flightModes
        var i
        var m
        var ml
        for (i = 0; i < modes.length; i++) {
            m = modes[i]
            ml = m.trim().toLowerCase()
            if (ml === "poshold")
                return m
        }
        for (i = 0; i < modes.length; i++) {
            m = modes[i]
            ml = m.trim().toLowerCase()
            if (ml === "position" || ml === "posctl")
                return m
        }
        for (i = 0; i < modes.length; i++) {
            m = modes[i]
            if (m.toLowerCase().indexOf("position") >= 0)
                return m
        }
        for (i = 0; i < modes.length; i++) {
            m = modes[i]
            if (m.toLowerCase().indexOf("loiter") >= 0)
                return m
        }
        for (i = 0; i < modes.length; i++) {
            m = modes[i]
            ml = m.trim().toLowerCase()
            if (ml === "hold")
                return m
        }
        for (i = 0; i < modes.length; i++) {
            m = modes[i]
            ml = m.trim().toLowerCase()
            if (ml === "position")
                return m
        }
        for (i = 0; i < modes.length; i++) {
            m = modes[i]
            ml = m.toLowerCase()
            if (ml.indexOf("altitude") >= 0 && ml.indexOf("hold") >= 0)
                continue
            if (ml.indexOf("hold") >= 0)
                return m
        }
        return ""
    }

    readonly property string _quickModeStab: {
        if (!vehicle)
            return ""
        var hit = controlRoot._modeFromVehicleHints(vehicle, [vehicle.stabilizedFlightMode])
        if (hit.length > 0)
            return hit
        return controlRoot._modeFromVehicleHints(vehicle, ["Stabilize", "Stabilized"])
    }
    readonly property string _quickModeAlt: {
        if (!vehicle)
            return ""
        return controlRoot._altHoldFromFlightModesOnly(vehicle)
    }
    readonly property string _quickModePos: {
        if (!vehicle)
            return ""
        var hints = []
        if (vehicle.px4Firmware && vehicle.multiRotor)
            hints.push("Position")
        if (vehicle.apmFirmware && vehicle.multiRotor)
            hints.push(vehicle.takeControlFlightMode)
        if (vehicle.takeControlFlightMode)
            hints.push(vehicle.takeControlFlightMode)
        if (vehicle.pauseFlightMode)
            hints.push(vehicle.pauseFlightMode)
        var hit = controlRoot._modeFromVehicleHints(vehicle, hints)
        if (hit.length > 0)
            return hit
        return controlRoot._positionLikeFromFlightModesOnly(vehicle)
    }

    function _applyQuickFlightMode(modeStr) {
        if (!vehicle || !modeStr || modeStr.length === 0)
            return
        vehicle.flightMode = modeStr
    }

    ColumnLayout {
        id: droneControlButton
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: controlRoot._panelMargin
        spacing: controlRoot._panelSpacing

        // 1행: ARM / DISARM / Auto(미션)
        RowLayout {
            Layout.fillWidth: true
            spacing: controlRoot._buttonSpacing

            // ARM: 비무장 + 비비행 중일 때만 활성 (비행모드 불변 — ModeChange/Takeoff 등에서만 모드 변경)
            PanelButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: "ARM"
                enabled: controlRoot._hasVehicle && !controlRoot._isArmed && !controlRoot._isFlying && controlRoot._canArm
                onClicked: {
                    if (!controlRoot.vehicle) return
                    controlRoot.vehicle.armed = true
                }
            }

            // DISARM: 무장 + 비행 중이 아닐 때만 활성 (비행 중 DISARM = 추락 위험)
            PanelButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: "DISARM"
                enabled: controlRoot._isArmed && !controlRoot._isFlying
                onClicked: {
                    if (controlRoot.vehicle) controlRoot.vehicle.armed = false
                }
            }

            // Auto: 미션 시작/계속 (flightMode 변경이 아닌 startMission 사용)
            PanelButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: "Auto"
                enabled: controlRoot._hasVehicle && controlRoot._missionAvailable
                         && !controlRoot._inMissionMode && !controlRoot._inLandMode && !controlRoot._inRTLMode
                         && ((!controlRoot._isFlying && controlRoot._canStartMission) || (controlRoot._isFlying && controlRoot._isArmed))
                onClicked: {
                    if (controlRoot.vehicle) controlRoot.vehicle.startMission()
                }
            }
        }

        // 2행: Takeoff / Land / RTL
        RowLayout {
            Layout.fillWidth: true
            spacing: controlRoot._buttonSpacing

            // Takeoff: guidedTakeoffSupported 여부에 따라 API 분기
            PanelButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: "Takeoff"
                enabled: controlRoot._hasVehicle && controlRoot.vehicle.takeoffVehicleSupported
                         && !controlRoot._isFlying && controlRoot._canTakeoff
                onClicked: {
                    if (!controlRoot.vehicle) return
                    // guidedTakeoffSupported: 고도 입력 팝업 → guidedModeTakeoff / 미지원: startTakeoff
                    if (controlRoot.vehicle.guidedTakeoffSupported)
                        controlRoot._openTakeoffAltitudePopup()
                    else
                        controlRoot.vehicle.startTakeoff()
                }
            }

            // Land: guidedModeLand() 사용 (flightMode 문자열 변경이 아님)
            PanelButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: "Land"
                enabled: controlRoot._guidedOk && controlRoot._isArmed
                         && !controlRoot.vehicle.fixedWing
                         && !controlRoot._inLandMode
                onClicked: {
                    if (controlRoot.vehicle) controlRoot.vehicle.guidedModeLand()
                }
            }

            // RTL: guidedModeRTL() 사용 (flightMode 문자열 변경이 아님)
            PanelButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: "RTL"
                enabled: controlRoot._guidedOk && controlRoot._isArmed && controlRoot._isFlying
                         && !controlRoot._inRTLMode
                onClicked: {
                    if (controlRoot.vehicle) controlRoot.vehicle.guidedModeRTL(false)
                }
            }
        }

        // 3행: Move / Pause / ModeChange (+ Stabilize·AltHold·Loiter)
        RowLayout {
            Layout.fillWidth: true
            spacing: controlRoot._buttonSpacing

            // Move: 방법 선택(좌표입력 / 마우스 맵핑) 후 guided goto
            PanelButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: "Move"
                enabled: controlRoot._guidedOk && controlRoot._isArmed && controlRoot._isFlying
                onClicked: {
                    controlRoot._openMoveMethodPopup()
                }
            }

            // Pause: 비행 중 + pauseVehicleSupported 일 때만 활성
            PanelButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: "Pause"
                enabled: controlRoot._isArmed && controlRoot._isFlying
                         && controlRoot._hasVehicle && controlRoot.vehicle.pauseVehicleSupported
                         && !controlRoot._inPauseMode
                onClicked: {
                    if (controlRoot.vehicle) controlRoot.vehicle.pauseVehicle()
                }
            }

            RowLayout {
                spacing: controlRoot._buttonSpacing
                Layout.fillWidth: true

                PanelButton {
                    id: modeChangeButton
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    text: "ModeChange"
                    enabled: controlRoot._hasVehicle && controlRoot.vehicle.flightModes.length > 0
                    onClicked: flightModeMenu.opened = !flightModeMenu.opened
                }

                RowLayout {
                    id: flightModeMenu
                    property bool opened: false

                    Layout.preferredWidth: opened ? 210 : 0
                    opacity: opened ? 1 : 0
                    visible: opacity > 0
                    clip: true

                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 200 } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    PanelButton {
                        text: qsTr("자세유지모드")
                        Layout.preferredWidth: 100
                        enabled: controlRoot._hasVehicle && controlRoot._quickModeStab.length > 0
                        onClicked: {
                            controlRoot._applyQuickFlightMode(controlRoot._quickModeStab)
                            flightModeMenu.opened = false
                        }
                    }

                    PanelButton {
                        text: qsTr("고도유지모드")
                        Layout.preferredWidth: 100
                        enabled: controlRoot._hasVehicle && controlRoot._quickModeAlt.length > 0
                        onClicked: {
                            controlRoot._applyQuickFlightMode(controlRoot._quickModeAlt)
                            flightModeMenu.opened = false
                        }
                    }

                    PanelButton {
                        text: qsTr("GPS비행모드")
                        Layout.preferredWidth: 100
                        enabled: controlRoot._hasVehicle && controlRoot._quickModePos.length > 0
                        onClicked: {
                            controlRoot._applyQuickFlightMode(controlRoot._quickModePos)
                            flightModeMenu.opened = false
                        }
                    }
                }
            }
        }
    }
}
