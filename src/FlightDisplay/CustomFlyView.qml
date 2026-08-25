import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtCore

import QGroundControl
import QGroundControl.Controllers
import QGroundControl.Controls
import QGroundControl.FactSystem
import QGroundControl.FlightDisplay
import QGroundControl.FlightMap
import QGroundControl.Palette
import QGroundControl.ScreenTools
import QGroundControl.Vehicle
import QGroundControl.Toolbar
import Viewer3D

RowLayout {
    id: root
    spacing: 0

    property bool planViewActive: false
    property var planMasterController: null
    readonly property var planController: planMasterController
    readonly property var guidedController: null
    readonly property string selectedDeviceName:    droneList.selectedDevice
    /// DroneList에서 선택된 QGC Vehicle 객체 (직접 연결 기체). 외부(MainWindow)에서 참조용.
    readonly property var    selectedQgcVehicle:    droneList.selectedQgcVehicle
    /// DroneList의 전체 기기 목록 모델. SetupView 등 외부에서 전원/연결 상태 필터링에 사용.
    readonly property var    deviceListModel:        droneList.deviceListModel
    /// [Custom] SetupView 등 외부에서 DroneList 선택을 변경(로드=선택, 해제="")하기 위한 setter.
    /// 선택 변경 → Edit A(_syncActiveVehicleToSelection)가 active 전환 → 해당 기체 데이터 로드/언로드.
    function selectDeviceByName(name) { droneList.selectedDevice = name ? String(name) : "" }

    // 비행 진행 추적 전용 컨트롤러 (flyView: true → currentMissionIndex/missionItemCount 유효)
    // FlyViewMap 표시용 planMasterController(planView, flyView:false)와 별개로 유지
    PlanMasterController {
        id:                     _flyPlanController
        flyView:                true
        Component.onCompleted:  start()
    }

    // DroneList에서 선택된 로컬기기(QGC 직접 연결 기체). 미선택 시 null → 모든 패널 비활성
    readonly property var  _activeVehicle:  droneList.selectedQgcVehicle
    // 서버 기체 선택 여부: planController 기반 WP 표시 비활성화 용도 (서버 연동 시 활성)
    readonly property bool _droneSelected:  droneList.selectedDevice !== "" && droneList.selectedQgcVehicle === null
    /// 확대창에 디코딩 서피스를 넘길 첫 번째 드론 비디오 타일.
    property var _primaryDroneVideoTile: null

    // [Custom] "선택=활성화" 연동: DroneList 선택 기체를 QGC active로 지정(미선택이면 null).
    // 표준 PlanMasterController가 active 기준으로 미션을 로드/삭제하므로, 경로는 선택 기체 것만 표시된다.
    // TCP 오토커넥트가 새 기체를 자동 active로 잡아도 항상 선택 기준으로 되돌려 "미선택=경로 없음"을 유지한다.
    function _syncActiveVehicleToSelection() {
        QGroundControl.multiVehicleManager.activeVehicle = root._activeVehicle
    }
    on_ActiveVehicleChanged: {
        root._syncActiveVehicleToSelection()
        if (!root._activeVehicle)
            root._cancelMoveMapPick()
    }
    Connections {
        target: QGroundControl.multiVehicleManager
        // QGC가 자동으로(TCP 오토커넥트 등) 선택 안 한 기체를 active로 잡으면 즉시 선택 기준으로 되돌린다.
        // vehicleAdded보다 뒤에 실행되는 자동 setActiveVehicle까지 잡기 위해 active 변경 자체를 감시한다.
        function onActiveVehicleChanged(activeVehicle) {
            if (activeVehicle !== root._activeVehicle)
                root._syncActiveVehicleToSelection()
        }
    }

    /// 사용자가 드래그로 조절한 좌/우 패널 폭(px, 절대값). 0이면 미설정 → 기본폭(sidebarTargetWidth) 사용.
    property real leftPanelUserWidth: 0
    property real rightPanelUserWidth: 0
    /// AppSettings.panelWidthsLinked(QSettings .ini) SSoT. General 탭/우클릭 메뉴와 공유.
    readonly property var  _panelWidthsLinkedFact: QGroundControl.settingsManager.appSettings.panelWidthsLinked
    readonly property bool panelWidthsLinked: _panelWidthsLinkedFact ? _panelWidthsLinkedFact.rawValue : false
    /// 좌/우 패널의 실제 적용 폭(클램프 반영). 컨테이너 폭 및 내부 위젯 maximumWidth의 SSoT.
    /// 최소폭 = 현재 기본폭(sidebarTargetWidth), 최대폭 = 창폭의 45%(단 최소폭 이상 보장).
    readonly property real _leftPanelEffectiveWidth:  _clampPanelWidth(leftPanelUserWidth)
    readonly property real _rightPanelEffectiveWidth: _clampPanelWidth(rightPanelUserWidth)
    /// MainWindow/CustomPlanView에서 참조하는 좌측 패널 폭(펼침 상태 기준). 드래그 폭과 연동.
    readonly property real leftPanelWidth: leftPanelVisible ? _leftPanelEffectiveWidth : 0
    /// 폭 클램프 헬퍼. w<=0(미설정)이면 기본폭 반환.
    function _clampPanelWidth(w) {
        // 최대폭 기준은 실제 창폭(mainWindow.width). root.width는 PlanView 모드에서
        // 좌패널 폭 자체로 축소되어(맵/우패널 숨김) 피드백 루프가 생기므로 사용하지 않는다.
        var minW = mainWindow.sidebarTargetWidth
        var maxW = Math.max(minW, mainWindow.width * 0.45)
        var base = (w > 0) ? w : minW
        return Math.max(minW, Math.min(base, maxW))
    }
    /// 좌패널 폭 설정. 연동 중이면 우패널도 동일 값으로 맞춤.
    function _setLeftPanelUserWidth(w) {
        var clamped = _clampPanelWidth(w)
        leftPanelUserWidth = clamped
        if (panelWidthsLinked)
            rightPanelUserWidth = clamped
    }
    /// 우패널 폭 설정. 연동 중이면 좌패널도 동일 값으로 맞춤.
    function _setRightPanelUserWidth(w) {
        var clamped = _clampPanelWidth(w)
        rightPanelUserWidth = clamped
        if (panelWidthsLinked)
            leftPanelUserWidth = clamped
    }
    /// 좌우 폭 연동 on/off (AppSettings Fact → .ini). 켤 때 현재 좌측 유효폭으로 양쪽을 맞춘다.
    function _setPanelWidthsLinked(linked) {
        if (_panelWidthsLinkedFact)
            _panelWidthsLinkedFact.value = linked
        if (linked)
            _equalizePanelWidthsFromLeft()
    }
    /// 연동 활성화 시 좌측 유효폭으로 양쪽 정렬.
    function _equalizePanelWidthsFromLeft() {
        var w = _leftPanelEffectiveWidth
        leftPanelUserWidth = w
        rightPanelUserWidth = w
        _savePanelWidthsSoon()
    }
    /// 좌/우 패널 폭을 초기값(sidebarTargetWidth)으로 되돌리고 저장.
    function _resetPanelWidthsToDefault() {
        leftPanelUserWidth = 0
        rightPanelUserWidth = 0
        _savePanelWidthsSoon()
    }
    /// Fly/CustomPlan 화면에서만 패널 폭 메뉴 허용. toolDrawer(Setup/Analyze 등)에서는 금지.
    readonly property bool _panelWidthMenuAllowed: {
        if (typeof mainWindow === "undefined" || mainWindow === null)
            return true
        return !mainWindow.toolDrawerVisible
    }
    /// 패널 우클릭 메뉴 표시. 좌표 인자 없이 popup()해야 커서 위치에 뜬다.
    /// (mapToGlobal을 넘기면 부모 로컬로 해석되어 창 오프셋만큼 아래로 어긋남)
    function _openPanelWidthResetMenu() {
        if (ScreenTools.isMobile || !root._panelWidthMenuAllowed)
            return
        panelWidthMenu.popup()
    }

    property bool _cursorOverSidePanels: _cursorOverLeftPanel || _cursorOverRightPanel
    property bool _cursorOverLeftPanel: leftPanelHoverArea.containsMouse
    property bool _cursorOverRightPanel: rightPanelHoverArea.containsMouse
    property bool rightPanelStationVisible: true
    property bool leftPanelVisible: true
    property bool droneVideoOnMap: false
    property bool expandWindowMinimized: false
    property bool stationVideoOnMap: false
    property bool stationExpandWindowMinimized: false

    // Move → 마우스 맵핑: 맵 클릭으로 목표점 선택. 비활성일 때 오버레이/Shortcut 모두 꺼져 사이드이펙트 없음.
    property bool _moveMapPickActive: false

    function _startMoveMapPick() {
        if (!root._activeVehicle || root.planViewActive || viewer3DWindow.isOpen) {
            root._moveMapPickActive = false
            return
        }
        root._moveMapPickActive = true
    }

    function _cancelMoveMapPick() {
        root._moveMapPickActive = false
    }

    function _finishMoveMapPickAt(mapX, mapY) {
        if (!root._moveMapPickActive || !root._activeVehicle)
            return
        var coord = mapControl.toCoordinate(Qt.point(mapX, mapY), false /* clipToViewPort */)
        root._moveMapPickActive = false
        if (!coord || !coord.isValid)
            return
        controlPanel.openMoveConfirmFromMap(coord.latitude, coord.longitude)
    }

    onPlanViewActiveChanged: {
        if (root.planViewActive)
            root._cancelMoveMapPick()
    }

    readonly property real _panelHorizontalMargins: 4

    /// 사이드 패널 내부 컴포넌트 최소 폭. 패널 목표 폭 이하로는 min(레이아웃)이 깨지지 않도록 정렬.
    readonly property real _panelComponentMinWidth: Math.max(_panelMinWidth, mainWindow.sidebarTargetWidth)
    /// 좌우 패널 아이템(leftPanelItem/rightPanelItem)의 최소 폭.
    readonly property real _panelMinWidth: 200
    /// 드론/스테이션 비디오 하단 버튼바 높이. DroneVideo._bottomBarHeight와 동기 유지.
    readonly property real _videoBarHeight: 36
    /// 확장 팝업 창 타이틀바 높이.
    readonly property real _expandTitleBarHeight: 32
    /// 확장 팝업 창 최소화·최대화 버튼 너비.
    readonly property real _expandButtonWidth: 36
    /// 확장 팝업 창 닫기 버튼 너비.
    readonly property real _expandCloseButtonWidth: 40
    /// FHD~QHD에서 패널 내부 블록이 고정 px에 묶이지 않도록 현재 패널 높이와 폰트 크기 기준으로 예산화.
    readonly property real _panelAvailableHeight: Math.max(1, height - 4)
    readonly property real _panelListMinHeight: ScreenTools.defaultFontPixelHeight * 8
    readonly property real _panelHudHeight: Math.max(ScreenTools.defaultFontPixelHeight * 10,
                                                    Math.min(_panelAvailableHeight * 0.18, ScreenTools.defaultFontPixelHeight * 13))
    readonly property real _panelVideoMinHeight: _videoBarHeight + ScreenTools.defaultFontPixelHeight * 4
    readonly property real _panelVideoMaxHeight: Math.max(_panelVideoMinHeight, _panelAvailableHeight * 0.17)
    readonly property real _panelMessageMaxHeight: ScreenTools.defaultFontPixelHeight * 4
    readonly property bool _hasMissionProgress: !root._droneSelected &&
                                                root.planController &&
                                                root.planController.missionController &&
                                                root.planController.missionController.visualItems &&
                                                root.planController.missionController.visualItems.count > 1

    /// [테스트 후 제거] 메인 비디오 폴백.
    readonly property string _mainVideoRtspUrl: "rtsp://127.0.0.1:10000/live"
    readonly property string _mainVideoRtspTransport: "udp"

    /// 장비 목록 { id, name, rtspUrl }. 추후 API 교체.
    property var _equipmentList: [
        { id: "local-1", name: qsTr("로컬 카메라 1"), rtspUrl: "rtsp://127.0.0.1:8554/live" },
        { id: "local-2", name: qsTr("로컬 카메라 2"), rtspUrl: "rtsp://127.0.0.1:8554/live" }
    ]
    /// 선택된 장비 인덱스 (0-based). -1이면 미선택.
    property int selectedEquipmentIndex: 0
    function _mainVideoUrlWithTransport(url) {
        var u = String(url || "").trim()
        if (u.indexOf("rtsp://") !== 0 || u.indexOf("rtsp_transport=") >= 0) return u
        return u + (u.indexOf("?") >= 0 ? "&" : "?") + "rtsp_transport=" + root._mainVideoRtspTransport
    }
    /// video_endpoints.ini 설정 싱글턴(없으면 null). 드론/스테이션 RTSP 주소의 SSoT.
    readonly property var _videoCfg: (typeof QGroundControl !== "undefined" && QGroundControl.videoEndpointSettings) ? QGroundControl.videoEndpointSettings : null
    /// 영상 암호 사용 여부. 켜져 있으면 QGC 연결 기체라도 VideoManager 대신 암호 RTSP 경로를 쓴다.
    readonly property bool _videoCryptoEnabled: (typeof QGroundControl !== "undefined" && QGroundControl.videoCryptoSettings)
        ? QGroundControl.videoCryptoSettings.enabled
        : false
    // transport는 DroneVideo.rtpTransport(ini drone_rtp_transport)가 적용.
    readonly property string _effectiveMainVideoRtspUrl: root._videoCfg
        ? root._videoCfg.droneUrl
        : root._mainVideoRtspUrl
    readonly property string _effectiveMainVideoChannelLabel: (root.selectedEquipmentIndex >= 0 && root._equipmentList.length > root.selectedEquipmentIndex && root._equipmentList[root.selectedEquipmentIndex].name)
        ? String(root._equipmentList[root.selectedEquipmentIndex].name)
        : qsTr("카메라")

    /// 비디오 채널 목록. [테스트 후 제거 검토]
    property var _videoChannels: [{ label: qsTr("카메라"), enabled: true }]

    /// [테스트 후 제거] 스테이션 비디오 폴백.
    readonly property string _stationMainVideoRtspUrl: "rtsp://127.0.0.1:10001/live"
    /// 스테이션 장비 목록 { id, name, rtspUrl }. 추후 API 교체.
    property var _stationEquipmentList: [
        { id: "station-1", name: qsTr("로컬 스테이션 1"), rtspUrl: "rtsp://127.0.0.1:8554/live" },
        { id: "station-2", name: qsTr("로컬 스테이션 2"), rtspUrl: "rtsp://127.0.0.1:8554/live" }
    ]
    /// 선택된 스테이션 장비 인덱스 (0-based). -1이면 미선택.
    property int selectedStationEquipmentIndex: 0
    // transport는 StationVideo.rtpTransport(ini station_rtp_transport)가 적용.
    readonly property string _effectiveStationVideoRtspUrl: root._videoCfg
        ? root._videoCfg.stationUrl
        : root._stationMainVideoRtspUrl
    readonly property string _effectiveStationVideoChannelLabel: (root.selectedStationEquipmentIndex >= 0 && root._stationEquipmentList.length > root.selectedStationEquipmentIndex && root._stationEquipmentList[root.selectedStationEquipmentIndex].name)
        ? String(root._stationEquipmentList[root.selectedStationEquipmentIndex].name)
        : qsTr("카메라")
    /// [테스트 후 제거] QGC 설정 기반, 비디오 미사용.
    property string _defaultRtspUrl: String(QGroundControl.settingsManager.videoSettings.rtspUrl.rawValue || "").trim() || "rtsp://127.0.0.1:8554/live"
    readonly property string _primaryEffectiveRtspUrl: (_defaultRtspUrl === "") ? "" : (_defaultRtspUrl.indexOf("?") >= 0 ? _defaultRtspUrl + "&rtsp_transport=udp" : _defaultRtspUrl + "?rtsp_transport=udp")

    // 지속 videoContent/thermalVideo 서피스.
    // VideoManager가 init()에서 objectName으로 찾아 GStreamer sink를 바인딩하므로 절대 파괴하지 않는다.
    // 로컬(QGC 연결) 기기가 선택되면 videoContent를 해당 타일로 reparent(빌려주고, 해제 시 반납)한다.
    // 리시버는 QGC가 관리하는 videoContent 하나뿐 → 연결 1개, 표준 teardown 경로 유지(이중 리시버 크래시 없음).
    Item {
        id: sharedVideoHolder
        width: 0
        height: 0
        visible: false
        z: -1
        QGCVideoBackground {
            id: sharedVideoContent
            objectName: "videoContent"
            visible: false
            width: 1
            height: 1
            x: 0
            y: 0
        }
        QGCVideoBackground {
            objectName: "thermalVideo"
            visible: false
            width: 1
            height: 1
            x: 0
            y: 0
        }
    }

    /// 공유 videoContent 서피스를 host에 붙인다(로컬 기기 타일). 디코딩 중일 때만 표시.
    function attachSharedVideo(host) {
        if (!host) return
        sharedVideoContent.parent = host
        sharedVideoContent.anchors.fill = host
        sharedVideoContent.visible = Qt.binding(function() {
            return (typeof QGroundControl !== "undefined") && QGroundControl.videoManager && QGroundControl.videoManager.decoding
        })
    }
    /// 공유 videoContent 서피스를 보관 위치로 되돌린다. requester가 현재 부모일 때만(경합 방지).
    function detachSharedVideo(requester) {
        if (requester && sharedVideoContent.parent !== requester) return
        sharedVideoContent.visible = false
        sharedVideoContent.anchors.fill = undefined
        sharedVideoContent.parent = sharedVideoHolder
    }

    Item {
        id: leftPanelItem
        visible: root.width > 0
        Layout.fillWidth: false
        Layout.preferredWidth: root.width > 0 ? (root.leftPanelVisible ? Math.max(0, root._leftPanelEffectiveWidth - root._panelHorizontalMargins) : 0) : 0
        Layout.minimumWidth: root.width > 0 ? (root.leftPanelVisible ? Math.max(0, root._leftPanelEffectiveWidth - root._panelHorizontalMargins) : 0) : 0
        Layout.maximumWidth: root.width > 0 ? (root.leftPanelVisible ? Math.max(0, root._leftPanelEffectiveWidth - root._panelHorizontalMargins) : 0) : 0
        Layout.fillHeight: root.width > 0
        Layout.leftMargin: 2
        Layout.topMargin: 2
        Layout.bottomMargin: 2
        Layout.rightMargin: 2

        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.AllButtons
            onPressed: (mouse) => { mouse.accepted = true }
            onReleased: (mouse) => { mouse.accepted = true }
            onWheel: (wheel) => { wheel.accepted = true }
        }

        // 패널 우클릭 메뉴. 우측 리사이즈 핸들(8px)은 제외해야 SizeHorCursor hover가 막히지 않는다.
        MouseArea {
            anchors.fill: parent
            anchors.rightMargin: leftPanelResizeHandle.width
            z: 2000
            acceptedButtons: Qt.RightButton
            onPressed: (mouse) => {
                root._openPanelWidthResetMenu()
                mouse.accepted = true
            }
        }

        QGCMenu {
            id: panelWidthMenu
            // checkable 기본 인디케이터는 왼쪽이라, 요청대로 텍스트 오른쪽에 체크/언체크를 붙인다.
            QGCMenuItem {
                text: qsTr("대칭 폭 조절") + (root.panelWidthsLinked ? "  ✓" : "  ☐")
                onTriggered: root._setPanelWidthsLinked(!root.panelWidthsLinked)
            }
            QGCMenuItem {
                text: qsTr("기본 폭으로 초기화")
                onTriggered: root._resetPanelWidthsToDefault()
            }
        }

        Rectangle {
            id: droneStatusToggleButton
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.rightMargin: 4
            anchors.topMargin: 4
            width: ScreenTools.defaultFontPixelHeight * 1.4
            height: width
            radius: width / 2
            // 열림 상태에서만 표시(접힘 시엔 맵의 재열기 버튼이 대신 표시됨)
            visible: root.leftPanelVisible
            // 접기 버튼: 배경 없음
            color: "transparent"
            z: 1000

            QGCMouseArea {
                anchors.fill: parent
                onClicked: {
                    root.leftPanelVisible = !root.leftPanelVisible
                }
            }

            QGCColoredImage {
                anchors.centerIn: parent
                width: parent.width * 0.6
                height: width
                source: "/res/PanelFold.svg"
                fillMode: Image.PreserveAspectFit
                sourceSize.width: width
                sourceSize.height: height
                color: "#ffffff"
                // 좌측 패널 접기(‹)
                rotation: 0
            }
        }

        ColumnLayout {
            id: droneStatus
            anchors.fill: parent
            visible: root.leftPanelVisible
            spacing: 0

            DroneList {
                id:                     droneList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: root.width > 0 ? root._panelComponentMinWidth : 0
                Layout.minimumHeight: root._panelListMinHeight
                Layout.preferredWidth: parent.width
                Layout.maximumWidth: root._leftPanelEffectiveWidth
            }

            CustomDroneMetrics {
                id: customDroneMetrics
                Layout.fillWidth: true
                Layout.preferredWidth: droneStatus.width
                Layout.maximumWidth: root._leftPanelEffectiveWidth

                lat:           root._activeVehicle ? root._activeVehicle.latitude                                                          : 0
                lon:           root._activeVehicle ? root._activeVehicle.longitude                                                         : 0
                altM:          root._activeVehicle ? root._activeVehicle.altitudeRelative.rawValue                                         : 0
                speedMps:      root._activeVehicle ? root._activeVehicle.groundSpeed.rawValue                                              : 0
                headingDeg:    root._activeVehicle ? root._activeVehicle.heading.rawValue                                                  : 0
                batteryPct:    (root._activeVehicle && root._activeVehicle.batteries.count > 0) ? root._activeVehicle.batteries.get(0).percentRemaining.rawValue : -1
                batteryVolt:   (root._activeVehicle && root._activeVehicle.batteries.count > 0) ? root._activeVehicle.batteries.get(0).voltage.rawValue          : -1
                gpsFixType:    root._activeVehicle ? root._activeVehicle.gps.lock.rawValue                                                : 0
                gpsSatCount:   root._activeVehicle ? root._activeVehicle.gps.count.rawValue                                               : 0
                flightDistM:   (root.planMasterController && root.planMasterController.missionController)
                               ? root.planMasterController.missionController.missionTotalDistance : 0
                // flightTime: 무장 이후 경과 시간 (hobbsMeter/홉스와 다름)
                flightTimeStr: root._activeVehicle ? root._activeVehicle.flightTime.valueString : "--:--:--"
                vehicle:       root._activeVehicle
            }

            CustomHUDWidget{
                id: customHUDWidget
                Layout.fillWidth: true
                Layout.preferredWidth:  droneStatus.width
                Layout.maximumWidth:    root._leftPanelEffectiveWidth
                Layout.preferredHeight: root._panelHudHeight
                Layout.maximumHeight:   root._panelHudHeight

                rollDeg:    root._activeVehicle ? root._activeVehicle.roll.rawValue            : 0
                pitchDeg:   root._activeVehicle ? root._activeVehicle.pitch.rawValue           : 0
                headingDeg: root._activeVehicle ? root._activeVehicle.heading.rawValue         : 0
                speedMps:   root._activeVehicle ? root._activeVehicle.groundSpeed.rawValue     : 0
                altM:       root._activeVehicle ? root._activeVehicle.altitudeRelative.rawValue: 0
            }

            ColumnLayout {
                id: droneVideoHome
                Layout.fillWidth: true
                Layout.minimumWidth: root.width > 0 ? root._panelComponentMinWidth : 0
                Layout.minimumHeight: root._panelVideoMinHeight
                Layout.preferredWidth: droneStatus.width
                Layout.preferredHeight: Math.min(droneStatus.width * 0.5625 + root._videoBarHeight, root._panelVideoMaxHeight)
                Layout.maximumWidth: root._leftPanelEffectiveWidth
                Layout.maximumHeight: root._panelVideoMaxHeight
                spacing: 2
                Repeater {
                    model: root._videoChannels
                    delegate: Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(droneStatus.width * 0.5625 + root._videoBarHeight, root._panelVideoMaxHeight)
                        Layout.minimumHeight: root._panelVideoMinHeight
                        DroneVideo {
                            id: droneVideoTile
                            anchors.fill: parent
                            deviceName: droneList.selectedDevice
                            // 로컬(QGC 연결) 기체 선택 시 QGC 공유 videoContent 서피스를 이 타일에 붙여 재생(QGC 기본 설정 그대로).
                            // 단 QGC 비디오 소스가 미설정이면 VideoManager는 렌더할 것이 없어 검은 화면만 남고,
                            // 영상 암호가 켜져 있으면 사용자가 요구한 암호 RTSP 경로를 우회해 버린다.
                            // 두 경우와 서버/API 기기는 channelUrl(RTSP)로 자체 수신한다.
                            useVideoManager: droneList.selectedQgcVehicle !== null
                                && QGroundControl.settingsManager.videoSettings.streamConfigured
                                && !root._videoCryptoEnabled
                            mapOverlayMode: false
                            mapToggleEnabled: true
                            showExpandButton: (index === 0)
                            isMainVideo: (index === 0)
                            placeholderBlackMode: false
                            // 목록에서 드론이 선택된 경우에만 재생(선택 해제 시 정지). 선택 변경 시 재연결은 DroneVideo가 처리.
                            streamEnabled: (modelData.enabled !== false) && droneList.selectedDevice !== ""
                            channelUrl: root._effectiveMainVideoRtspUrl
                            channelLabel: root._effectiveMainVideoChannelLabel
                            onToggleMapVideoRequested: {
                                if (index === 0) {
                                    root._primaryDroneVideoTile = droneVideoTile
                                    root.droneVideoOnMap = true
                                }
                            }
                            onRequestAttachSharedVideo: (host) => root.attachSharedVideo(host)
                            onRequestDetachSharedVideo: (host) => root.detachSharedVideo(host)
                            Component.onCompleted: {
                                if (index === 0)
                                    root._primaryDroneVideoTile = droneVideoTile
                            }
                            Component.onDestruction: {
                                if (root._primaryDroneVideoTile === droneVideoTile)
                                    root._primaryDroneVideoTile = null
                            }
                        }
                    }
                }
            }

            DroneStatusMessage{
                id: droneStatusMessage
                Layout.fillWidth: true
                Layout.minimumHeight: Math.min(droneStatusMessage.implicitHeight, root._panelMessageMaxHeight)
                Layout.minimumWidth: root.width > 0 ? root._panelComponentMinWidth : 0
                Layout.preferredWidth: droneStatus.width
                Layout.preferredHeight: Math.min(Layout.preferredWidth * 0.35, root._panelMessageMaxHeight)
                Layout.maximumWidth: root._leftPanelEffectiveWidth
                Layout.maximumHeight: root._panelMessageMaxHeight

                vehicle: root._activeVehicle
            }

            DroneControlPanel{
                id: controlPanel
                Layout.fillWidth: true
                Layout.minimumHeight: controlPanel.implicitHeight
                Layout.minimumWidth: root.width > 0 ? root._panelComponentMinWidth : 0
                Layout.preferredWidth: droneStatus.width
                Layout.preferredHeight: controlPanel.implicitHeight
                Layout.maximumWidth: root._leftPanelEffectiveWidth
                Layout.maximumHeight: controlPanel.implicitHeight * 1.25
                Layout.alignment: Qt.AlignBottom

                vehicle: root._activeVehicle
                missionController: root.planController ? root.planController.missionController : null
                onRequestMoveMapPick: root._startMoveMapPick()
                onCancelMoveMapPick: root._cancelMoveMapPick()
            }
        }

        MouseArea {
            id: leftPanelHoverArea
            anchors.fill: parent
            z: 1
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        // 우측 모서리 드래그 → 좌패널 폭 조절 (오른쪽으로 끌면 넓어짐). 우클릭 메뉴도 핸들에서 처리.
        MouseArea {
            id: leftPanelResizeHandle
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 8
            z: 2001
            visible: root.leftPanelVisible
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property real _startX: 0
            property real _startWidth: 0
            onPressed: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    root._openPanelWidthResetMenu()
                    return
                }
                _startX = mapToItem(root, mouse.x, mouse.y).x
                _startWidth = root._leftPanelEffectiveWidth
            }
            onPositionChanged: (mouse) => {
                if (!(mouse.buttons & Qt.LeftButton)) return
                var curX = mapToItem(root, mouse.x, mouse.y).x
                root._setLeftPanelUserWidth(_startWidth + (curX - _startX))
            }
            onReleased: (mouse) => {
                if (mouse.button === Qt.LeftButton)
                    root._savePanelWidthsSoon()
            }
        }
    }

    Item {
        id: mapHolder
        Layout.fillWidth: !root.planViewActive
        Layout.fillHeight: !root.planViewActive
        Layout.preferredWidth: 0
        Layout.minimumWidth:  0
        visible: !root.planViewActive

        QtObject {
            id: _flyToolInsets
            property real leftEdgeCenterInset: 0
            property real leftEdgeTopInset: 0
            property real leftEdgeBottomInset: 0
            property real rightEdgeCenterInset: 0
            property real rightEdgeTopInset: 0
            property real rightEdgeBottomInset: 0
            property real topEdgeCenterInset: 0
            property real topEdgeLeftInset: 0
            property real topEdgeRightInset: 0
            property real bottomEdgeCenterInset: 0
            property real bottomEdgeLeftInset: 0
            property real bottomEdgeRightInset: 0
        }
        Item {
            id: _pipView
            visible: false
        }
        FlyViewMap {
            id: mapControl
            anchors.fill: parent
            planMasterController: root.planMasterController
            rightPanelWidth: ScreenTools.defaultFontPixelHeight * 9
            pipView: _pipView
            pipMode: false
            toolInsets: _flyToolInsets
            mapName: "FlightDisplayView"
            enabled: !viewer3DWindow.isOpen && !root._cursorOverSidePanels
            // DroneList 선택 기체만 맵에 표시(아이콘+경로). 선택 해제 시 사라지고, 다른 기체 선택 시 전환됨.
            // 연결(multiVehicleManager)은 유지 — 통신 두절이 아니라 표시 필터일 뿐.
            restrictToTrackedVehicle: true
            trackedVehicle: root._activeVehicle
            // 편집 플랜 경로를 지도에 표시 → 고도 프로파일러와 동일 조건(!_droneSelected)으로 일치
            showEditPlan: !root._droneSelected
        }
        Viewer3D {
            id: viewer3DWindow
            anchors.fill: parent
            onIsOpenChanged: {
                if (isOpen)
                    root._cancelMoveMapPick()
            }
        }

        // Move 마우스 맵핑 전용. visible=false일 때는 입력/포커스/커서에 개입하지 않음.
        MouseArea {
            id: moveMapPickOverlay
            anchors.fill: parent
            z: 900
            visible: root._moveMapPickActive && !viewer3DWindow.isOpen
            hoverEnabled: true
            cursorShape: Qt.CrossCursor
            acceptedButtons: Qt.LeftButton
            onClicked: (mouse) => root._finishMoveMapPickAt(mouse.x, mouse.y)
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: ScreenTools.defaultFontPixelHeight
            z: 901
            visible: moveMapPickOverlay.visible
            width: moveMapPickBannerLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 2
            height: moveMapPickBannerLabel.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.6
            radius: 4
            color: "#cc2a2a2a"
            border.color: "#666"

            Label {
                id: moveMapPickBannerLabel
                anchors.centerIn: parent
                text: qsTr("맵을 클릭하세요 (Esc 취소)")
                color: "#f0f0f0"
                font.pointSize: ScreenTools.defaultFontPointSize
            }
        }

        Shortcut {
            enabled: root._moveMapPickActive
            sequence: StandardKey.Cancel
            onActivated: root._cancelMoveMapPick()
        }
        QGCMouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 4
            anchors.topMargin: 4
            width: ScreenTools.defaultFontPixelHeight * 1.4
            height: width
            visible: !root.planViewActive && !root.leftPanelVisible
            z: 1000
            onClicked: root.leftPanelVisible = true
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "#252525"
            }
            QGCColoredImage {
                anchors.centerIn: parent
                width: parent.width * 0.6
                height: width
                source: "/res/PanelFold.svg"
                fillMode: Image.PreserveAspectFit
                sourceSize.width: width
                sourceSize.height: height
                color: "#ffffff"
                // 좌측 패널 펴기(›)
                rotation: 180
            }
        }
        QGCMouseArea {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 4
            anchors.topMargin: 4
            width: ScreenTools.defaultFontPixelHeight * 1.4
            height: width
            visible: !root.planViewActive && !root.rightPanelStationVisible
            z: 1000
            onClicked: root.rightPanelStationVisible = true
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "#252525"
            }
            QGCColoredImage {
                anchors.centerIn: parent
                width: parent.width * 0.6
                height: width
                source: "/res/PanelFold.svg"
                fillMode: Image.PreserveAspectFit
                sourceSize.width: width
                sourceSize.height: height
                color: "#ffffff"
                // 우측 패널 펴기(‹)
                rotation: 0
            }
        }

        Item {
            id: droneVideoMinimizedOverlay
            visible: root.droneVideoOnMap && root.expandWindowMinimized
            z: 15
            width: 220
            height: 32
            anchors.left: mapHolder.left
            anchors.leftMargin: 4
            anchors.bottom: vehicleCurrentPostion.top
            anchors.bottomMargin: 4

            Rectangle {
                anchors.fill: parent
                color: "#1a1a1a"
                border.color: "#3a3a3a"
                border.width: 1
                radius: 4
            }
            Text {
                id: minimizedDeviceLabel
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 8
                text: root.selectedDeviceName ? root.selectedDeviceName : qsTr("연결된 기체")
                color: "#e0e0e0"
                font.pixelSize: 12
                elide: Text.ElideRight
                width: parent.width - (8 + 8 + 36 + 36 + 8)
            }
            Rectangle {
                width: 32
                height: 24
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: expandMinimizedBtn.left
                anchors.rightMargin: 4
                color: deleteMinimizedBtn.containsMouse ? "#5a2a2a" : "transparent"
                radius: 2
                Text { anchors.centerIn: parent; text: "×"; color: "white"; font.pixelSize: 14 }
                MouseArea {
                    id: deleteMinimizedBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { root.droneVideoOnMap = false; root.expandWindowMinimized = false }
                }
            }
            Rectangle {
                id: expandMinimizedBtn
                width: 32
                height: 24
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 4
                color: expandMinimizedBtnArea.containsMouse ? "#2f2f2f" : "transparent"
                radius: 2
                Text { anchors.centerIn: parent; text: "□"; color: "white"; font.pixelSize: 12 }
                MouseArea {
                    id: expandMinimizedBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.expandWindowMinimized = false
                }
            }
        }

        Item {
            id: stationVideoMinimizedOverlay
            visible: root.stationVideoOnMap && root.stationExpandWindowMinimized
            z: 15
            width: 220
            height: 32
            anchors.left: droneVideoMinimizedOverlay.visible ? droneVideoMinimizedOverlay.right : mapHolder.left
            anchors.leftMargin: 4
            anchors.bottom: vehicleCurrentPostion.top
            anchors.bottomMargin: 4

            Rectangle {
                anchors.fill: parent
                color: "#1a1a1a"
                border.color: "#3a3a3a"
                border.width: 1
                radius: 4
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 8
                text: (typeof stationList !== "undefined" && stationList && stationList.selectedStation) ? stationList.selectedStation : qsTr("스테이션")
                color: "#e0e0e0"
                font.pixelSize: 12
                elide: Text.ElideRight
                width: parent.width - (8 + 8 + 36 + 36 + 8)
            }
            Rectangle {
                width: 32
                height: 24
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: stationExpandMinimizedBtn.left
                anchors.rightMargin: 4
                color: stationDeleteMinimizedBtn.containsMouse ? "#5a2a2a" : "transparent"
                radius: 2
                Text { anchors.centerIn: parent; text: "×"; color: "white"; font.pixelSize: 14 }
                MouseArea {
                    id: stationDeleteMinimizedBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { root.stationVideoOnMap = false; root.stationExpandWindowMinimized = false }
                }
            }
            Rectangle {
                id: stationExpandMinimizedBtn
                width: 32
                height: 24
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 4
                color: stationExpandMinimizedBtnArea.containsMouse ? "#2f2f2f" : "transparent"
                radius: 2
                Text { anchors.centerIn: parent; text: "□"; color: "white"; font.pixelSize: 12 }
                MouseArea {
                    id: stationExpandMinimizedBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.stationExpandWindowMinimized = false
                }
            }
        }

        Item {
            id: vehicleCurrentPostion
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.bottom: parent.bottom
            height: root._hasMissionProgress ? ScreenTools.defaultFontPixelHeight * 4 : ScreenTools.defaultFontPixelHeight * 1.2
            z: 10

            Rectangle {
                id: vehicleCurrentPostion_background
                anchors.fill: parent
                color: qgcPal.window
                opacity: 0.85
                radius: 4
                border.color: qgcPal.windowShade
                border.width: 1
            }

            // 각 WP의 고도(altPercent) 변경 감시 → 리페인트 (편집기와 동기화)
            Repeater {
                model: (!root._droneSelected && root.planController)
                       ? root.planController.missionController.visualItems : null
                delegate: Item {
                    width: 0; height: 0
                    Connections {
                        target: object
                        function onAltPercentChanged() { currentPositionVisual.requestPaint() }
                    }
                }
            }

            Canvas {
                id: currentPositionVisual
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPointSize

                onTotalWpCountChanged:   requestPaint()
                onCurrentWpIndexChanged: requestPaint()

                Connections {
                    // planController(공유 편집기) 기준 → 경로 전체 삭제 시 함께 사라짐
                    target: (!root._droneSelected && root.planController)
                            ? root.planController.missionController.visualItems : null
                    function onCountChanged() { currentPositionVisual.requestPaint() }
                }

                // 미션 고도 범위/홈 고도 변경 시 y축 라벨·도트 갱신
                Connections {
                    target: currentPositionVisual._missionController
                    ignoreUnknownSignals: true
                    function onMaxAMSLAltitudeChanged()    { currentPositionVisual.requestPaint() }
                    function onMinAMSLAltitudeChanged()    { currentPositionVisual.requestPaint() }
                    function onPlannedHomePositionChanged() { currentPositionVisual.requestPaint() }
                }

                // planController 기준. visualItems[0]=홈 제외(-1). currentMissionIndex는 MAVLink 시퀀스(1=첫WP) → 0-based 오프셋 -1.
                property var _visualItems:   (!root._droneSelected && root.planController)
                                             ? root.planController.missionController.visualItems : null
                property var _missionController: (!root._droneSelected && root.planController)
                                             ? root.planController.missionController : null
                property int totalWpCount:   (!root._droneSelected && root.planController)
                                             ? Math.max(0, root.planController.missionController.visualItems.count - 1) : 0
                property int currentWpIndex: !root._droneSelected
                                             ? _flyPlanController.missionController.currentMissionIndex - 1 : -1

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    if (totalWpCount < 2) return;

                    // 수평 레이아웃: 좌측=y축 고도(m) 라벨 영역, 나머지=프로파일
                    var uiUnit     = ScreenTools.defaultFontPixelHeight;  // UI 크기 기준 단위
                    var fontPx     = uiUnit * 0.85;                       // 번호 폰트
                    var axisFont   = uiUnit * 0.7;                        // y축 라벨 폰트
                    var dotRadius  = uiUnit * 0.32;                       // 도트 반지름
                    var leftPad    = uiUnit * 2.6;                        // y축 라벨 영역 폭
                    var rightPad   = uiUnit * 1.2;
                    var drawWidth  = Math.max(1, width - leftPad - rightPad);
                    var stepX      = drawWidth / (totalWpCount - 1);

                    // 세로 레이아웃: 상단=번호 레이블 / 하단=고도 프로파일 (겹침 방지)
                    var labelBaseY = fontPx * 0.8;                        // 번호를 더 위로
                    var dotTopY    = labelBaseY + dotRadius + uiUnit * 0.2; // 프로파일 상단을 위로 → 라벨 간격 확대
                    var dotBottomY = height - dotRadius - uiUnit * 0.1;    // 하단 여백 축소 → 라벨 간격 확대
                    var dotDrawH   = Math.max(1, dotBottomY - dotTopY);

                    // 고도(홈 기준 상대고도 m): rel = amslEntryAlt - homeAMSL, 최대 = maxAMSLAltitude - homeAMSL
                    var mc       = _missionController;
                    var homeAmsl = (mc && mc.plannedHomePosition && !isNaN(mc.plannedHomePosition.altitude))
                                   ? mc.plannedHomePosition.altitude : 0;
                    var maxRel   = mc ? (mc.maxAMSLAltitude - homeAmsl) : 0;
                    if (!(maxRel > 0)) maxRel = 0;

                    // 각 WP 상대고도 수집 (visualItems[0]=홈 제외, 인덱스 1부터)
                    var relAlts = [];
                    for (var k = 0; k < totalWpCount; k++) {
                        var itm  = _visualItems ? _visualItems.get(k + 1) : null;
                        var amsl = (itm && !isNaN(itm.amslEntryAlt)) ? itm.amslEntryAlt : homeAmsl;
                        var rel  = amsl - homeAmsl;
                        if (rel < 0) rel = 0;
                        relAlts.push(rel);
                    }

                    // 도트 좌표 (0=바닥, maxRel=상단)
                    var positions = [];
                    for (var i = 0; i < totalWpCount; i++) {
                        var frac = maxRel > 0 ? (relAlts[i] / maxRel) : 0;
                        positions.push({ x: leftPad + (i * stepX),
                                         y: dotBottomY - frac * dotDrawH });
                    }

                    // y축 고도(m) 라벨 + 눈금선 (0 ~ maxRel)
                    var ticks = (maxRel > 0) ? [0, 0.5, 1] : [0];
                    ctx.strokeStyle  = Qt.rgba(1, 1, 1, 0.15);
                    ctx.lineWidth    = 1;
                    ctx.fillStyle    = qgcPal.text;
                    ctx.font         = axisFont + "px " + ScreenTools.normalFontFamily;
                    ctx.textAlign    = "right";
                    ctx.textBaseline = "middle";
                    for (var t = 0; t < ticks.length; t++) {
                        var yy = dotBottomY - ticks[t] * dotDrawH;
                        ctx.beginPath();
                        ctx.moveTo(leftPad, yy);
                        ctx.lineTo(width - rightPad, yy);
                        ctx.stroke();
                        ctx.fillText(Math.round(maxRel * ticks[t]) + "m", leftPad - uiUnit * 0.25, yy);
                    }
                    ctx.textBaseline = "alphabetic";

                    // 연결 폴리라인
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.45);
                    ctx.setLineDash([4, 3]);
                    ctx.lineWidth = 1.5;
                    ctx.beginPath();
                    ctx.moveTo(positions[0].x, positions[0].y);
                    for (var j = 1; j < positions.length; j++)
                        ctx.lineTo(positions[j].x, positions[j].y);
                    ctx.stroke();
                    ctx.setLineDash([]);

                    // 번호 레이블 + 도트
                    ctx.font = fontPx + "px " + ScreenTools.normalFontFamily;
                    ctx.textAlign = "center";
                    for (var n = 0; n < totalWpCount; n++) {
                        var pos       = positions[n];
                        var isCurrent = (n === currentWpIndex);

                        ctx.fillStyle = isCurrent ? "#E05E00" : qgcPal.text;
                        ctx.fillText(n + 1, pos.x, labelBaseY);

                        ctx.beginPath();
                        if (isCurrent) {
                            ctx.fillStyle   = "#E05E00";
                            ctx.arc(pos.x, pos.y, dotRadius, 0, 2 * Math.PI);
                            ctx.fill();
                            ctx.strokeStyle = "white";
                            ctx.lineWidth   = Math.max(1, dotRadius * 0.33);
                            ctx.stroke();
                        } else {
                            ctx.fillStyle = "white";
                            ctx.arc(pos.x, pos.y, dotRadius * 0.66, 0, 2 * Math.PI);
                            ctx.fill();
                        }
                    }
                }
            }
        }
    }

    Item {
        id: rightPanelItem
        visible: !root.planViewActive
        Layout.preferredWidth: root.planViewActive ? 0 : (root.rightPanelStationVisible ? Math.max(0, root._rightPanelEffectiveWidth - root._panelHorizontalMargins) : 0)
        Layout.minimumWidth: root.planViewActive ? 0 : (root.rightPanelStationVisible ? Math.max(0, root._rightPanelEffectiveWidth - root._panelHorizontalMargins) : 0)
        Layout.maximumWidth: root.planViewActive ? 0 : (root.rightPanelStationVisible ? Math.max(0, root._rightPanelEffectiveWidth - root._panelHorizontalMargins) : 0)
        Layout.fillHeight: !root.planViewActive
        Layout.leftMargin: 2
        Layout.topMargin: 2
        Layout.bottomMargin: 2
        Layout.rightMargin: 2

        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.AllButtons
            onPressed: (mouse) => { mouse.accepted = true }
            onReleased: (mouse) => { mouse.accepted = true }
            onWheel: (wheel) => { wheel.accepted = true }
        }

        // 패널 우클릭 메뉴. 좌측 리사이즈 핸들(8px)은 제외해야 SizeHorCursor hover가 막히지 않는다.
        MouseArea {
            anchors.fill: parent
            anchors.leftMargin: rightPanelResizeHandle.width
            z: 2000
            acceptedButtons: Qt.RightButton
            onPressed: (mouse) => {
                root._openPanelWidthResetMenu()
                mouse.accepted = true
            }
        }

        Rectangle {
            id: stationStatusToggleButton
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 4
            anchors.topMargin: 4
            width: ScreenTools.defaultFontPixelHeight * 1.4
            height: width
            radius: width / 2
            // 열림 상태에서만 표시(접힘 시엔 맵의 재열기 버튼이 대신 표시됨)
            visible: root.rightPanelStationVisible
            // 접기 버튼: 배경 없음
            color: "transparent"
            // 리사이즈 핸들(z:2001)보다 위 → 좌상단 토글 클릭이 핸들에 먹히지 않음
            z: 2002

            QGCMouseArea {
                anchors.fill: parent
                onClicked: {
                    root.rightPanelStationVisible = !root.rightPanelStationVisible
                }
            }

            QGCColoredImage {
                anchors.centerIn: parent
                width: parent.width * 0.6
                height: width
                source: "/res/PanelFold.svg"
                fillMode: Image.PreserveAspectFit
                sourceSize.width: width
                sourceSize.height: height
                color: "#ffffff"
                // 우측 패널 접기(›)
                rotation: 180
            }
        }

        ColumnLayout {
            id: stationStatus
            anchors.fill: parent
            visible: root.rightPanelStationVisible
            spacing: 2

            StationList {
                id: stationList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: root.width > 0 ? root._panelComponentMinWidth : 0
                Layout.minimumHeight: root._panelListMinHeight
                Layout.preferredWidth: stationStatus.width
                Layout.maximumWidth: root._rightPanelEffectiveWidth
            }

            CustomStationMetrics {
                id: customStationMetrics
                Layout.fillWidth: true
                Layout.preferredWidth: stationStatus.width
                Layout.maximumWidth: root._rightPanelEffectiveWidth
            }

            StationVideo {
                id: stationVideo
                Layout.fillWidth: true
                Layout.minimumWidth: root.width > 0 ? root._panelComponentMinWidth : 0
                Layout.minimumHeight: root._panelVideoMinHeight
                Layout.preferredWidth: stationStatus.width
                Layout.preferredHeight: Math.min(stationStatus.width * 0.5625 + root._videoBarHeight, root._panelVideoMaxHeight)
                Layout.maximumWidth: root._rightPanelEffectiveWidth
                Layout.maximumHeight: root._panelVideoMaxHeight
                selectedStation: stationList.selectedStation
                channelUrl: root._effectiveStationVideoRtspUrl
                channelLabel: root._effectiveStationVideoChannelLabel
                // 목록에서 스테이션이 선택된 경우에만 재생(선택 해제 시 정지). 선택 변경 시 재연결은 StationVideo가 처리.
                streamEnabled: stationList.selectedStation !== ""
                showExpandButton: true
                onToggleMapVideoRequested: root.stationVideoOnMap = true
            }

            StationStatusMessage {
                id: stationStatusMessage
                Layout.fillWidth: true
                Layout.minimumHeight: Math.min(stationStatusMessage.implicitHeight, root._panelMessageMaxHeight)
                Layout.minimumWidth: root.width > 0 ? root._panelComponentMinWidth : 0
                Layout.preferredWidth: stationStatus.width
                Layout.preferredHeight: Math.min(Layout.preferredWidth * 0.35, root._panelMessageMaxHeight)
                Layout.maximumWidth: root._rightPanelEffectiveWidth
                Layout.maximumHeight: root._panelMessageMaxHeight
                selectedStation: stationList.selectedStation
            }

            StationControlPanel {
                id: stationControlPanel
                Layout.fillWidth: true
                Layout.minimumHeight: stationControlPanel.implicitHeight
                Layout.minimumWidth: root.width > 0 ? root._panelComponentMinWidth : 0
                Layout.preferredWidth: stationStatus.width
                Layout.preferredHeight: stationControlPanel.implicitHeight
                Layout.maximumWidth: root._rightPanelEffectiveWidth
                Layout.maximumHeight: stationControlPanel.implicitHeight * 1.25
                Layout.alignment: Qt.AlignBottom
                selectedStation: stationList.selectedStation
            }
        }

        MouseArea {
            id: rightPanelHoverArea
            anchors.fill: parent
            z: 1
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        // 좌측 모서리 드래그 → 우패널 폭 조절 (왼쪽으로 끌면 넓어짐). 우클릭 메뉴도 핸들에서 처리.
        // 토글 버튼(z:2002)보다 낮게 두어 좌상단 토글 클릭과 충돌하지 않게 함
        MouseArea {
            id: rightPanelResizeHandle
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 8
            z: 2001
            visible: root.rightPanelStationVisible && !root.planViewActive
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property real _startX: 0
            property real _startWidth: 0
            onPressed: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    root._openPanelWidthResetMenu()
                    return
                }
                _startX = mapToItem(root, mouse.x, mouse.y).x
                _startWidth = root._rightPanelEffectiveWidth
            }
            onPositionChanged: (mouse) => {
                if (!(mouse.buttons & Qt.LeftButton)) return
                var curX = mapToItem(root, mouse.x, mouse.y).x
                root._setRightPanelUserWidth(_startWidth - (curX - _startX))
            }
            onReleased: (mouse) => {
                if (mouse.button === Qt.LeftButton)
                    root._savePanelWidthsSoon()
            }
        }
    }

    Window {
        id: droneVideoExpandWindow
        visibility: (root.droneVideoOnMap && !root.expandWindowMinimized) ? (droneVideoExpandWindow._maximized ? Window.Maximized : Window.Windowed) : Window.Hidden
        width: 520
        height: 400
        x: droneVideoExpandWindow._winX
        y: droneVideoExpandWindow._winY
        flags: Qt.Window | Qt.FramelessWindowHint

        property real _winX: 0
        property real _winY: 0
        property bool _maximized: false

        onVisibilityChanged: (newVisibility) => {
            _maximized = (newVisibility === Window.Maximized)
            if (newVisibility === Window.Windowed)
                _winX = x; _winY = y
            if (newVisibility === Window.Windowed || newVisibility === Window.Maximized) {
                if (root._primaryDroneVideoTile)
                    root._primaryDroneVideoTile.attachVideoSurface(expandVideoHost)
            } else if (root._primaryDroneVideoTile) {
                root._primaryDroneVideoTile.restoreVideoSurface()
            }
        }
        onXChanged: { if (visibility === Window.Windowed) _winX = x }
        onYChanged: { if (visibility === Window.Windowed) _winY = y }

        Item {
            id: expandWindowContent
            anchors.fill: parent

            Column {
                anchors.fill: parent
                spacing: 0
                FramelessWindowTitleBar {
                    id: expandTopBar
                    width: parent.width
                    height: root._expandTitleBarHeight
                    targetWindow: droneVideoExpandWindow
                    titleText: qsTr("드론 비디오")
                    buttonWidth: root._expandButtonWidth
                    closeButtonWidth: root._expandCloseButtonWidth
                    onMinimizeRequested: root.expandWindowMinimized = true
                    onMaximizeToggleRequested: WindowHelper.toggleMaximizeRestore(droneVideoExpandWindow)
                    onCloseRequested: { root.droneVideoOnMap = false; root.expandWindowMinimized = false }
                }
                Item {
                    id: expandVideoArea
                    width: expandTopBar.width
                    height: expandWindowContent.height - expandTopBar.height
                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                    }
                    Item {
                        id: expandVideoHost
                        anchors.fill: parent
                    }
                }
            }

            WindowResizeLayer {
                targetWindow: droneVideoExpandWindow
            }
        }
    }

    Window {
        id: stationVideoExpandWindow
        visibility: (root.stationVideoOnMap && !root.stationExpandWindowMinimized) ? (stationVideoExpandWindow._maximized ? Window.Maximized : Window.Windowed) : Window.Hidden
        width: 520
        height: 400
        x: stationVideoExpandWindow._winX
        y: stationVideoExpandWindow._winY
        flags: Qt.Window | Qt.FramelessWindowHint

        property real _winX: 0
        property real _winY: 0
        property bool _maximized: false

        onVisibilityChanged: (newVisibility) => {
            _maximized = (newVisibility === Window.Maximized)
            if (newVisibility === Window.Windowed)
                _winX = x; _winY = y
            if (newVisibility === Window.Windowed || newVisibility === Window.Maximized)
                stationVideo.attachVideoSurface(stationExpandVideoHost)
            else
                stationVideo.restoreVideoSurface()
        }
        onXChanged: { if (visibility === Window.Windowed) _winX = x }
        onYChanged: { if (visibility === Window.Windowed) _winY = y }

        Item {
            id: stationExpandWindowContent
            anchors.fill: parent

            Column {
                anchors.fill: parent
                spacing: 0
                FramelessWindowTitleBar {
                    id: stationExpandTopBar
                    width: parent.width
                    height: root._expandTitleBarHeight
                    targetWindow: stationVideoExpandWindow
                    titleText: qsTr("스테이션 비디오")
                    buttonWidth: root._expandButtonWidth
                    closeButtonWidth: root._expandCloseButtonWidth
                    onMinimizeRequested: root.stationExpandWindowMinimized = true
                    onMaximizeToggleRequested: WindowHelper.toggleMaximizeRestore(stationVideoExpandWindow)
                    onCloseRequested: { root.stationVideoOnMap = false; root.stationExpandWindowMinimized = false }
                }
                Item {
                    id: stationExpandVideoArea
                    width: stationExpandTopBar.width
                    height: stationExpandWindowContent.height - stationExpandTopBar.height
                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                    }
                    Item {
                        id: stationExpandVideoHost
                        anchors.fill: parent
                    }
                }
            }

            WindowResizeLayer {
                targetWindow: stationVideoExpandWindow
            }
        }
    }

    // 사용자가 조절한 좌/우 패널 폭 영구 저장(QSettings 기반). 재시작 후에도 유지.
    // 연동 on/off는 AppSettings.panelWidthsLinked(.ini)가 SSoT.
    // MainWindowSavedState.qml과 동일한 QtCore.Settings 패턴.
    Settings {
        id: _panelWidthSettings
        category: "CustomFlyViewState"
        property real leftPanelWidth: 0
        property real rightPanelWidth: 0
    }
    Timer {
        id: _savePanelWidthTimer
        interval: 500
        repeat: false
        onTriggered: {
            _panelWidthSettings.leftPanelWidth = root.leftPanelUserWidth
            _panelWidthSettings.rightPanelWidth = root.rightPanelUserWidth
        }
    }
    function _savePanelWidthsSoon() { _savePanelWidthTimer.restart() }

    // General 탭에서 연동을 켜면 즉시 좌우 폭을 맞춤.
    Connections {
        target: root._panelWidthsLinkedFact
        function onRawValueChanged(value) {
            if (value)
                root._equalizePanelWidthsFromLeft()
        }
    }

    Component.onCompleted: {
        // 시작 시에도 "선택=활성화" 불변식 적용(이미 붙은 TCP 기체가 있으면 미선택 상태로 되돌림)
        root._syncActiveVehicleToSelection()
        // 저장된 폭 로드(0이면 _clampPanelWidth가 기본폭으로 처리). 연동은 AppSettings(.ini).
        root.leftPanelUserWidth = _panelWidthSettings.leftPanelWidth
        root.rightPanelUserWidth = _panelWidthSettings.rightPanelWidth
        if (root.panelWidthsLinked)
            root._equalizePanelWidthsFromLeft()
        if (root.droneVideoOnMap) {
            droneVideoExpandWindow._winX = (Screen.width - droneVideoExpandWindow.width) / 2
            droneVideoExpandWindow._winY = (Screen.height - droneVideoExpandWindow.height) / 2
        }
        if (root.stationVideoOnMap) {
            stationVideoExpandWindow._winX = (Screen.width - stationVideoExpandWindow.width) / 2
            stationVideoExpandWindow._winY = (Screen.height - stationVideoExpandWindow.height) / 2
        }
    }
    onDroneVideoOnMapChanged: {
        if (root.droneVideoOnMap) {
            root.expandWindowMinimized = false
            droneVideoExpandWindow._maximized = false
            droneVideoExpandWindow._winX = (Screen.width - droneVideoExpandWindow.width) / 2
            droneVideoExpandWindow._winY = (Screen.height - droneVideoExpandWindow.height) / 2
        }
    }
    onStationVideoOnMapChanged: {
        if (root.stationVideoOnMap) {
            root.stationExpandWindowMinimized = false
            stationVideoExpandWindow._maximized = false
            stationVideoExpandWindow._winX = (Screen.width - stationVideoExpandWindow.width) / 2
            stationVideoExpandWindow._winY = (Screen.height - stationVideoExpandWindow.height) / 2
        }
    }
}

/*
Column {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 10
    spacing: 8
    z:9999

    Text {
        text: "Debug Raw Input"
        color: "white"
        font.pixelSize: 14
    }
    TextArea {
        id: debugRawInput
        width: 500
        height: 170
        wrapMode: TextEdit.WrapAnywhere
        placeholderText: "raw payload"
    }

    Row {
        spacing: 8
        Button {
            text: "Inject"
            onClicked: droneManager.injectRawText(debugRawInput.text)
        }
        Button {
            text: "Clear"
            onClicked: debugRawInput.text = ""
        }
    }
}*/
