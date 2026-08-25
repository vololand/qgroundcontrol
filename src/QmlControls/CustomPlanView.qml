import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQml
import QtLocation
import QtPositioning
import QtQuick.Layouts
import QtQuick.Window

import QGroundControl
import QGroundControl.FlightMap
import QGroundControl.ScreenTools
import QGroundControl.Controls
import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Palette
import QGroundControl.Controllers
import QGroundControl.ShapeFileHelper
import QGroundControl.FlightDisplay
import QGroundControl.UTMSP

// CustomPlanView: 기존 우측 패널 유지. missionEditor에 지도+Takeoff/Waypoint+우측 편집 패널 포함. (다른 QGC 파일 수정 없음)
Item {
    id: root

    Rectangle {
        anchors.fill: parent
        z: -1
        color: root._panelBgColor
    }

    property var    planMasterController
    property bool   showToolbar: true
    property string deviceName: ""
    property real   droneStatusWidth: 0
    /// 좌측 드론 상태 패널이 접혀 있는지 (MainWindow에서 leftPanelVisible과 동기화). 펼치기 버튼 표시용
    property bool   leftPanelCollapsed: false
    property real   _lastMouseX: 0
    property var    _planMasterController:              planMasterController
    property var    _missionController:                 _planMasterController ? _planMasterController.missionController : null
    property var    _geoFenceController:                _planMasterController ? _planMasterController.geoFenceController : null
    property var    _rallyPointController:              _planMasterController ? _planMasterController.rallyPointController : null
    property var    _appSettings:                      QGroundControl.settingsManager.appSettings

    /// mainWindow.sidebarTargetWidth(SSoT)를 참조하여 CustomFlyView leftPanel과 동일한 너비 규칙 유지
    readonly property real _panelHorizontalMargins:     4
    readonly property real _missionPanelPreferredWidth: Math.max(0, mainWindow.sidebarTargetWidth - _panelHorizontalMargins)

    readonly property int   _decimalPlaces:              8
    readonly property real  _margin:                     ScreenTools.defaultFontPixelHeight * 0.5
    readonly property real  _toolsMargin:                ScreenTools.defaultFontPixelWidth * 0.75
    readonly property var   _visualItems:                _missionController ? _missionController.visualItems : null
    property bool   _utmspEnabled:                       QGroundControl.utmspSupported
    property bool   _resetGeofencePolygon:              false
    property bool   _triggerSubmit:                     false
    property bool   _resetRegisterFlightPlan:            false
    property int    _customEditingLayer:                 _layerMission
    readonly property int   _editingLayer:               _customEditingLayer
    readonly property var   _layers:                     [_layerMission, _layerGeoFence, _layerRallyPoints]
    readonly property var   _layersUTMSP:                [_layerMission, _layerRallyPoints, _layerUTMSP]
    readonly property int   _layerMission:               1
    readonly property int   _layerGeoFence:             2
    readonly property int   _layerRallyPoints:           3
    readonly property int   _layerUTMSP:                 4
    property bool           _waypointAddMode:            false
    property bool           _addROIOnClick:              false
    /// 로컬/서버 목록 또는 파일 다이얼로그에서 선택한 파일 이름 (단일 소스)
    property string         selectedPlanPath:            ""

    readonly property color _panelBgColor:       "#1a1a1a"
    readonly property color _panelCardColor:     "#252525"
    readonly property color _panelItemColor:     "#151515"
    readonly property color _panelFieldColor:    "#2a2a2a"
    readonly property color _panelHoverColor:    "#2f2f2f"
    readonly property color _panelBorderColor:   "#333333"
    readonly property color _panelBorderLight:   "#3a3a3a"
    readonly property color _panelAccentColor:   "#00BFFF"
    readonly property color _panelTextColor:     "#e0e0e0"
    readonly property color _panelMutedTextColor:"#AAAAAA"
    readonly property real  _missionActionButtonHeight: ScreenTools.implicitButtonHeight

    component PanelButton: Button {
        id: control

        property bool danger: false

        Layout.preferredHeight: root._missionActionButtonHeight
        padding:                ScreenTools.defaultFontPixelWidth
        font.family:            ScreenTools.normalFontFamily
        font.pointSize:         ScreenTools.defaultFontPointSize
        font.bold:              checked

        contentItem: QGCLabel {
            text:                   control.text
            color:                  !control.enabled ? root._panelMutedTextColor : "#ffffff"
            font:                   control.font
            horizontalAlignment:    Text.AlignHCenter
            verticalAlignment:      Text.AlignVCenter
            elide:                  Text.ElideRight
        }

        background: Rectangle {
            radius:         ScreenTools.defaultFontPixelWidth * 0.55
            color:          !control.enabled ? root._panelCardColor
                            : control.down ? (control.danger ? "#5a2a2a" : root._panelFieldColor)
                            : control.checked ? root._panelFieldColor
                            : control.hovered ? (control.danger ? "#5a2a2a" : root._panelHoverColor)
                            : root._panelCardColor
            border.color:   control.checked ? root._panelAccentColor
                            : control.danger ? "#5a2a2a"
                            : root._panelBorderLight
            border.width:   1
        }
    }

    component PanelTextField: TextField {
        id: control

        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.1
        leftPadding:            ScreenTools.defaultFontPixelWidth
        rightPadding:           ScreenTools.defaultFontPixelWidth
        color:                  "#ffffff"
        selectionColor:         root._panelAccentColor
        selectedTextColor:      "#ffffff"
        placeholderTextColor:   root._panelMutedTextColor
        font.family:            ScreenTools.normalFontFamily
        font.pointSize:         ScreenTools.defaultFontPointSize

        background: Rectangle {
            radius:         ScreenTools.defaultFontPixelWidth * 0.45
            color:          root._panelFieldColor
            border.color:   control.activeFocus ? root._panelAccentColor : "#444444"
            border.width:   1
        }
    }

    component PanelTabButton: TabButton {
        id: control

        topPadding:     Math.round(ScreenTools.defaultFontPixelHeight * 0.45)
        bottomPadding:  topPadding
        leftPadding:    ScreenTools.defaultFontPixelWidth
        rightPadding:   ScreenTools.defaultFontPixelWidth
        font.family:    ScreenTools.normalFontFamily
        font.pointSize: ScreenTools.defaultFontPointSize
        font.bold:      checked

        contentItem: QGCLabel {
            text:                   control.text
            color:                  !control.enabled ? root._panelMutedTextColor : "#ffffff"
            font:                   control.font
            horizontalAlignment:    Text.AlignHCenter
            verticalAlignment:      Text.AlignVCenter
            elide:                  Text.ElideRight
        }

        background: Rectangle {
            radius:         ScreenTools.defaultFontPixelWidth * 0.45
            color:          !control.enabled ? root._panelCardColor
                            : control.checked ? root._panelFieldColor
                            : control.hovered ? root._panelHoverColor
                            : root._panelCardColor
            border.color:   control.checked ? root._panelAccentColor : root._panelBorderLight
            border.width:   1
        }
    }

    readonly property var  _qgcVehicle:    QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool _hasQgcVehicle: _qgcVehicle !== null && _qgcVehicle !== undefined
    readonly property bool _singleComplexItem: _missionController &&
                                               _missionController.complexMissionItemNames &&
                                               _missionController.complexMissionItemNames.length === 1

    function mapCenter() {
        if (!editorMap) return QtPositioning.coordinate()
        var coordinate = editorMap.center
        coordinate.latitude  = coordinate.latitude.toFixed(_decimalPlaces)
        coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
        coordinate.altitude  = coordinate.altitude.toFixed(_decimalPlaces)
        return coordinate
    }
    function _fileNameFromPath(path) {
        var normalized = String(path || "").replace(/\\/g, "/")
        var segments = normalized.split("/").filter(function(s) { return s.length > 0 })
        return segments.length > 0 ? segments[segments.length - 1] : normalized
    }
    function _stripFileExtension(fileName) {
        var name = String(fileName || "")
        var dotIndex = name.lastIndexOf(".")
        return dotIndex > 0 ? name.substring(0, dotIndex) : name
    }
    function _displayNameFromPath(path) {
        return _stripFileExtension(_fileNameFromPath(path))
    }
    function insertSimpleItemAfterCurrent(coordinate) {
        if (!_missionController) return
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertSimpleMissionItem(coordinate, nextIndex, true)
    }
    function insertROIAfterCurrent(coordinate) {
        if (!_missionController) return
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertROIMissionItem(coordinate, nextIndex, true)
    }
    function insertCancelROIAfterCurrent() {
        if (!_missionController) return
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertCancelROIMissionItem(nextIndex, true)
    }
    function insertComplexItemAfterCurrent(complexItemName) {
        if (!_missionController) return
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertComplexMissionItem(complexItemName, mapCenter(), nextIndex, true)
    }
    function insertTakeoffItemAfterCurrent() {
        if (!_missionController) return
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertTakeoffItem(mapCenter(), nextIndex, true)
    }
    function insertLandItemAfterCurrent() {
        if (!_missionController) return
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertLandItem(mapCenter(), nextIndex, true)
    }
    function selectNextNotReady() {
        if (!_missionController || !_missionController.visualItems) return
        for (var i = 0; i < _missionController.visualItems.count; i++) {
            var vmi = _missionController.visualItems.get(i)
            if (vmi.readyForSaveState === VisualMissionItem.NotReadyForSaveData) {
                _missionController.setCurrentPlanViewSeqNum(vmi.sequenceNumber, true)
                break
            }
        }
    }

    /// QGC처럼 계획 파일 선택 창을 띄워 불러오기 (로컬 저장소 "목록 열기"에서 사용)
    function openPlanFileSelection() {
        if (!_planMasterController) return
        planFileDialog.title =       qsTr("Select Plan File")
        planFileDialog.planFiles =    true
        planFileDialog.nameFilters = _planMasterController.loadNameFilters
        planFileDialog.openForLoad()
    }

    /// 로컬 저장소: 현재 그려진 경로를 선택된 파일 이름으로 저장 (파일 다이얼로그 → saveToFile)
    function openPlanFileSave() {
        if (!_planMasterController) return
        planFileDialog.title =           qsTr("Save Plan")
        planFileDialog.planFiles =       true
        planFileDialog.nameFilters =     _planMasterController.saveNameFilters
        planFileDialog.suggestedFileName = root.selectedPlanPath
        planFileDialog.openForSave()
    }

    /// 서버 저장소: 현재 그려진 경로 + 선택된 파일 이름으로 서버에 저장 요청 (구조만, 서버 미구현)
    function savePlanToServer() {
        if (!_planMasterController || root.selectedPlanPath === "") return
        // TODO: 서버에 현재 계획 + selectedPlanPath 이름으로 저장 요청
    }

    /// 서버 저장소: 선택된 파일에 대해 서버에 삭제 요청 (확인 후 실행, 서버 미구현)
    function requestDeletePlanFromServer() {
        if (root.selectedPlanPath === "") return
        mainWindow.showMessageDialog(qsTr("삭제"),
                                     qsTr("선택된 파일 '%1' 삭제하겠습니다. 계속하시겠습니까?").arg(root.selectedPlanPath),
                                     Dialog.Yes | Dialog.No,
                                     function() {
                                         // TODO: 서버에 선택된 파일(selectedPlanPath) 삭제 요청 후 serverPlanListModel 갱신
                                     })
    }

    /// 서버 저장소: 서버에 계획 목록 요청 (후에 연결할 서버 API 호출)
    function requestServerPlanList() {
        // TODO: 서버 연결 후 목록 요청 → 수신 데이터로 serverPlanListModel 채우기
    }

    /// 서버 저장소: 목록에서 지정된 항목을 서버에 요청하여 계획 파일 받은 뒤 불러오기
    function loadPlanFromServer() {
        if (!_planMasterController || root.selectedPlanPath === "") return
        // TODO: 서버에 선택된 계획(selectedPath 또는 selectedServerPlanId) 요청
        //       → 응답 파일(또는 스트림) 수신 후 임시 파일로 저장 등
        //       → _planMasterController.loadFromFile(파일경로) 및 fitViewportToItems(), setCurrentPlanViewSeqNum(0, true)
    }

    /// 선택된 파일(로컬/서버 공통) 이름 변경 — 로컬: 파일 rename, 서버: API 호출 등 후에 구현
    function renameSelectedPlan(oldName, newName) {
        if (!newName || newName.trim() === "" || newName === oldName) return
        // TODO: 로컬 저장소면 파일 rename, 서버 저장소면 서버 API로 이름 변경 후 serverPlanListModel 갱신
    }

    /// 서버에서 받은 계획 목록 (후에 requestServerPlanList 응답으로 채움). role: name, id 등 확장 가능
    ListModel {
        id: serverPlanListModel
    }

    /// 현재 그려진 경로(계획) 삭제 — 편집기 + 기체 미션 모두 삭제 (FlyView 지도/하단 바 동시 초기화)
    function clearDrawnPlan() {
        if (!_planMasterController) return
        mainWindow.showMessageDialog(qsTr("삭제"),
                                     qsTr("현재 그려진 경로를 모두 삭제하시겠습니까?"),
                                     Dialog.Yes | Dialog.Cancel,
                                 function() {
                                     _planMasterController.removeAll()
                                     if (_missionController)
                                         _missionController.setCurrentPlanViewSeqNum(0, true)
                                     root.selectedPlanPath = ""
                                 })
    }

    QGCFileDialog {
        id:             planFileDialog
        folder:         _appSettings ? _appSettings.missionSavePath : ""
        property bool planFiles: true
        onAcceptedForLoad: (file) => {
            if (_planMasterController) {
                _planMasterController.loadFromFile(file)
                _planMasterController.fitViewportToItems()
                if (_missionController)
                    _missionController.setCurrentPlanViewSeqNum(0, true)
            }
            root.selectedPlanPath = root._displayNameFromPath(file.toString())
            close()
        }
        onAcceptedForSave: (file) => {
            if (_planMasterController) {
                _planMasterController.saveToFile(file)
            }
            root.selectedPlanPath = root._displayNameFromPath(file.toString())
            close()
        }
    }

    CustomPlanViewToolBar {
        id:                     planToolBar
        visible:                root.showToolbar
        planMasterController:   _planMasterController
    }

    function _ensurePlanViewSeqNum() {
        if (_missionController)
            _missionController.setCurrentPlanViewSeqNum(0, true)
    }
    Component.onCompleted: _ensurePlanViewSeqNum()
    onVisibleChanged: {
        if (visible) {
            // PlanView와 동일: 미션에 항목이 없으면 removeAll()로 0번 Mission Start만 생성
            if (_planMasterController && !_planMasterController.containsItems)
                _planMasterController.removeAll()
            _ensurePlanViewSeqNum()
            initSeqNumTimer.start()
            // Fly 뷰 → Custom Plan 전환 시 editorMap이 FlyViewMap과 동일한 중심/줌을 쓰도록 강제 동기화 (맵 튐/다른 맵 느낌 방지)
            if (editorMap) {
                editorMap.center = QGroundControl.flightMapPosition
                editorMap.zoomLevel = QGroundControl.flightMapZoom
            }
            syncMapTimer.start()
        }
    }
    Timer {
        id: syncMapTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (editorMap) {
                editorMap.center = QGroundControl.flightMapPosition
                editorMap.zoomLevel = QGroundControl.flightMapZoom
            }
        }
    }
    Timer {
        id: initSeqNumTimer
        interval: 150
        repeat: false
        onTriggered: _ensurePlanViewSeqNum()
    }
    Connections {
        target: root
        function on_PlanMasterControllerChanged() { _ensurePlanViewSeqNum() }
    }

    Item {
        id: contentRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: root.showToolbar ? planToolBar.bottom : parent.top
        anchors.bottom: parent.bottom

        Rectangle {
            anchors.fill: parent
            z: -1
            color: root._panelBgColor
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                id: mapPanel
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: _planMasterController !== null
                enabled: root._lastMouseX < root._mapAreaRightEdge

        FlightMap {
            id: editorMap
            anchors.fill: parent
            mapName: "MissionEditor"
            allowGCSLocationCenter: true
            allowVehicleLocationCenter: true
            planView: true
            zoomLevel: QGroundControl.flightMapZoom
            center: QGroundControl.flightMapPosition
            property rect centerViewport: Qt.rect(_leftToolWidth + _margin, _margin, Math.max(0, width - _leftToolWidth - _margin * 2), Math.max(0, height - _margin * 2))
            property real _leftToolWidth: 0
            property real _nonInteractiveOpacity: 0.5
            Component.onCompleted: editorMap.center = QGroundControl.flightMapPosition
            QGCMapPalette { id: mapPal; lightColors: editorMap.isSatelliteMap }
            onZoomLevelChanged: QGroundControl.flightMapZoom = editorMap.zoomLevel
            onCenterChanged: QGroundControl.flightMapPosition = editorMap.center
            onMapClicked: (mouse) => {
                editorMap.focus = true
                var coordinate = editorMap.toCoordinate(Qt.point(mouse.x, mouse.y), false)
                coordinate.latitude = coordinate.latitude.toFixed(_decimalPlaces)
                coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
                coordinate.altitude = coordinate.altitude.toFixed(_decimalPlaces)
                if (_utmspEnabled) QGroundControl.utmspManager.utmspVehicle.updateLastCoordinates(coordinate.latitude, coordinate.longitude)
                switch (_editingLayer) {
                case _layerMission:
                    if (root._waypointAddMode) {
                        insertSimpleItemAfterCurrent(coordinate)
                    } else if (root._addROIOnClick) {
                        insertROIAfterCurrent(coordinate)
                        root._addROIOnClick = false
                    }
                    break
                case _layerRallyPoints:
                    if (_rallyPointController && _rallyPointController.supported && root._waypointAddMode) _rallyPointController.addPoint(coordinate)
                    break
                case _layerUTMSP:
                    if (root._waypointAddMode) insertSimpleItemAfterCurrent(coordinate)
                    break
                }
            }

            Repeater {
                model: _missionController && _missionController.visualItems ? _missionController.visualItems : []
                delegate: MissionItemMapVisual {
                    map: editorMap
                    opacity: _editingLayer == _layerMission || _editingLayer == _layerUTMSP ? 1 : editorMap._nonInteractiveOpacity
                    interactive: _editingLayer == _layerMission || _editingLayer == _layerUTMSP
                    vehicle: _planMasterController ? _planMasterController.controllerVehicle : null
                    onClicked: (sequenceNumber) => { _missionController.setCurrentPlanViewSeqNum(sequenceNumber, false) }
                }
            }
            MissionLineView {
                showSpecialVisual: _missionController && _missionController.isROIBeginCurrentItem
                model: _missionController ? _missionController.simpleFlightPathSegments : null
                opacity: _editingLayer == _layerMission || _editingLayer == _layerUTMSP ? 1 : editorMap._nonInteractiveOpacity
            }
            MapItemView {
                model: _editingLayer == _layerMission || _editingLayer == _layerUTMSP && _missionController ? _missionController.directionArrows : undefined
                delegate: MapLineArrow {
                    fromCoord: object ? object.coordinate1 : undefined
                    toCoord: object ? object.coordinate2 : undefined
                    arrowPosition: 3
                    z: QGroundControl.zOrderWaypointLines + 1
                }
            }
            MapItemView {
                model: _missionController ? _missionController.incompleteComplexItemLines : null
                delegate: MapPolyline {
                    path: [object.coordinate1, object.coordinate2]
                    line.width: 1
                    line.color: "red"
                    z: QGroundControl.zOrderWaypointLines
                    opacity: _editingLayer == _layerMission ? 1 : editorMap._nonInteractiveOpacity
                }
            }
            MapQuickItem {
                id: splitSegmentItem
                anchorPoint.x: sourceItem.width / 2
                anchorPoint.y: sourceItem.height / 2
                z: QGroundControl.zOrderWaypointLines + 1
                visible: _editingLayer == _layerMission || _editingLayer == _layerUTMSP
                sourceItem: SplitIndicator {
                    onClicked: _missionController.insertSimpleMissionItem(splitSegmentItem.coordinate, _missionController.currentPlanViewVIIndex, true)
                }
                function _updateSplitCoord() {
                    if (_missionController && _missionController.splitSegment) {
                        var d = _missionController.splitSegment.coordinate1.distanceTo(_missionController.splitSegment.coordinate2)
                        var a = _missionController.splitSegment.coordinate1.azimuthTo(_missionController.splitSegment.coordinate2)
                        splitSegmentItem.coordinate = _missionController.splitSegment.coordinate1.atDistanceAndAzimuth(d / 2, a)
                    } else {
                        coordinate = QtPositioning.coordinate()
                    }
                }
                Connections {
                    target: _missionController
                    function onSplitSegmentChanged() { splitSegmentItem._updateSplitCoord() }
                }
                Connections {
                    target: _missionController && _missionController.splitSegment ? _missionController.splitSegment : null
                    function onCoordinate1Changed() { splitSegmentItem._updateSplitCoord() }
                    function onCoordinate2Changed() { splitSegmentItem._updateSplitCoord() }
                }
            }
            MapItemView {
                model: QGroundControl.multiVehicleManager.vehicles
                delegate: VehicleMapItem {
                    vehicle: object
                    coordinate: object.coordinate
                    map: editorMap
                    size: ScreenTools.defaultFontPixelHeight * 3
                    z: QGroundControl.zOrderMapItems - 1
                }
            }
            GeoFenceMapVisuals {
                map: editorMap
                myGeoFenceController: _geoFenceController
                interactive: _editingLayer == _layerGeoFence
                homePosition: _missionController ? _missionController.plannedHomePosition : null
                planView: true
                opacity: _editingLayer != _layerGeoFence ? editorMap._nonInteractiveOpacity : 1
            }
            RallyPointMapVisuals {
                map: editorMap
                myRallyPointController: _rallyPointController
                interactive: _editingLayer == _layerRallyPoints
                planView: true
                opacity: _editingLayer != _layerRallyPoints ? editorMap._nonInteractiveOpacity : 1
            }
            UTMSPMapVisuals {
                id: utmspvisual
                enabled: _utmspEnabled
                map: editorMap
                currentMissionItems: _visualItems
                myGeoFenceController: _geoFenceController
                interactive: _editingLayer == _layerUTMSP
                homePosition: _missionController ? _missionController.plannedHomePosition : null
                planView: true
                opacity: _editingLayer != _layerUTMSP ? editorMap._nonInteractiveOpacity : 1
                resetCheck: _resetGeofencePolygon
            }
            Connections { target: utmspEditor; function onResetGeofencePolygonTriggered() { resetTimer.start() } }
            Timer { id: resetTimer; interval: 2500; repeat: false; onTriggered: { _resetGeofencePolygon = true } }
        }

        MapFitFunctions {
            id: mapFitFunctions
            map: editorMap
            usePlannedHomePosition: true
            planMasterController: _planMasterController
        }

        PanelButton {
            id: centerMapBtn
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: ScreenTools.defaultFontPixelHeight
            anchors.rightMargin: ScreenTools.defaultFontPixelHeight
            z: QGroundControl.zOrderWidgets
            text: qsTr("Center")
            onClicked: centerMapPopup.open()
        }

        Popup {
            id: centerMapPopup
            parent: centerMapBtn
            x: -width + centerMapBtn.width
            y: centerMapBtn.height + ScreenTools.defaultFontPixelHeight * 0.25
            modal: false
            focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnReleaseOutside
            padding: ScreenTools.defaultFontPixelWidth
            background: Rectangle {
                color: root._panelCardColor
                radius: ScreenTools.defaultFontPixelWidth * 0.45
                border.color: root._panelBorderLight
                border.width: 1
            }
            contentItem: ColumnLayout {
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                QGCLabel {
                    text: qsTr("Center map on:")
                    color: root._panelTextColor
                }
                PanelButton {
                    text: qsTr("Mission")
                    Layout.fillWidth: true
                    onClicked: {
                        centerMapPopup.close()
                        mapFitFunctions.fitMapViewportToMissionItems()
                    }
                }
                PanelButton {
                    text: qsTr("All items")
                    Layout.fillWidth: true
                    onClicked: {
                        centerMapPopup.close()
                        mapFitFunctions.fitMapViewportToAllItems()
                    }
                }
                PanelButton {
                    text: qsTr("Launch")
                    Layout.fillWidth: true
                    onClicked: {
                        centerMapPopup.close()
                        editorMap.center = mapFitFunctions.fitHomePosition()
                    }
                }
                PanelButton {
                    text: qsTr("Vehicle")
                    Layout.fillWidth: true
                    enabled: globals.activeVehicle && globals.activeVehicle.coordinate.isValid
                    onClicked: {
                        centerMapPopup.close()
                        editorMap.center = globals.activeVehicle.coordinate
                    }
                }
                PanelButton {
                    text: qsTr("Current Location")
                    Layout.fillWidth: true
                    enabled: editorMap.gcsPosition.isValid
                    onClicked: {
                        centerMapPopup.close()
                        editorMap.center = editorMap.gcsPosition
                    }
                }
                PanelButton {
                    text: qsTr("Specified Location")
                    Layout.fillWidth: true
                    onClicked: {
                        centerMapPopup.close()
                        editorMap.centerToSpecifiedLocation()
                    }
                }
            }
        }

        Item {
            id: planWpProgressBar
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.bottom: parent.bottom
            // FlyView(_hasMissionProgress)와 동일 기준: WP가 있으면 *4, 없으면 *1.2로 축소
            height: (root._planMasterController
                     && root._planMasterController.missionController
                     && root._planMasterController.missionController.visualItems
                     && root._planMasterController.missionController.visualItems.count > 1)
                    ? ScreenTools.defaultFontPixelHeight * 4 : ScreenTools.defaultFontPixelHeight * 1.2
            z: 10

            Rectangle {
                anchors.fill: parent
                color: qgcPal.window
                opacity: 0.85
                radius: 4
                border.color: qgcPal.windowShade
                border.width: 1
            }

            // 각 WP의 고도(altPercent) 변경 감시 → 리페인트
            Repeater {
                model: root._planMasterController
                       ? root._planMasterController.missionController.visualItems : null
                delegate: Item {
                    width: 0; height: 0
                    Connections {
                        target: object
                        function onAltPercentChanged() { planPositionVisual.requestPaint() }
                    }
                }
            }

            Canvas {
                id: planPositionVisual
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPointSize

                onTotalWpCountChanged:   requestPaint()
                onCurrentWpIndexChanged: requestPaint()

                Connections {
                    target: root._planMasterController ? root._planMasterController.missionController.visualItems : null
                    function onCountChanged() { planPositionVisual.requestPaint() }
                }

                // 미션 고도 범위/홈 고도 변경 시 y축 라벨·도트 갱신
                Connections {
                    target: planPositionVisual._missionController
                    ignoreUnknownSignals: true
                    function onMaxAMSLAltitudeChanged()    { planPositionVisual.requestPaint() }
                    function onMinAMSLAltitudeChanged()    { planPositionVisual.requestPaint() }
                    function onPlannedHomePositionChanged() { planPositionVisual.requestPaint() }
                }

                // visualItems[0]은 항상 홈/설정 아이템이므로 -1 처리
                property var _visualItems:   root._planMasterController
                                             ? root._planMasterController.missionController.visualItems : null
                property var _missionController: root._planMasterController
                                             ? root._planMasterController.missionController : null
                property int totalWpCount:   root._planMasterController
                                             ? Math.max(0, root._planMasterController.missionController.visualItems.count - 1) : 0
                property int currentWpIndex: -1  // PlanView에서는 현재 비행 WP 강조 없음

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
                        var pos = positions[n];

                        ctx.fillStyle = qgcPal.text;
                        ctx.fillText(n + 1, pos.x, labelBaseY);

                        ctx.beginPath();
                        ctx.fillStyle = "white";
                        ctx.arc(pos.x, pos.y, dotRadius * 0.66, 0, 2 * Math.PI);
                        ctx.fill();
                    }
                }
            }
        }
            }

            Item {
                id: missionPanel
                Layout.preferredWidth: root._missionPanelPreferredWidth
                Layout.minimumWidth:  Math.max(0, 200 - root._panelHorizontalMargins)
                Layout.maximumWidth:  Math.max(0, mainWindow.sidebarTargetWidth - root._panelHorizontalMargins)
                Layout.fillHeight: true
                Layout.leftMargin: 2
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                Layout.rightMargin: 2

        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.NoButton
            onWheel: (wheel) => wheel.accepted = false
        }

        MouseArea {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root._missionPanelTopStripHeight
            z: 1
            acceptedButtons: Qt.AllButtons
            onPressed: (mouse) => mouse.accepted = true
            onReleased: (mouse) => mouse.accepted = true
            onPositionChanged: (mouse) => mouse.accepted = true
        }

        Rectangle {
            id: missionPanelBackground
            anchors.fill: parent
            color: root._panelBgColor
            anchors.topMargin: 10
            anchors.bottomMargin: 10

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 15

                RowLayout {
                    id: storageButtom
                    Layout.fillWidth: true
                    spacing: 10

                    PanelButton {
                        id: localBtn
                        text: qsTr("로컬저장소")
                        checkable: true
                        checked: true
                        autoExclusive: true
                        Layout.fillWidth: true
                    }

                    PanelButton {
                        id: serverBtn
                        text: qsTr("서버저장소")
                        checkable: true
                        autoExclusive: true
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    id: pathHeader
                    Layout.fillWidth: true

                    QGCLabel {
                        text: qsTr("비행 경로 불러오기")
                        color: root._panelTextColor
                    }

                    Item { Layout.fillWidth: true }

                    QGCLabel {
                        id: statusText
                        text: missionPanelBackground.pathListVisible ? qsTr("닫기 ▲") : (serverBtn.checked ? qsTr("목록 요청 ▼") : qsTr("목록 열기 ▼"))
                        color: root._panelAccentColor
                        font.bold: true

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (missionPanelBackground.pathListVisible) {
                                    missionPanelBackground.pathListVisible = false
                                } else if (serverBtn.checked) {
                                    root.requestServerPlanList()
                                    missionPanelBackground.pathListVisible = true
                                } else {
                                    root.openPlanFileSelection()
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    id: selectedFileRow
                    Layout.fillWidth: true
                    spacing: 6

                    QGCLabel {
                        text: qsTr("선택된 파일:")
                        color: root._panelMutedTextColor
                        Layout.alignment: Qt.AlignVCenter
                    }

                    PanelTextField {
                        id: selectedFileNameField
                        Layout.fillWidth: true
                        text: root.selectedPlanPath
                        placeholderText: qsTr("선택된 파일 없음")
                        onEditingFinished: {
                            var newName = text.trim()
                            if (newName !== "" && newName !== root.selectedPlanPath) {
                                root.renameSelectedPlan(root.selectedPlanPath, newName)
                                root.selectedPlanPath = newName
                            }
                        }
                    }
                }

                RowLayout {
                    id: fileAction
                    Layout.fillWidth: true
                    spacing: 8

                    PanelButton {
                        id: saveBtn
                        text: qsTr("저장")
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        onClicked: {
                            if (localBtn.checked)
                                root.openPlanFileSave()
                            else
                                root.savePlanToServer()
                        }
                    }

                    PanelButton {
                        id: loadBtn
                        text: qsTr("불러오기")
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        enabled: !localBtn.checked && root.selectedPlanPath !== ""
                        onClicked: {
                            if (serverBtn.checked)
                                root.loadPlanFromServer()
                        }
                    }

                    PanelButton {
                        id: deleteBtn
                        text: localBtn.checked ? qsTr("경로 전체 삭제") : qsTr("삭제")
                        danger: true
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        onClicked: {
                            if (localBtn.checked)
                                root.clearDrawnPlan()
                            else
                                root.requestDeletePlanFromServer()
                        }
                    }
                }

                RowLayout {
                    id: deviceSelectInfo
                    Layout.fillWidth: true

                    Item { Layout.fillWidth: true }

                    QGCLabel {
                        text: root.deviceName === "" ? qsTr("대상 기체를 선택하시오") : qsTr("선택된 기체: ") + root.deviceName
                        color: root._panelTextColor
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Item { Layout.fillWidth: true }
                }

                RowLayout{

                    id: deviceAction
                    Layout.fillWidth: true
                    spacing: 8

                    PanelButton {
                        id: uploadBtn
                        text: qsTr("업로드")
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        enabled: (root._hasQgcVehicle || root.deviceName !== "") &&
                                 !(root._planMasterController && root._planMasterController.syncInProgress)
                        onClicked: {
                            if (root._hasQgcVehicle && root._planMasterController)
                                root._planMasterController.sendToVehicle()
                        }
                    }

                    PanelButton {
                        id: deviceLoadBtn
                        text: qsTr("경로 불러오기")
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        enabled: (root._hasQgcVehicle || root.deviceName !== "") &&
                                 !(root._planMasterController && root._planMasterController.syncInProgress)
                        onClicked: {
                            if (root._hasQgcVehicle && root._planMasterController)
                                root._planMasterController.loadFromVehicle()
                        }
                    }

                    PanelButton {
                        id: deviceDeleteBtn
                        text: qsTr("업로드 경로 삭제")
                        danger: true
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        enabled: (root._hasQgcVehicle || root.deviceName !== "") &&
                                 !(root._planMasterController && root._planMasterController.syncInProgress)
                        onClicked: {
                            if (root._hasQgcVehicle && root._planMasterController)
                                root._planMasterController.removeAllFromVehicle()
                        }
                    }

                }

                ColumnLayout {
                    id: missionEditor
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: ScreenTools.defaultFontPixelHeight * 0.25

                    ColumnLayout {
                        id: missionActionSections
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelHeight * 0.35
                        visible: _editingLayer == _layerMission ||
                                 _editingLayer == _layerRallyPoints ||
                                 _editingLayer == _layerUTMSP

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: addMissionSectionLayout.implicitHeight + addMissionSectionLayout.anchors.margins * 2
                            color: root._panelCardColor
                            radius: ScreenTools.defaultFontPixelWidth * 0.45
                            border.color: root._panelBorderColor
                            border.width: 1
                            visible: _editingLayer == _layerMission || _editingLayer == _layerRallyPoints || _editingLayer == _layerUTMSP

                            ColumnLayout {
                                id: addMissionSectionLayout
                                anchors.fill: parent
                                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.6
                                spacing: ScreenTools.defaultFontPixelHeight * 0.25
                                readonly property real _buttonSpacing: 8

                                QGCLabel {
                                    text: qsTr("미션 추가")
                                    color: root._panelMutedTextColor
                                    font.bold: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: addMissionSectionLayout._buttonSpacing

                                    PanelButton {
                                        text: qsTr("Takeoff")
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 0
                                        Layout.preferredHeight: root._missionActionButtonHeight
                                        enabled: _missionController && _missionController.isInsertTakeoffValid
                                        visible: (_editingLayer == _layerMission || _editingLayer == _layerUTMSP) && _planMasterController && (!_planMasterController.controllerVehicle || !_planMasterController.controllerVehicle.rover)
                                        onClicked: {
                                            root._waypointAddMode = false
                                            root._addROIOnClick = false
                                            insertTakeoffItemAfterCurrent()
                                            _triggerSubmit = true
                                        }
                                    }
                                    PanelButton {
                                        id: addWaypointBtn
                                        text: _editingLayer == _layerRallyPoints ? qsTr("Rally Point") : qsTr("Waypoint")
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 0
                                        Layout.preferredHeight: root._missionActionButtonHeight
                                        checkable: true
                                        enabled: _editingLayer == _layerRallyPoints ? true : (_missionController && _missionController.flyThroughCommandsAllowed)
                                        visible: _editingLayer == _layerRallyPoints || _editingLayer == _layerMission || _editingLayer == _layerUTMSP
                                        onClicked: {
                                            root._waypointAddMode = addWaypointBtn.checked
                                            if (addWaypointBtn.checked)
                                                root._addROIOnClick = false
                                        }
                                    }
                                    PanelButton {
                                        id: roiBtn
                                        text: _missionController && _missionController.isROIActive ? qsTr("Cancel ROI") : qsTr("ROI")
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 0
                                        Layout.preferredHeight: root._missionActionButtonHeight
                                        checkable: _missionController && !_missionController.isROIActive
                                        enabled: _missionController && !_missionController.onlyInsertTakeoffValid
                                        visible: _editingLayer == _layerMission &&
                                                 _planMasterController &&
                                                 _planMasterController.controllerVehicle &&
                                                 _planMasterController.controllerVehicle.roiModeSupported
                                        onClicked: {
                                            root._waypointAddMode = false
                                            if (_missionController && _missionController.isROIActive) {
                                                root._addROIOnClick = false
                                                insertCancelROIAfterCurrent()
                                            } else {
                                                root._addROIOnClick = roiBtn.checked
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: finishMissionSectionLayout.implicitHeight + finishMissionSectionLayout.anchors.margins * 2
                            color: root._panelItemColor
                            radius: ScreenTools.defaultFontPixelWidth * 0.45
                            border.color: root._panelBorderColor
                            border.width: 1
                            visible: _editingLayer == _layerMission || _editingLayer == _layerUTMSP

                            ColumnLayout {
                                id: finishMissionSectionLayout
                                anchors.fill: parent
                                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.6
                                spacing: ScreenTools.defaultFontPixelHeight * 0.25
                                readonly property real _buttonSpacing: 8

                                QGCLabel {
                                    text: qsTr("패턴 / 종료")
                                    color: root._panelMutedTextColor
                                    font.bold: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: finishMissionSectionLayout._buttonSpacing

                                    PanelButton {
                                        id: patternBtn
                                        text: _singleComplexItem && _missionController ? _missionController.complexMissionItemNames[0] : qsTr("Pattern")
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 0
                                        Layout.preferredHeight: root._missionActionButtonHeight
                                        enabled: _missionController && _missionController.flyThroughCommandsAllowed
                                        visible: _editingLayer == _layerMission
                                        onClicked: {
                                            root._waypointAddMode = false
                                            root._addROIOnClick = false
                                            if (_singleComplexItem) {
                                                insertComplexItemAfterCurrent(_missionController.complexMissionItemNames[0])
                                            } else {
                                                patternPopup.open()
                                            }
                                        }
                                    }

                                    PanelButton {
                                        id:       addRTLBtn
                                        text:     qsTr("Return")
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 0
                                        Layout.preferredHeight: root._missionActionButtonHeight
                                        enabled:  _missionController && _missionController.isInsertLandValid
                                        visible:  _editingLayer == _layerMission || _editingLayer == _layerUTMSP
                                        onClicked: {
                                            root._waypointAddMode = false
                                            root._addROIOnClick = false
                                            // Return(RTL) 아이템을 현재 위치 다음에 삽입
                                            insertLandItemAfterCurrent()
                                            _triggerSubmit = true
                                        }
                                    }

                                    PanelButton {
                                        id: landPointBtn
                                        text: qsTr("Land")
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 0
                                        Layout.preferredHeight: root._missionActionButtonHeight
                                        enabled:  _missionController && _missionController.isInsertLandValid
                                        visible:  _editingLayer == _layerMission || _editingLayer == _layerUTMSP
                                        onClicked: {
                                            root._waypointAddMode = false
                                            root._addROIOnClick = false
                                            stationLandPoint.open()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Binding {
                        target: addWaypointBtn
                        property: "checked"
                        value: root._waypointAddMode
                    }
                    Binding {
                        target: roiBtn
                        property: "checked"
                        value: root._addROIOnClick
                    }

                    Popup {
                        id: patternPopup
                        parent: patternBtn
                        x: 0
                        y: patternBtn.height + ScreenTools.defaultFontPixelHeight * 0.25
                        modal: false
                        focus: true
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnReleaseOutside
                        padding: ScreenTools.defaultFontPixelWidth
                        background: Rectangle {
                            color: root._panelCardColor
                            radius: ScreenTools.defaultFontPixelWidth * 0.45
                            border.color: root._panelBorderLight
                            border.width: 1
                        }
                        contentItem: ColumnLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 0.5
                            QGCLabel {
                                text: qsTr("Create complex pattern:")
                                color: root._panelTextColor
                            }
                            Repeater {
                                model: _missionController ? _missionController.complexMissionItemNames : []
                                PanelButton {
                                    text: modelData
                                    Layout.fillWidth: true
                                    onClicked: {
                                        insertComplexItemAfterCurrent(modelData)
                                        patternPopup.close()
                                    }
                                }
                            }
                        }
                    }

                    TabBar {
                        id: customLayerTabBar
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.implicitButtonHeight
                        visible: !_utmspEnabled
                        Component.onCompleted: { currentIndex = 0; root._customEditingLayer = root._layers[0] }
                        onCurrentIndexChanged: {
                            root._customEditingLayer = root._layers[currentIndex]
                            if (root._customEditingLayer != root._layerMission && root._customEditingLayer != root._layerRallyPoints && root._customEditingLayer != root._layerUTMSP) {
                                root._waypointAddMode = false
                                root._addROIOnClick = false
                            }
                        }
                        spacing: ScreenTools.defaultFontPixelWidth * 0.5
                        background: Rectangle {
                            color: root._panelBgColor
                            radius: ScreenTools.defaultFontPixelWidth * 0.45
                            border.color: root._panelBorderColor
                            border.width: 1
                        }
                        PanelTabButton { text: qsTr("Mission") }
                        PanelTabButton { text: qsTr("Fence"); enabled: _geoFenceController && _geoFenceController.supported }
                        PanelTabButton { text: qsTr("Rally"); enabled: _rallyPointController && _rallyPointController.supported }
                    }
                    TabBar {
                        id: customLayerTabBarUTMSP
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.implicitButtonHeight
                        visible: _utmspEnabled
                        Component.onCompleted: { currentIndex = 0; root._customEditingLayer = root._layersUTMSP[0] }
                        onCurrentIndexChanged: {
                            root._customEditingLayer = root._layersUTMSP[currentIndex]
                            if (root._customEditingLayer != root._layerMission && root._customEditingLayer != root._layerRallyPoints && root._customEditingLayer != root._layerUTMSP) {
                                root._waypointAddMode = false
                                root._addROIOnClick = false
                            }
                        }
                        spacing: ScreenTools.defaultFontPixelWidth * 0.5
                        background: Rectangle {
                            color: root._panelBgColor
                            radius: ScreenTools.defaultFontPixelWidth * 0.45
                            border.color: root._panelBorderColor
                            border.width: 1
                        }
                        PanelTabButton { text: qsTr("Mission") }
                        PanelTabButton { text: qsTr("Rally"); enabled: _rallyPointController && _rallyPointController.supported }
                        PanelTabButton { text: qsTr("UTM-Adapter"); visible: _utmspEnabled }
                    }

                    Item {
                        id: missionEditorListContainer
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Rectangle {
                            anchors.fill: parent
                            color: root._panelBgColor
                            radius: ScreenTools.defaultFontPixelWidth * 0.45
                            border.color: root._panelBorderLight
                            border.width: 1
                        }
                        QGCListView {
                            id: missionItemEditorListView
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                            spacing: ScreenTools.defaultFontPixelHeight / 4
                            orientation: ListView.Vertical
                            model: _missionController ? _missionController.visualItems : null
                            cacheBuffer: Math.max(height * 2, 0)
                            clip: true
                            currentIndex: _missionController ? _missionController.currentPlanViewSeqNum : -1
                            highlightMoveDuration: 250
                            visible: _editingLayer == _layerMission
                            delegate: CustomMissionItemEditor {
                                map: editorMap
                                masterController: _planMasterController
                                missionItem: object
                                listView: missionItemEditorListView
                                width: missionItemEditorListView.width
                                readOnly: false
                                onClicked: (sequenceNumber) => { _missionController.setCurrentPlanViewSeqNum(object.sequenceNumber, false) }
                                onRemove: {
                                    var removeVIIndex = index
                                    _missionController.removeVisualItem(removeVIIndex)
                                    if (removeVIIndex >= _missionController.visualItems.count) removeVIIndex--
                                }
                                onSelectNextNotReadyItem: selectNextNotReady()
                            }
                        }
                        // 단일 DropArea 오버레이: 드롭을 여기서 받아 indexAt + move 수행. release는 다른 행으로 가므로 delegate onReleased 미호출 문제 회피.
                        Item {
                            id: missionReorderOverlay
                            anchors.fill: missionItemEditorListView
                            z: 1000
                            visible: _editingLayer == _layerMission
                            DropArea {
                                anchors.fill: parent
                                keys: ["mission-item-reorder"]
                                onEntered: (drag) => {
                                    if (drag.source && drag.source._dragStartIndex !== undefined && drag.source._dragStartIndex >= 2)
                                        drag.accepted = true
                                }
                                onDropped: (drag) => {
                                    if (!drag.source || !_missionController || typeof CustomMissionReorderHelper === "undefined" || !CustomMissionReorderHelper.moveVisualItem)
                                        return
                                    var fromIdx = drag.source._dragStartIndex
                                    if (fromIdx === undefined || fromIdx < 0) {
                                        var model = _missionController.visualItems
                                        if (!model) return
                                        for (var i = 0; i < model.count; i++) {
                                            if (model.get(i) === drag.source.missionItem) {
                                                fromIdx = i
                                                break
                                            }
                                        }
                                    }
                                    var p = missionReorderOverlay.mapToItem(missionItemEditorListView.contentItem, drag.x, drag.y)
                                    var toIdx = missionItemEditorListView.indexAt(p.x, p.y)
                                    if (toIdx < 2 || fromIdx < 2 || fromIdx === toIdx)
                                        return
                                    var item = missionItemEditorListView.itemAtIndex(toIdx)
                                    if (!item)
                                        return
                                    var inRow = p.x >= item.x && p.x < item.x + item.width && p.y >= item.y && p.y < item.y + item.height
                                    if (!inRow)
                                        return
                                    CustomMissionReorderHelper.moveVisualItem(_missionController, fromIdx, toIdx)
                                    if (missionItemEditorListView.forceLayout)
                                        Qt.callLater(missionItemEditorListView.forceLayout)
                                }
                            }
                        }
                        GeoFenceEditor {
                            anchors.fill: parent
                            myGeoFenceController: _geoFenceController
                            flightMap: editorMap
                            visible: _editingLayer == _layerGeoFence
                        }
                        RallyPointEditorHeader {
                            id: customRallyPointHeader
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            controller: _rallyPointController
                            visible: _editingLayer == _layerRallyPoints
                        }
                        RallyPointItemEditor {
                            anchors.top: customRallyPointHeader.bottom
                            anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.25
                            anchors.left: parent.left
                            anchors.right: parent.right
                            rallyPoint: _rallyPointController ? _rallyPointController.currentRallyPoint : null
                            controller: _rallyPointController
                            visible: _editingLayer == _layerRallyPoints && _rallyPointController && _rallyPointController.points.count
                        }
                        UTMSPAdapterEditor {
                            id: utmspEditor
                            enabled: _utmspEnabled
                            anchors.fill: parent
                            currentMissionItems: _visualItems
                            myGeoFenceController: _geoFenceController
                            flightMap: editorMap
                            visible: _editingLayer == _layerUTMSP
                            triggerSubmitButton: _triggerSubmit
                            resetRegisterFlightPlan: _resetRegisterFlightPlan
                        }
                        Connections {
                            target: utmspEditor
                            function onRemoveFlightPlanTriggered() {
                                if (_planMasterController) _planMasterController.removeAllFromVehicle()
                                if (_missionController) _missionController.setCurrentPlanViewSeqNum(0, true)
                                if (_utmspEnabled) _resetRegisterFlightPlan = true
                            }
                        }
                    }
                }
            }

            Popup {
                id: stationLandPoint
                anchors.centerIn: Overlay.overlay
                modal: true
                focus: true
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnReleaseOutside

                padding: 0
                background: Item {}

                width: contentItem.implicitWidth
                height: contentItem.implicitHeight

                QGCPalette { id: qgcPal; colorGroupEnabled: true }

                contentItem: Rectangle {

                    radius: 4
                    color: qgcPal.windowShade
                    border.color: qgcPal.windowShadeLight
                    border.width: 1

                    property int pad: ScreenTools.defaultFontPixelHeight * 0.8
                    property int gap: ScreenTools.defaultFontPixelWidth * 1.0
                    property int minW: ScreenTools.defaultFontPixelWidth * 90
                    property int minH: ScreenTools.defaultFontPixelHeight * 6.5

                    implicitWidth: Math.max(minW, layout.implicitWidth + pad * 2)
                    implicitHeight: Math.max(minH, layout.implicitHeight + pad * 2)

                    RowLayout {
                        id: layout
                        anchors.fill: parent
                        anchors.margins: parent.pad
                        spacing: parent.gap

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: ScreenTools.defaultFontPixelHeight * 0.6

                            Label {
                                text: qsTr("착륙 지점 선택하세요")
                                color: qgcPal.text
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.15
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 2
                                color: qgcPal.window
                                border.color: qgcPal.windowShadeLight
                                border.width: 1
                                implicitHeight: ScreenTools.defaultFontPixelHeight * 2.6

                                Repeater{
                                    ScrollView{
                                    // 스테이션 위치 정보 값
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignTop
                            spacing: ScreenTools.defaultFontPixelWidth * 0.7

                            QGCButton {
                                text: qsTr("Cancel")
                                onClicked: stationLandPoint.close()
                            }

                            QGCButton {
                                text: qsTr("Yes")
                                primary: true
                                onClicked: {
                                    stationLandPoint.close()
                                }
                            }
                        }
                    }
                }
            }

            Popup {
                id: pathContainer
                visible: missionPanelBackground.pathListVisible
                parent: pathHeader
                x: 0
                y: pathHeader.height + 5
                width: pathHeader.width
                height: 150
                padding: 0
                margins: 0
                background: Rectangle {
                    color: root._panelCardColor
                    radius: ScreenTools.defaultFontPixelWidth * 0.45
                    border.color: root._panelBorderLight
                    border.width: 1
                }
                contentItem: Item {
                    width: pathContainer.width
                    height: pathContainer.height
                    // 서버 저장소용 목록만 표시 (로컬은 목록 열기 시 파일 다이얼로그만 사용)
                    QGCLabel {
                        anchors.centerIn: parent
                        visible: serverPlanListModel && serverPlanListModel.count === 0
                        text: qsTr("서버 연결 후 '목록 요청'을 눌러 주세요.")
                        color: root._panelMutedTextColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    ScrollView {
                        anchors.fill: parent
                        visible: serverPlanListModel && serverPlanListModel.count > 0
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        contentWidth: serverPathListView.width
                        contentHeight: serverPathListView.contentHeight
                        ListView {
                            id: serverPathListView
                            model: serverPlanListModel
                            delegate: ItemDelegate {
                                width: pathContainer.width - 20
                                text: root._stripFileExtension((typeof model.name !== "undefined") ? model.name : "")
                                background: Rectangle {
                                    color: parent.down ? root._panelFieldColor : (parent.hovered ? root._panelHoverColor : "transparent")
                                    radius: ScreenTools.defaultFontPixelWidth * 0.35
                                }
                                contentItem: QGCLabel {
                                    text: parent.text
                                    color: parent.down ? "#ffffff" : root._panelTextColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 10
                                }
                                onClicked: {
                                    root.selectedPlanPath = root._stripFileExtension((typeof model.name !== "undefined") ? model.name : "")
                                    missionPanelBackground.pathListVisible = false
                                    // TODO: 서버에서 선택한 계획 불러오기
                                }
                            }
                        }
                    }
                }
            }

            property bool pathListVisible: false
        }
            }
        }
    }

    property real _missionPanelTopStripHeight: 24
    /// CustomFlyView와 동일: 맵 영역 우측 경계(루트 기준 x). 좌|맵|우 레이아웃에서 우측 패널 왼쪽 = 맵 영역 끝
    readonly property real _mapAreaRightEdge: contentRow ? (contentRow.x + missionPanel.x) : 0

    MouseArea {
        anchors.fill: parent
        z: 10000
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onPositionChanged: (mouse) => { root._lastMouseX = mouse.x; mouse.accepted = (mouse.x >= root._mapAreaRightEdge) }
        onPressed: (mouse) => {
            root._lastMouseX = mouse.x
            var inExpandZone = (root.leftPanelCollapsed && mouse.x < 32 && mouse.y < 32)
            mouse.accepted = !inExpandZone && (mouse.x >= root._mapAreaRightEdge && mouse.y < root._missionPanelTopStripHeight)
        }
        onReleased: (mouse) => {
            root._lastMouseX = mouse.x
            var inExpandZone = (root.leftPanelCollapsed && mouse.x < 32 && mouse.y < 32)
            mouse.accepted = !inExpandZone && (mouse.x >= root._mapAreaRightEdge && mouse.y < root._missionPanelTopStripHeight)
        }

        onWheel: (wheel) => {
            root._lastMouseX = wheel.x
            wheel.accepted = false
        }
    }

    // droneStatus 접었을 때만: CustomFlyView와 동일 위치(좌상단 4px 마진), 배경 없음. 클릭 시 펼치기
    QGCMouseArea {
        anchors.left: parent.left
        anchors.top: contentRow.top
        anchors.leftMargin: 4
        anchors.topMargin: 4
        width: 24
        height: 24
        visible: root.leftPanelCollapsed
        z: 10001
        preventStealing: true
        onPressed: (mouse) => mouse.accepted = true
        onReleased: (mouse) => mouse.accepted = true
        onClicked: {
            if (typeof mainWindow !== "undefined" && mainWindow.expandFlyViewLeftPanel)
                mainWindow.expandFlyViewLeftPanel()
        }
        Text {
            anchors.centerIn: parent
            text: "▶"
            color: "#ffffff"
            font.pixelSize: 14
        }
    }
}
