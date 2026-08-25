/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window

import QGroundControl
import QGroundControl.Palette
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.ScreenTools
import QGroundControl.FlightDisplay
import QGroundControl.FlightMap
import QGroundControl.Toolbar

import QGroundControl.UTMSP

/// @brief Native QML top level window
/// All properties defined here are visible to all QML pages.
ApplicationWindow {
    id:             mainWindow
    visible:        true
    flags:          Qt.Window | Qt.FramelessWindowHint

    readonly property real _desktopWindowMargin: ScreenTools.defaultFontPixelHeight * 4
    minimumHeight: Math.min(customFlyView.implicitHeight + customtoolBar.height + 40,
                            Math.max(ScreenTools.defaultFontPixelHeight * 40, Screen.height - (_desktopWindowMargin * 2)))

    property bool   _utmspSendActTrigger
    property bool   _utmspStartTelemetry
    /// Plan 뷰 / Custom Plan 뷰 진입 여부 (툴바 숨김·컨텐츠 상단 정렬용)
    property bool   _planViewShown: false
    /// true = Custom Plan View(드론상태+CustomPlanView), false = Plan Flight(PlanView)
    property bool   _customPlanViewShown: false
    /// Setup/Analyze/Settings/Management 등 toolDrawer 표시 여부. CustomFlyView 우클릭 메뉴 가드용.
    readonly property bool toolDrawerVisible: toolDrawer.visible
    /// PlanView의 planMasterController(0번 mission start 포함). FlyViewMap/CustomPlanView에서 공유
    readonly property var _planController: typeof planViewArea !== "undefined" ? planViewArea._planController : null
    
    /// 최소화 전 윈도우 상태 저장 (최대화 상태 복원용)
    property int _savedVisibilityBeforeMinimize: Window.Windowed
    /// 사용자가 의도적으로 상태를 변경했는지 여부 (최대화/복원 버튼 클릭 시 true)
    property bool _userInitiatedStateChange: false
    /// 서버 연결 상태 (0: 연결됨, 1: 연결중, 그 외: 연결끊김). DroneList backend와 동기화, 상단바 아이콘 표시용
    property int serverConnectionStatus: 2

    /// 좌측 사이드 패널 목표 폭. 전체 앱에서 공유하는 단일 출처(SSoT).
    /// AppSettings, AnalyzeView, SetupView, CustomPlanView 등이 이 값을 참조한다.
    readonly property real sidebarTargetWidth: Math.round(Math.max(ScreenTools.defaultFontPixelWidth * 34,
                                                                   Math.min(width * 0.20, ScreenTools.defaultFontPixelWidth * 46)))
    /// DroneList의 기기 목록 모델. SetupView 등 외부 컴포넌트에서 전원/연결 상태 필터링에 사용.
    readonly property var  droneDeviceListModel: customFlyView ? customFlyView.deviceListModel : null
    /// CustomFlyView 아이템 접근자. 자식 뷰(SetupView 등)는 id에 직접 접근할 수 없으므로 프로퍼티로 노출.
    readonly property var  flyViewItem: customFlyView
    /// SetupView 로드/해제에서 DroneList 선택을 변경(로드=선택, 해제="") → Edit A가 active 전환.
    function selectFlyViewDevice(name) {
        if (customFlyView && customFlyView.selectDeviceByName)
            customFlyView.selectDeviceByName(name)
    }

    Component.onCompleted: {
        firstRunPromptManager.nextPrompt()
    }

    // 최소화에서 복원 시 저장된 상태로 복원 (사용자가 의도적으로 변경한 경우 제외)
    onVisibilityChanged: (newVisibility) => {
        if (!_userInitiatedStateChange && newVisibility === Window.Windowed && _savedVisibilityBeforeMinimize === Window.Maximized) {
            Qt.callLater(function() {
                if (mainWindow.visibility === Window.Windowed && !_userInitiatedStateChange) {
                    mainWindow.showMaximized()
                }
            })
        }
        
        
        if (_userInitiatedStateChange) {
            _userInitiatedStateChange = false
        }
    }
    
    function saveVisibilityBeforeMinimize() {
        _savedVisibilityBeforeMinimize = mainWindow.visibility === Window.Maximized ? Window.Maximized : Window.Windowed
    }
    
    function setUserInitiatedStateChange() {
        _userInitiatedStateChange = true
        _savedVisibilityBeforeMinimize = mainWindow.visibility === Window.Maximized ? Window.Maximized : Window.Windowed
    }
    
    /// Saves main window position and size and re-opens it in the same position and size next time
    MainWindowSavedState {
        window: mainWindow
    }

    QtObject {
        id: firstRunPromptManager

        property var currentDialog:     null
        property var rgPromptIds:       QGroundControl.corePlugin.firstRunPromptsToShow()
        property int nextPromptIdIndex: 0

        function clearNextPromptSignal() {
            if (currentDialog) {
                currentDialog.closed.disconnect(nextPrompt)
            }
        }

        function nextPrompt() {
            if (nextPromptIdIndex < rgPromptIds.length) {
                var component = Qt.createComponent(QGroundControl.corePlugin.firstRunPromptResource(rgPromptIds[nextPromptIdIndex]));
                currentDialog = component.createObject(mainWindow)
                currentDialog.closed.connect(nextPrompt)
                currentDialog.open()
                nextPromptIdIndex++
            } else {
                currentDialog = null
                showPreFlightChecklistIfNeeded()
            }
        }
    }

    readonly property real      _topBottomMargins:          ScreenTools.defaultFontPixelHeight * 0.5

    //-------------------------------------------------------------------------
    //-- Global Scope Variables

    QtObject {
        id: globals

        readonly property var       activeVehicle:                  QGroundControl.multiVehicleManager.activeVehicle
        readonly property real      defaultTextHeight:              ScreenTools.defaultFontPixelHeight
        readonly property real      defaultTextWidth:               ScreenTools.defaultFontPixelWidth
        readonly property var       planMasterControllerFlyView:    customFlyView.planController !== undefined ? customFlyView.planController : null
        readonly property var       guidedControllerFlyView:        customFlyView.guidedController !== undefined ? customFlyView.guidedController : null

        // FlyViewMap 등 mapToItem(globals.parent, ...)용 (QGC와 동일)
        property var                parent:                         mainWindow

        // Number of QGCTextField's with validation errors. Used to prevent closing panels with validation errors.
        property int                validationErrorCount:           0 

        // Property to manage RemoteID quick access to settings page
        property bool               commingFromRIDIndicator:        false
    }

    /// Default color palette used throughout the UI
    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    //-------------------------------------------------------------------------
    //-- Actions

    signal armVehicleRequest
    signal forceArmVehicleRequest
    signal disarmVehicleRequest
    signal vtolTransitionToFwdFlightRequest
    signal vtolTransitionToMRFlightRequest
    signal showPreFlightChecklistIfNeeded

    //-------------------------------------------------------------------------
    //-- Global Scope Functions

    // This function is used to prevent view switching if there are validation errors
    function allowViewSwitch(previousValidationErrorCount = 0) {
        // Run validation on active focus control to ensure it is valid before switching views
        if (mainWindow.activeFocusControl instanceof FactTextField) {
            mainWindow.activeFocusControl._onEditingFinished()
        }
        return globals.validationErrorCount <= previousValidationErrorCount
    }

    //custom view: Plan/Custom Plan 뷰에서 뒤로갈 때 호출. 툴바 다시 표시되도록 _planViewShown 해제
    function showCustomFlyView() {
        _planViewShown = false
        _customPlanViewShown = false
    }

    /// Custom Plan 뷰에서 droneStatus(좌측 패널) 접었을 때 다시 펼치기용
    function expandFlyViewLeftPanel() {
        if (customFlyView)
            customFlyView.leftPanelVisible = true
    }

    /// Custom Plan 뷰: 좌측 droneStatus + CustomPlanView (독립 화면)
    function showCustomPlanView() {
        if (allowViewSwitch()) {
            _planViewShown = true
            _customPlanViewShown = true
        }
    }

    /// Plan Flight: PlanView만 표시 (독립 화면)
    function showPlanView() {
        _planViewShown = true
        _customPlanViewShown = false
    }

    function showFlyView() {
        _planViewShown = false
        _customPlanViewShown = false
    }

    function showTool(toolTitle, toolSource, toolIcon) {
        toolDrawer.backIcon     = customFlyView.visible ? "/qmlimages/PaperPlane.svg" : "/qmlimages/Plan.svg"
        toolDrawer.toolTitle    = toolTitle
        toolDrawer.toolSource   = toolSource
        toolDrawer.toolIcon     = toolIcon
        toolDrawer.visible      = true
    }

    function showAnalyzeTool() {
        showTool(qsTr("Analyze Tools"), "qrc:/qml/QGroundControl/AnalyzeView/AnalyzeView.qml", "/qmlimages/Analyze.svg")
    }

    function showManagementTool() {
        showTool(qsTr("Management"), "qrc:/qml/QGroundControl/ManagementView/ManagementView.qml", "/qmlimages/applicationsettingsIcon.png")
    }

    // Vehicle Configuration 열기.
    // 직접 링크 기체의 경우 자동 파라미터 로드를 생략했으므로,
    // 여기서 선택된 기체의 파라미터를 요청한다.
    function showVehicleConfig() {
        var selectedVehicle = (customFlyView && customFlyView.selectedQgcVehicle !== undefined)
                              ? customFlyView.selectedQgcVehicle : null

        if (selectedVehicle !== null) {
            // DroneList에서 선택된 기체가 있으면 해당 기체 파라미터를 요청
            _requestParametersAndShowConfig(selectedVehicle)
        } else {
            // 선택된 기체 없음: 파라미터 미로드 기체 목록을 다이얼로그로 표시
            var vehicles = QGroundControl.multiVehicleManager.vehicles
            var unloadedVehicles = []
            for (var i = 0; i < vehicles.count; i++) {
                var v = vehicles.get(i)
                if (v && !v.parameterManager.parametersReady)
                    unloadedVehicles.push(v)
            }

            if (unloadedVehicles.length === 1) {
                // 파라미터 미로드 기체가 1개면 바로 요청
                _requestParametersAndShowConfig(unloadedVehicles[0])
            } else if (unloadedVehicles.length > 1) {
                // 여러 기체 중 선택하게 함
                _vehicleSelectDialogComponent.createObject(mainWindow,
                    { vehicles: unloadedVehicles }).open()
            } else {
                // 이미 파라미터가 모두 로드된 경우 그냥 열기
                showTool(qsTr("Vehicle Configuration"), "qrc:/qml/QGroundControl/VehicleSetup/SetupView.qml", "/qmlimages/Gears.svg")
            }
        }
    }

    function _requestParametersAndShowConfig(vehicle) {
        if (!vehicle.parameterManager.parametersReady) {
            vehicle.parameterManager.refreshAllParameters()
        }
        // activeVehicle 을 선택한 기체로 설정하여 SetupView 가 올바른 기체를 보도록 함
        QGroundControl.multiVehicleManager.activeVehicle = vehicle
        showTool(qsTr("Vehicle Configuration"), "qrc:/qml/QGroundControl/VehicleSetup/SetupView.qml", "/qmlimages/Gears.svg")
    }

    // 파라미터 미로드 기체 선택 다이얼로그
    Component {
        id: _vehicleSelectDialogComponent

        QGCPopupDialog {
            title:      qsTr("기체 선택")
            buttons:    Dialog.Cancel

            property var vehicles: []

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelHeight * 0.5

                QGCLabel {
                    text: qsTr("파라미터를 불러올 기체를 선택하세요.")
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: vehicles.length

                    QGCButton {
                        Layout.fillWidth: true
                        text: {
                            var v = vehicles[index]
                            if (!v) return ""
                            var linkName = v.vehicleLinkManager ? v.vehicleLinkManager.primaryLinkName : ""
                            return qsTr("Vehicle %1").arg(v.id) + (linkName ? " (" + linkName + ")" : "")
                        }
                        onClicked: {
                            close()
                            mainWindow._requestParametersAndShowConfig(vehicles[index])
                        }
                    }
                }
            }
        }
    }

    function showVehicleConfigParametersPage() {
        showVehicleConfig()
        toolDrawerLoader.item.showParametersPanel()
    }

    function showKnownVehicleComponentConfigPage(knownVehicleComponent) {
        showVehicleConfig()
        let vehicleComponent = globals.activeVehicle.autopilotPlugin.findKnownVehicleComponent(knownVehicleComponent)
        if (vehicleComponent) {
            toolDrawerLoader.item.showVehicleComponentPanel(vehicleComponent)
        }
    }

    function showSettingsTool(settingsPage = "") {
        showTool(qsTr("Application Settings"), "qrc:/qml/QGroundControl/Controls/AppSettings.qml", "/res/GeneralWhite")
        if (settingsPage !== "") {
            var page = settingsPage
            Qt.callLater(function() {
                if (toolDrawerLoader.item && toolDrawerLoader.item.showSettingsPage) {
                    toolDrawerLoader.item.showSettingsPage(page)
                }
            })
        }
    }

    //-------------------------------------------------------------------------
    //-- Global simple message dialog

    function showMessageDialog(dialogTitle, dialogText, buttons = Dialog.Ok, acceptFunction = null, closeFunction = null) {
        simpleMessageDialogComponent.createObject(mainWindow, { title: dialogTitle, text: dialogText, buttons: buttons, acceptFunction: acceptFunction, closeFunction: closeFunction }).open()
    }

    // This variant is only meant to be called by QGCApplication
    function _showMessageDialog(dialogTitle, dialogText) {
        showMessageDialog(dialogTitle, dialogText)
    }

    Component {
        id: simpleMessageDialogComponent

        QGCSimpleMessageDialog {
        }
    }

    property bool _forceClose: false

    function finishCloseProcess() {
        _forceClose = true
        // For some reason on the Qml side Qt doesn't automatically disconnect a signal when an object is destroyed.
        // So we have to do it ourselves otherwise the signal flows through on app shutdown to an object which no longer exists.
        firstRunPromptManager.clearNextPromptSignal()
        QGroundControl.linkManager.shutdown()
        QGroundControl.videoManager.stopVideo();
        mainWindow.close()
    }

    // Check for things which should prevent the app from closing
    //  Returns true if it is OK to close
    readonly property int _skipUnsavedMissionCheckMask: 0x01
    readonly property int _skipPendingParameterWritesCheckMask: 0x02
    readonly property int _skipActiveConnectionsCheckMask: 0x04
    property int _closeChecksToSkip: 0
    function performCloseChecks() {
        if (!(_closeChecksToSkip & _skipUnsavedMissionCheckMask) && !checkForUnsavedMission()) {
            return false
        }
        if (!(_closeChecksToSkip & _skipPendingParameterWritesCheckMask) && !checkForPendingParameterWrites()) {
            return false
        }
        if (!(_closeChecksToSkip & _skipActiveConnectionsCheckMask) && !checkForActiveConnections()) {
            return false
        }
        finishCloseProcess()
        return true
    }

    property string closeDialogTitle: qsTr("Close %1").arg(QGroundControl.appName)

    function checkForUnsavedMission() {
        if (planView._planMasterController.dirty) {
            showMessageDialog(closeDialogTitle,
                              qsTr("You have a mission edit in progress which has not been saved/sent. If you close you will lose changes. Are you sure you want to close?"),
                              Dialog.Yes | Dialog.No,
                              function() { _closeChecksToSkip |= _skipUnsavedMissionCheckMask; performCloseChecks() })
            return false
        } else {
            return true
        }
    }

    function checkForPendingParameterWrites() {
        for (var index=0; index<QGroundControl.multiVehicleManager.vehicles.count; index++) {
            if (QGroundControl.multiVehicleManager.vehicles.get(index).parameterManager.pendingWrites) {
                mainWindow.showMessageDialog(closeDialogTitle,
                    qsTr("You have pending parameter updates to a vehicle. If you close you will lose changes. Are you sure you want to close?"),
                    Dialog.Yes | Dialog.No,
                    function() { _closeChecksToSkip |= _skipPendingParameterWritesCheckMask; performCloseChecks() })
                return false
            }
        }
        return true
    }

    function checkForActiveConnections() {
        if (QGroundControl.multiVehicleManager.activeVehicle) {
            mainWindow.showMessageDialog(closeDialogTitle,
                qsTr("There are still active connections to vehicles. Are you sure you want to exit?"),
                Dialog.Yes | Dialog.No,
                function() { _closeChecksToSkip |= _skipActiveConnectionsCheckMask; performCloseChecks() })
            return false
        } else {
            return true
        }
    }

    onClosing: (close) => {
        if (!_forceClose) {
            _closeChecksToSkip = 0
            close.accepted = performCloseChecks()
        }
    }

    background: Rectangle {
        anchors.fill:   parent
        color:          QGroundControl.globalPalette.window
    }

    // 툴바 하나로 통일 (Fly / Custom Plan 동일)
    Item {
        id: toolbarContainer
        anchors.top: parent.top
        width: parent.width
        height: (visible ? ScreenTools.toolbarHeight : 0)
        visible: !mainWindow._planViewShown || mainWindow._customPlanViewShown || toolDrawer.visible

        CustomToolbar {
            id: customtoolBar
            anchors.fill: parent
            visible: true
            showPlanReturnButton: mainWindow._customPlanViewShown || toolDrawer.visible
            returnAction: toolDrawer.visible
                ? function() { if (mainWindow.allowViewSwitch()) toolDrawer.visible = false }
                : function() { mainWindow.showCustomFlyView() }
        }
    }

    // Fly/Plan 뷰 컨테이너
    Item {
        id: flyPlanContainer
        anchors.top: (mainWindow._customPlanViewShown || !mainWindow._planViewShown) ? toolbarContainer.bottom : parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        RowLayout {
                anchors.fill: parent
                spacing: 0
                CustomFlyView {
                    id: customFlyView
                    Layout.fillHeight: true
                    Layout.fillWidth: !mainWindow._planViewShown
                    Layout.preferredWidth: mainWindow._planViewShown
                                        ? (mainWindow._customPlanViewShown && customFlyView.leftPanelVisible ? customFlyView.leftPanelWidth : 0)
                                        : 0
                    planViewActive: mainWindow._customPlanViewShown
                    planMasterController: mainWindow._planController
                }
                Item {
                    id: planViewArea
                    Layout.fillWidth: mainWindow._planViewShown
                    Layout.fillHeight: mainWindow._planViewShown
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 0
                    readonly property var _planController: planView._planMasterController
                    PlanView {
                        id: planView
                        anchors.fill: parent
                        visible: mainWindow._planViewShown && !mainWindow._customPlanViewShown
                        z: mainWindow._customPlanViewShown ? 0 : 1
                    }
                    CustomPlanView {
                        id: customPlanView
                        anchors.fill: parent
                        visible: mainWindow._customPlanViewShown
                        z: mainWindow._customPlanViewShown ? 1 : 0
                        planMasterController: planViewArea._planController
                        showToolbar: false
                        deviceName: customFlyView.selectedDeviceName
                        droneStatusWidth: mainWindow._customPlanViewShown ? customFlyView.leftPanelWidth : 0
                        leftPanelCollapsed: mainWindow._customPlanViewShown && !customFlyView.leftPanelVisible
                    }
                }
            }
        Connections {
            target: planView
            function onVisibleChanged() {
                if (!planView.visible && !customPlanView.visible)
                    mainWindow._planViewShown = false
            }
        }
        Connections {
            target: customPlanView
            function onVisibleChanged() {
                if (!planView.visible && !customPlanView.visible)
                    mainWindow._planViewShown = false
            }
        }
    }

    // 프레임리스 윈도우 드래그 및 우클릭 메뉴 처리
    MouseArea {
        id: windowDragArea
        anchors.top: parent.top
        height: customtoolBar.visible ? customtoolBar.height : 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.ArrowCursor
        z: -100
        enabled: true
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: customtoolBar.visible ? customtoolBar.dragAreaLeft : 0
        anchors.rightMargin: customtoolBar.visible ? customtoolBar.dragAreaRight : 0

        property point _pressPos: Qt.point(0, 0)
        property bool _dragStarted: false
        
        onPressed: (mouse) => {
            if (customtoolBar.visible) {
                var toolbarPos = mapToItem(customtoolBar, mouse.x, mouse.y)
                var leftButtonArea = toolbarPos.x < customtoolBar.dragAreaLeft
                var rightButtonArea = toolbarPos.x > (customtoolBar.width - customtoolBar.dragAreaRight)
                if (leftButtonArea || rightButtonArea) {
                    mouse.accepted = false
                    return
                }
            }
            if (mouse.button === Qt.LeftButton) {
                _pressPos = Qt.point(mouse.x, mouse.y)
                _dragStarted = false
            } else if (mouse.button === Qt.RightButton) {
                // 우클릭: Windows 시스템 메뉴 표시
                if (!ScreenTools.isMobile && mainWindow.visibility !== Window.FullScreen) {
                    var rootPos = mapToItem(mainWindow.contentItem, mouse.x, mouse.y)
                    var globalX = mainWindow.x + rootPos.x
                    var globalY = mainWindow.y + rootPos.y
                    
                    WindowHelper.showSystemMenu(mainWindow, globalX, globalY)
                    mouse.accepted = true
                }
            }
        }
        
        // 타이틀바 더블클릭: Windows 기본 동작 (최대화/복원 토글)
        // 단일 클릭은 툴바·버튼으로 전달되므로 onDoubleClicked만 처리
        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton && !ScreenTools.isMobile && mainWindow.visibility !== Window.FullScreen) {
                mainWindow.setUserInitiatedStateChange()
                WindowHelper.toggleMaximizeRestore(mainWindow)
            }
        }
        
        onPositionChanged: (mouse) => {
            if (mouse.buttons & Qt.LeftButton && !_dragStarted) {
                var deltaX = Math.abs(mouse.x - _pressPos.x)
                var deltaY = Math.abs(mouse.y - _pressPos.y)
                
                // 최소 이동 거리 체크 (드래그 시작으로 간주) - 5픽셀 이상
                if (deltaX > 5 || deltaY > 5) {
                    _dragStarted = true
                    
                    if (mainWindow.visibility === Window.Windowed) {
                        var rootPos = mapToItem(mainWindow.contentItem, _pressPos.x, _pressPos.y)
                        WindowHelper.startSystemMove(mainWindow, rootPos.x, rootPos.y)
                    }
                    // 최대화 상태에서는 드래그하지 않음 (복원 로직 제거)
                }
            }
        }
        
        onReleased: (mouse) => {
            if (_dragStarted && mouse.button === Qt.LeftButton) {
                var rootPos = mapToItem(mainWindow.contentItem, mouse.x, mouse.y)
                var globalX = mainWindow.x + rootPos.x
                var globalY = mainWindow.y + rootPos.y
                
                // Aero Snap 처리 (상단/좌/우 가장자리 감지)
                if (!ScreenTools.isMobile && mainWindow.visibility !== Window.FullScreen) {
                    WindowHelper.handleAeroSnap(mainWindow, globalX, globalY)
                }
            }
            _dragStarted = false
        }
    }

    // 창 테두리 드래그 리사이즈 (상·하·좌·우)
    Item {
        id: windowEdgeResizeLayer
        anchors.fill: parent
        z: 50
        visible: !ScreenTools.isMobile && mainWindow.visibility !== Window.FullScreen && mainWindow.visibility !== Window.Maximized

        property int _edgeSize: 5
        property int _cornerSize: 10

        // 좌상·우상·좌하·우하 모서리 드래그 리사이즈
        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            width: windowEdgeResizeLayer._cornerSize
            height: windowEdgeResizeLayer._cornerSize
            cursorShape: Qt.SizeFDiagCursor
            acceptedButtons: Qt.LeftButton
            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    WindowHelper.startSystemResize(mainWindow, Qt.TopEdge | Qt.LeftEdge)
                }
            }
        }
        MouseArea {
            anchors.right: parent.right
            anchors.top: parent.top
            width: windowEdgeResizeLayer._cornerSize
            height: windowEdgeResizeLayer._cornerSize
            cursorShape: Qt.SizeBDiagCursor
            acceptedButtons: Qt.LeftButton
            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    WindowHelper.startSystemResize(mainWindow, Qt.TopEdge | Qt.RightEdge)
                }
            }
        }
        MouseArea {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: windowEdgeResizeLayer._cornerSize
            height: windowEdgeResizeLayer._cornerSize
            cursorShape: Qt.SizeBDiagCursor
            acceptedButtons: Qt.LeftButton
            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    WindowHelper.startSystemResize(mainWindow, Qt.BottomEdge | Qt.LeftEdge)
                }
            }
        }
        MouseArea {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: windowEdgeResizeLayer._cornerSize
            height: windowEdgeResizeLayer._cornerSize
            cursorShape: Qt.SizeFDiagCursor
            acceptedButtons: Qt.LeftButton
            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    WindowHelper.startSystemResize(mainWindow, Qt.BottomEdge | Qt.RightEdge)
                }
            }
        }

        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: windowEdgeResizeLayer._edgeSize
            cursorShape: Qt.SizeHorCursor
            acceptedButtons: Qt.LeftButton
            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    WindowHelper.startSystemResize(mainWindow, Qt.LeftEdge)
                }
            }
        }
        MouseArea {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: windowEdgeResizeLayer._edgeSize
            cursorShape: Qt.SizeHorCursor
            acceptedButtons: Qt.LeftButton
            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    WindowHelper.startSystemResize(mainWindow, Qt.RightEdge)
                }
            }
        }
        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: windowEdgeResizeLayer._edgeSize
            cursorShape: Qt.SizeVerCursor
            acceptedButtons: Qt.LeftButton
            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    WindowHelper.startSystemResize(mainWindow, Qt.TopEdge)
                }
            }
        }
        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: windowEdgeResizeLayer._edgeSize
            cursorShape: Qt.SizeVerCursor
            acceptedButtons: Qt.LeftButton
            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    WindowHelper.startSystemResize(mainWindow, Qt.BottomEdge)
                }
            }
        }
    }

    footer: LogReplayStatusBar {
        visible: QGroundControl.settingsManager.flyViewSettings.showLogReplayStatusBar.rawValue
    }

    MessageDialog {
        id:                 showTouchAreasNotification
        title:              qsTr("Debug Touch Areas")
        text:               qsTr("Touch Area display toggled")
        buttons:            MessageDialog.Ok
    }

    MessageDialog {
        id:                 advancedModeOnConfirmation
        title:              qsTr("Advanced Mode")
        text:               QGroundControl.corePlugin.showAdvancedUIMessage
        buttons:            MessageDialog.Yes | MessageDialog.No
        onButtonClicked: function (button, role) {
            if (button === MessageDialog.Yes) {
                QGroundControl.corePlugin.showAdvancedUI = true
            }
        }
    }

    MessageDialog {
        id:                 advancedModeOffConfirmation
        title:              qsTr("Advanced Mode")
        text:               qsTr("Turn off Advanced Mode?")
        buttons:            MessageDialog.Yes | MessageDialog.No
        onButtonClicked: function (button, role) {
            if (button === MessageDialog.Yes) {
                QGroundControl.corePlugin.showAdvancedUI = false
            }
        }
    }

    function showToolSelectDialog() {
        if (mainWindow.allowViewSwitch()) {
            mainWindow.showIndicatorDrawer(toolSelectComponent, null)
        }
    }

    Component {
        id: toolSelectComponent

        ToolIndicatorPage {
            id:         toolSelectDialog

            property real _toolButtonHeight:    ScreenTools.defaultFontPixelHeight * 3
            property real _margins:             ScreenTools.defaultFontPixelWidth

            contentComponent: Component {
                ColumnLayout {
                    width:  indicatorDrawer._leftPanelStyleWidth
                    height: mainWindow.height - indicatorDrawer.y - (2 * indicatorDrawer._margins)

                    ColumnLayout {
                        id:             innerLayout
                        Layout.fillWidth: true
                        Layout.margins: toolSelectDialog._margins
                        spacing:        ScreenTools.defaultFontPixelWidth

                        SubMenuButton {
                            //height:             toolSelectDialog._toolButtonHeight
                            Layout.preferredHeight: toolSelectDialog._toolButtonHeight
                            Layout.fillWidth:   true
                            text:               qsTr("Plan View")
                            imageResource:      "/qmlimages/planviewIcon.png"
                            onClicked: {
                                if (mainWindow.allowViewSwitch()) {
                                    mainWindow.closeIndicatorDrawer()
                                    mainWindow.showCustomPlanView()
                                }
                            }
                        }

                        SubMenuButton {
                            id:                 analyzeButton
                            //height:             toolSelectDialog._toolButtonHeight
                            Layout.preferredHeight: toolSelectDialog._toolButtonHeight
                            Layout.fillWidth:   true
                            text:               qsTr("Analyze Tools")
                            imageResource:      "/qmlimages/analyzetoolsIcon.png"
                            visible:            QGroundControl.corePlugin.showAdvancedUI
                            onClicked: {
                                if (mainWindow.allowViewSwitch()) {
                                    mainWindow.closeIndicatorDrawer()
                                    mainWindow.showAnalyzeTool()
                                }
                            }
                        }

                        SubMenuButton {
                            id:                 setupButton
                            //height:             toolSelectDialog._toolButtonHeight
                            Layout.preferredHeight: toolSelectDialog._toolButtonHeight
                            Layout.fillWidth:   true
                            text:               qsTr("Vehicle Configuration")
                            imageResource:      "/qmlimages/Gears.svg"
                            onClicked: {
                                if (mainWindow.allowViewSwitch()) {
                                    mainWindow.closeIndicatorDrawer()
                                    mainWindow.showVehicleConfig()
                                }
                            }
                        }

                        SubMenuButton {
                            id:                 settingsButton
                            //height:             toolSelectDialog._toolButtonHeight
                            Layout.preferredHeight: toolSelectDialog._toolButtonHeight
                            Layout.fillWidth:   true
                            text:               qsTr("Application Settings")
                            imageResource:      "/qmlimages/applicationsettingsIcon.png"
                            imageColor:         "transparent"
                            visible:            !QGroundControl.corePlugin.options.combineSettingsAndSetup
                            onClicked: {
                                if (mainWindow.allowViewSwitch()) {
                                    drawer.close()
                                    mainWindow.showSettingsTool()
                                }
                            }
                        }

                        SubMenuButton {
                            id:                 managementMenuButton
                            Layout.preferredHeight: toolSelectDialog._toolButtonHeight
                            Layout.fillWidth:   true
                            text:               qsTr("Management")
                            imageResource:      "/qmlimages/applicationsettingsIcon.png"
                            imageColor:         "transparent"
                            visible:            !QGroundControl.corePlugin.options.combineSettingsAndSetup
                            onClicked: {
                                if (mainWindow.allowViewSwitch()) {
                                    mainWindow.closeIndicatorDrawer()
                                    mainWindow.showManagementTool()
                                }
                            }
                        }

                        SubMenuButton {
                            id:                 closeButton
                            height:             toolSelectDialog._toolButtonHeight
                            Layout.fillWidth:   true
                            text:               qsTr("Close %1").arg(QGroundControl.appName)
                            imageResource:      "/res/cancel.svg"
                            visible:            mainWindow.visibility === Window.FullScreen
                            onClicked: {
                                if (mainWindow.allowViewSwitch()) {
                                    mainWindow.finishCloseProcess()
                                }
                            }
                        }

                        ColumnLayout {
                            width:                  innerLayout.width
                            spacing:                0
                            Layout.alignment:       Qt.AlignHCenter

                            QGCLabel {
                                id:                     versionLabel
                                text:                   qsTr("%1 Version").arg(QGroundControl.appName)
                                font.pointSize:         ScreenTools.smallFontPointSize
                                wrapMode:               QGCLabel.WordWrap
                                Layout.maximumWidth:    parent.width
                                Layout.alignment:       Qt.AlignHCenter
                                visible: false 
                            }

                            QGCLabel {
                                text:                   QGroundControl.qgcVersion
                                font.pointSize:         ScreenTools.smallFontPointSize
                                wrapMode:               QGCLabel.WrapAnywhere
                                Layout.maximumWidth:    parent.width
                                Layout.alignment:       Qt.AlignHCenter
                                visible: false 

                                QGCMouseArea {
                                    id:                 easterEggMouseArea
                                    anchors.topMargin:  -versionLabel.height
                                    anchors.fill:       parent

                                    onClicked: (mouse) => {
                                        if (mouse.modifiers & Qt.ControlModifier) {
                                            QGroundControl.corePlugin.showTouchAreas = !QGroundControl.corePlugin.showTouchAreas
                                            showTouchAreasNotification.open()
                                        } else if (ScreenTools.isMobile || mouse.modifiers & Qt.ShiftModifier) {
                                            mainWindow.closeIndicatorDrawer()
                                            if(!QGroundControl.corePlugin.showAdvancedUI) {
                                                advancedModeOnConfirmation.open()
                                            } else {
                                                advancedModeOffConfirmation.open()
                                            }
                                        }
                                    }

                                    // This allows you to change this on mobile
                                    onPressAndHold: {
                                        QGroundControl.corePlugin.showTouchAreas = !QGroundControl.corePlugin.showTouchAreas
                                        showTouchAreasNotification.open()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id:             toolDrawer
        anchors.top:    toolbarContainer.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        visible:        false
        color:          qgcPal.window

        property var backIcon
        property string toolTitle
        property alias toolSource:  toolDrawerLoader.source
        property var toolIcon

        onVisibleChanged: {
            if (!toolDrawer.visible) {
                toolDrawerLoader.source = ""
            }
        }

        // This need to block click event leakage to underlying map.
        DeadMouseArea {
            anchors.fill: parent
        }

        Loader {
            id:             toolDrawerLoader
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    parent.top
            anchors.bottom: parent.bottom

            Connections {
                target:                 toolDrawerLoader.item
                ignoreUnknownSignals:   true
                onPopout:               toolDrawer.visible = false
            }
        }
    }

    //-------------------------------------------------------------------------
    //-- Critical Vehicle Message Popup

    function showCriticalVehicleMessage(message) {
        /*
        closeIndicatorDrawer()
        if (criticalVehicleMessagePopup.visible || QGroundControl.videoManager.fullScreen) {
            // We received additional warning message while an older warning message was still displayed.
            // When the user close the older one drop the message indicator tool so they can see the rest of them.
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = true
        } else {
            criticalVehicleMessagePopup.criticalVehicleMessage      = message
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false
            criticalVehicleMessagePopup.open()
        }
        */
    }

    Popup {
        id:                 criticalVehicleMessagePopup
        y:                  ScreenTools.toolbarHeight + ScreenTools.defaultFontPixelHeight
        x:                  Math.round((mainWindow.width - width) * 0.5)
        width:              mainWindow.width  * 0.55
        height:             criticalVehicleMessageText.contentHeight + ScreenTools.defaultFontPixelHeight * 2
        modal:              false
        focus:              true

        property alias  criticalVehicleMessage:             criticalVehicleMessageText.text
        property bool   additionalCriticalMessagesReceived: false

        background: Rectangle {
            anchors.fill:   parent
            color:          qgcPal.alertBackground
            radius:         ScreenTools.defaultFontPixelHeight * 0.5
            border.color:   qgcPal.alertBorder
            border.width:   2

            Rectangle {
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.top:                parent.top
                anchors.topMargin:          -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      vehicleWarningLabel.contentWidth + _margins
                height:                     vehicleWarningLabel.contentHeight + _margins

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 vehicleWarningLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Vehicle Error")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }

            Rectangle {
                id:                         additionalErrorsIndicator
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.bottom:             parent.bottom
                anchors.bottomMargin:       -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      additionalErrorsLabel.contentWidth + _margins
                height:                     additionalErrorsLabel.contentHeight + _margins
                visible:                    criticalVehicleMessagePopup.additionalCriticalMessagesReceived

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 additionalErrorsLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Additional errors received")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }
        }

        QGCLabel {
            id:                 criticalVehicleMessageText
            width:              criticalVehicleMessagePopup.width - ScreenTools.defaultFontPixelHeight
            anchors.centerIn:   parent
            wrapMode:           Text.WordWrap
            color:              qgcPal.alertText
            textFormat:         TextEdit.RichText
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                criticalVehicleMessagePopup.close()
                if (criticalVehicleMessagePopup.additionalCriticalMessagesReceived) {
                    criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false;
                    customFlyView.dropMainStatusIndicatorTool !== undefined && customFlyView.dropMainStatusIndicatorTool();
                } else {
                    QGroundControl.multiVehicleManager.activeVehicle.resetErrorLevelMessages();
                }
            }
        }
    }

    //-------------------------------------------------------------------------
    //-- Indicator Drawer

    function showIndicatorDrawer(drawerComponent, indicatorItem) {
        indicatorDrawer.sourceComponent = drawerComponent
        indicatorDrawer.indicatorItem = indicatorItem
        indicatorDrawer.open()
    }

    function closeIndicatorDrawer() {
        indicatorDrawer.close()
    }

    Popup {
        id:             indicatorDrawer
        x:              calcXPosition()
        y:              calcYPosition()
        leftInset:      0
        rightInset:     0
        topInset:       0
        bottomInset:    0
        padding:        indicatorItem ? (_margins * 2) : 0
        visible:        false
        modal:          true
        focus:          true
        closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var sourceComponent
        property var indicatorItem

        property bool _expanded:    false
        property real _margins:     ScreenTools.defaultFontPixelHeight / 4
        readonly property real _leftPanelStyleWidth: Math.max(0, mainWindow.sidebarTargetWidth - 4)

        function calcXPosition() {
            if (indicatorItem) {
                var xCenter = indicatorItem.mapToItem(mainWindow.contentItem, indicatorItem.width / 2, 0).x
                return Math.max(_margins, Math.min(xCenter - (contentItem.implicitWidth / 2), mainWindow.contentItem.width - contentItem.implicitWidth - _margins - (indicatorDrawer.padding * 2) - (ScreenTools.defaultFontPixelHeight / 2)))
            } else {
                return 2  // leftPanel과 동일: Layout.leftMargin
            }
        }

        function calcYPosition() {
            return ScreenTools.toolbarHeight + 2  // 상단바 아래, leftPanel과 동일 Layout.topMargin
        }

        onOpened: {
            _expanded                               = false;
            indicatorDrawerLoader.sourceComponent   = indicatorDrawer.sourceComponent
        }
        onClosed: {
            _expanded                               = false
            indicatorItem                           = undefined
            indicatorDrawerLoader.sourceComponent   = undefined
        }

        background: Item {
            Rectangle {
                id:             backgroundRect
                anchors.fill:   parent
                color:          QGroundControl.globalPalette.window
                radius:         0
                opacity:        1.0
            }

            Rectangle {
                anchors.horizontalCenter:   backgroundRect.right
                anchors.verticalCenter:     backgroundRect.top
                width:                      ScreenTools.largeFontPixelHeight
                height:                     width
                radius:                     width / 2
                color:                      QGroundControl.globalPalette.button
                border.color:               QGroundControl.globalPalette.buttonText
                visible:                    indicatorDrawerLoader.item && indicatorDrawerLoader.item.showExpand && !indicatorDrawer._expanded

                QGCLabel {
                    anchors.centerIn:   parent
                    text:               ">"
                    color:              QGroundControl.globalPalette.buttonText
                }  

                QGCMouseArea {
                    fillItem: parent
                    onClicked: indicatorDrawer._expanded = true
                }
            }
        }

        contentItem: QGCFlickable {
            id:             indicatorDrawerLoaderFlickable
            implicitWidth:  indicatorDrawer.indicatorItem ? Math.min(mainWindow.contentItem.width - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.width) : indicatorDrawer._leftPanelStyleWidth
            implicitHeight: Math.min(mainWindow.contentItem.height - ScreenTools.toolbarHeight - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.height)
            contentWidth:   indicatorDrawerLoader.width
            contentHeight:  indicatorDrawerLoader.height

            Loader {
                id: indicatorDrawerLoader

                Binding {
                    target:     indicatorDrawerLoader.item
                    property:   "expanded"
                    value:      indicatorDrawer._expanded
                }

                Binding {
                    target:     indicatorDrawerLoader.item
                    property:   "drawer"
                    value:      indicatorDrawer
                }
            }
        }
    }

    // We have to create the popup windows for the Analyze pages here so that the creation context is rooted
    // to mainWindow. Otherwise if they are rooted to the AnalyzeView itself they will die when the analyze viewSwitch
    // closes.

    function createrWindowedAnalyzePage(title, source) {
        var windowedPage = windowedAnalyzePage.createObject(mainWindow)
        windowedPage.title = title
        windowedPage.source = source
    }

    Component {
        id: windowedAnalyzePage

        Window {
            width:      ScreenTools.defaultFontPixelWidth  * 100
            height:     ScreenTools.defaultFontPixelHeight * 40
            visible:    true

            property alias source: loader.source

            Rectangle {
                color:          QGroundControl.globalPalette.window
                anchors.fill:   parent

                Loader {
                    id:             loader
                    anchors.fill:   parent
                    onLoaded:       item.popped = true
                }
            }

            onClosing: {
                visible = false
                source = ""
            }
        }
    }

    Connections{
         target: activationbar
         function onActivationTriggered(value){
              _utmspSendActTrigger= value
         }
    }

    UTMSPActivationStatusBar{
         id:                         activationbar
         activationStartTimestamp:   UTMSPStateStorage.startTimeStamp
         activationApproval:         UTMSPStateStorage.showActivationTab && QGroundControl.utmspManager.utmspVehicle.vehicleActivation
         flightID:                   UTMSPStateStorage.flightID
         anchors.fill:               parent
    }
}
