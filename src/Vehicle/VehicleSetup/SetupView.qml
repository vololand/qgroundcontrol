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

import QGroundControl
import QGroundControl.AutoPilotPlugin
import QGroundControl.Palette
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.MultiVehicleManager

Rectangle {
    id:     setupView
    color:  qgcPal.window
    z:      QGroundControl.zOrderTopMost

    DeadMouseArea {
        anchors.fill: parent
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    readonly property real      _defaultTextHeight: ScreenTools.defaultFontPixelHeight
    readonly property real      _defaultTextWidth:  ScreenTools.defaultFontPixelWidth
    readonly property real      _horizontalMargin:  _defaultTextWidth / 2
    readonly property real      _verticalMargin:    _defaultTextHeight / 2
    readonly property real      _buttonWidth:       _defaultTextWidth * 18
    readonly property real      _sidebarTargetWidth:    mainWindow.sidebarTargetWidth
    readonly property real      _buttonColumnWidth:     _sidebarTargetWidth - _horizontalMargin - 1
    readonly property string    _armedVehicleText:  qsTr("This operation cannot be performed while the vehicle is armed.")

    property bool   _vehicleArmed:                  QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle.armed : false
    property string _messagePanelText:              qsTr("missing message panel text")
    property bool   _fullParameterVehicleAvailable: QGroundControl.multiVehicleManager.parameterReadyVehicleAvailable && !QGroundControl.multiVehicleManager.activeVehicle.parameterManager.missingParameters
    property var    _corePlugin:                    QGroundControl.corePlugin
    property bool   _hasPortScanner:                typeof QGroundControl.portScanner !== "undefined" && QGroundControl.portScanner !== null
    property bool   _pendingParamRequest:           false

    function _portNameForVehicle(vehicle) {
        if (!vehicle || !vehicle.vehicleLinkManager)
            return ""
        var lname = vehicle.vehicleLinkManager.primaryLinkName
        var prefix = "Pixhawk-"
        if (typeof lname === "string" && lname.indexOf(prefix) === 0)
            return lname.substring(prefix.length)
        return ""
    }

    function _rowMatchesActiveVehicle(nodeType, portName, deviceName) {
        var av = QGroundControl.multiVehicleManager.activeVehicle
        if (!av)
            return false
        var pn = portName || ""
        var dn = deviceName || ""
        if (nodeType === "port" && pn !== "") {
            var linkPn = _portNameForVehicle(av)
            if (linkPn !== "")
                return pn === linkPn
            return false
        }
        if (nodeType === "device") {
            if (dn === ("Vehicle " + av.id))
                return true
            var cfv = mainWindow.flyViewItem
            if (cfv && cfv.selectedQgcVehicle === av && dn === cfv.selectedDeviceName)
                return true
            return false
        }
        return false
    }

    /// [Custom] 현재 "실제로 연결된" 기체가 네트워크(TCP/UDP/암호화TCP) 링크를 쓰는지 확인.
    /// 주의: cfg.link 존재 여부로 판단하면 안 된다. 암호화 TCP 링크는 끊겨도(_onPipeDisconnected)
    /// 재연결을 위해 링크 객체를 유지하므로 cfg.link가 계속 truthy다(= false positive).
    /// 따라서 실제 연결의 신뢰 신호인 "연결된 vehicle"을 기준으로, 그 vehicle의 primaryLink가
    /// 네트워크 타입인지 확인한다. TCP가 끊기면 vehicle은 comm-lost 후 목록에서 제거되어 경고가 사라진다.
    function _linkNameIsNetworkType(linkName) {
        var configs = QGroundControl.linkManager.linkConfigurations
        if (!configs || !linkName)
            return false
        for (var i = 0; i < configs.count; i++) {
            var cfg = configs.get(i)
            if (!cfg || cfg.name !== linkName)
                continue
            var t = cfg.linkType
            return t === LinkConfiguration.TypeTcp ||
                   t === LinkConfiguration.TypeUdp ||
                   t === LinkConfiguration.TypeTngEncryptedTest
        }
        return false
    }

    function _hasConnectedNetworkLink() {
        var mvm = QGroundControl.multiVehicleManager
        var vehicles = mvm ? mvm.vehicles : null
        if (!vehicles)
            return false
        for (var v = 0; v < vehicles.count; v++) {
            var veh = vehicles.get(v)
            if (!veh || !veh.vehicleLinkManager)
                continue
            if (_linkNameIsNetworkType(veh.vehicleLinkManager.primaryLinkName))
                return true
        }
        return false
    }

    function showSummaryPanel() {
        if (mainWindow.allowViewSwitch()) {
            _showSummaryPanel()
        }
    }

    function _showSummaryPanel() {
        if (_fullParameterVehicleAvailable) {
            if (QGroundControl.multiVehicleManager.activeVehicle.autopilotPlugin.vehicleComponents.length === 0) {
                panelLoader.setSourceComponent(noComponentsVehicleSummaryComponent)
            } else {
                panelLoader.setSource("qrc:/qml/QGroundControl/VehicleSetup/VehicleSummary.qml")
            }
        } else if (QGroundControl.multiVehicleManager.parameterReadyVehicleAvailable) {
            panelLoader.setSourceComponent(missingParametersVehicleSummaryComponent)
        } else {
            panelLoader.setSourceComponent(disconnectedVehicleSummaryComponent)
        }
        summaryButton.checked = true
    }

    function showPanel(button, qmlSource) {
        if (mainWindow.allowViewSwitch()) {
            button.checked = true
            panelLoader.setSource(qmlSource)
        }
    }

    function showVehicleComponentPanel(vehicleComponent)
    {
        if (mainWindow.allowViewSwitch()) {
            var autopilotPlugin = QGroundControl.multiVehicleManager.activeVehicle.autopilotPlugin
            var prereq = autopilotPlugin.prerequisiteSetup(vehicleComponent)
            if (prereq !== "") {
                _messagePanelText = qsTr("%1 setup must be completed prior to %2 setup.").arg(prereq).arg(vehicleComponent.name)
                panelLoader.setSourceComponent(messagePanelComponent)
            } else {
                panelLoader.setSource(vehicleComponent.setupSource, vehicleComponent)
                for(var i = 0; i < componentRepeater.count; i++) {
                    var obj = componentRepeater.itemAt(i);
                    if (obj.text === vehicleComponent.name) {
                        obj.checked = true
                        break;
                    }
                }
            }
        }
    }

    function showParametersPanel() {
        if (mainWindow.allowViewSwitch()) {
            parametersButton.checked = true
            panelLoader.setSource("qrc:/qml/QGroundControl/VehicleSetup/SetupParameterEditor.qml")
        }
    }

    Component.onCompleted: _showSummaryPanel()

    Connections {
        target: QGroundControl.corePlugin
        onShowAdvancedUIChanged: {
            if(!QGroundControl.corePlugin.showAdvancedUI) {
                _showSummaryPanel()
            }
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        onParameterReadyVehicleAvailableChanged: {
            if (QGroundControl.multiVehicleManager.parameterReadyVehicleAvailable || summaryButton.checked || !firmwareButton.checked) {
                summaryButton.checked = true
                _showSummaryPanel()
            }
        }
        onVehicleAdded: function(vehicle) {
            if (_pendingParamRequest) {
                _pendingParamRequest = false
                vehicle.parameterManager.refreshAllParameters()
            }
        }
    }

    Component {
        id: noComponentsVehicleSummaryComponent
        Rectangle {
            color: qgcPal.windowShade
            QGCLabel {
                anchors.margins:        _defaultTextWidth * 2
                anchors.fill:           parent
                verticalAlignment:      Text.AlignVCenter
                horizontalAlignment:    Text.AlignHCenter
                wrapMode:               Text.WordWrap
                font.pointSize:         ScreenTools.mediumFontPointSize
                text:                   qsTr("%1 does not currently support setup of your vehicle type. ").arg(QGroundControl.appName) +
                                        "If your vehicle is already configured you can still Fly."
                onLinkActivated: (link) => Qt.openUrlExternally(link)
            }
        }
    }

    Component {
        id: disconnectedVehicleSummaryComponent
        Rectangle {
            color: qgcPal.windowShade
            QGCLabel {
                anchors.margins:        _defaultTextWidth * 2
                anchors.fill:           parent
                verticalAlignment:      Text.AlignVCenter
                horizontalAlignment:    Text.AlignHCenter
                wrapMode:               Text.WordWrap
                font.pointSize:         ScreenTools.largeFontPointSize
                text:                   qsTr("Vehicle settings and info will display after connecting your vehicle.") +
                                        (ScreenTools.isMobile || !_corePlugin.options.showFirmwareUpgrade ? "" : " Click Firmware on the left to upgrade your vehicle.")

                onLinkActivated: (link) => Qt.openUrlExternally(link)
            }
        }
    }

    Component {
        id: missingParametersVehicleSummaryComponent

        Rectangle {
            color: qgcPal.windowShade

            QGCLabel {
                anchors.margins:        _defaultTextWidth * 2
                anchors.fill:           parent
                verticalAlignment:      Text.AlignVCenter
                horizontalAlignment:    Text.AlignHCenter
                wrapMode:               Text.WordWrap
                font.pointSize:         ScreenTools.mediumFontPointSize
                text:                   qsTr("You are currently connected to a vehicle but it did not return the full parameter list. ") +
                                        qsTr("As a result, the full set of vehicle setup options are not available.")

                onLinkActivated: (link) => Qt.openUrlExternally(link)
            }
        }
    }

    Component {
        id: messagePanelComponent

        Item {
            QGCLabel {
                anchors.margins:        _defaultTextWidth * 2
                anchors.fill:           parent
                verticalAlignment:      Text.AlignVCenter
                horizontalAlignment:    Text.AlignHCenter
                wrapMode:               Text.WordWrap
                font.pointSize:         ScreenTools.mediumFontPointSize
                text:                   _messagePanelText
            }
        }
    }

    Item {
        id:             buttonArea
        anchors.left:   parent.left
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        width:          _sidebarTargetWidth


        QGCFlickable {
            id:                 buttonScroll
            width:              buttonColumn.width
            anchors.topMargin:  _defaultTextHeight / 2
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            anchors.leftMargin: _horizontalMargin
            anchors.left:       parent.left
            contentHeight:      buttonColumn.height
            flickableDirection: Flickable.VerticalFlick
            clip:               true

            Column {
                id:         buttonColumn
                width:      Math.max(_maxButtonWidth, setupView._buttonColumnWidth)
                spacing:    ScreenTools.defaultFontPixelHeight / 4

                property real _maxButtonWidth: 0

                Component.onCompleted: reflowWidths()
                onWidthChanged: reflowWidths()

                Connections {
                    target:         QGroundControl.settingsManager.appSettings.appFontPointSize
                    onValueChanged: buttonColumn.reflowWidths()
                }

                function reflowWidths() {
                    buttonColumn._maxButtonWidth = setupView._buttonColumnWidth
                    for (var i = 0; i < children.length; i++) {
                        buttonColumn._maxButtonWidth = Math.max(buttonColumn._maxButtonWidth, children[i].implicitWidth)
                    }
                    for (var j = 0; j < children.length; j++) {
                        children[j].width = buttonColumn._maxButtonWidth
                    }
                }

                // ── 연결된 기기 섹션: 기기 목록과 설정 메뉴를 통합 표시
                Column {
                    id:      deviceSection
                    width:   parent.width
                    spacing: 0
                    visible: mainWindow.droneDeviceListModel !== null && mainWindow.droneDeviceListModel.count > 0

                    // 섹션 헤더
                    Item {
                        width:  parent.width
                        height: _defaultTextHeight * 1.4

                        QGCLabel {
                            anchors.left:           parent.left
                            anchors.leftMargin:     _horizontalMargin
                            anchors.verticalCenter: parent.verticalCenter
                            text:           qsTr("연결된 기기")
                            font.pointSize: ScreenTools.smallFontPointSize
                            color:          qgcPal.colorGrey
                        }
                    }

                    Repeater {
                        id:    deviceSectionRepeater
                        model: mainWindow.droneDeviceListModel

                        delegate: Item {
                            visible: model.nodeType === "port" ||
                                     (model.nodeType === "device" && model.status === "ONLINE")
                            width:   deviceSection.width
                            height:  visible ? _defaultTextHeight * 2.5 : 0

                            readonly property bool _isPort:   model.nodeType === "port"
                            readonly property bool _isOnline: model.status === "ONLINE"
                            readonly property bool _hasPort:  model.portName !== ""
                            readonly property bool _rowIsActiveVehicle: setupView._rowMatchesActiveVehicle(
                                                                            model.nodeType,
                                                                            model.portName,
                                                                            model.deviceName)

                            Rectangle {
                                anchors.fill: parent
                                color:        _rowIsActiveVehicle ? qgcPal.buttonHighlight : "transparent"
                                radius:       2
                                opacity:      0.35
                            }

                            RowLayout {
                                anchors.fill:        parent
                                anchors.leftMargin:  _horizontalMargin
                                anchors.rightMargin: _horizontalMargin
                                spacing:             _defaultTextWidth

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text:             model.deviceName !== "" ? model.deviceName : model.portName
                                    elide:            Text.ElideRight
                                    color:            _rowIsActiveVehicle ? qgcPal.buttonHighlightText : qgcPal.text
                                }

                                QGCButton {
                                    // 시리얼 포트: 오프라인이거나 아직 로드 안 된 경우 표시 / device: 선택 안 됐을 때 표시
                                    visible:  _isPort ? (!_isOnline || !setupView._fullParameterVehicleAvailable || !_rowIsActiveVehicle)
                                                      : !_rowIsActiveVehicle
                                    text:     qsTr("로드")
                                    onClicked: {
                                        if (!_isPort) {
                                            // TCP/일반 기체: DroneList 선택 → Edit A가 active로 전환하여 데이터 로드
                                            mainWindow.selectFlyViewDevice(model.deviceName)
                                            return
                                        }
                                        // ── 시리얼 포트: 기존 로직 유지 ──
                                        var mdl = mainWindow.droneDeviceListModel
                                        if (mdl && _hasPortScanner) {
                                            for (var i = 0; i < mdl.count; i++) {
                                                var other = mdl.get(i)
                                                if (other.status === "ONLINE" &&
                                                        other.portName !== "" &&
                                                        other.portName !== model.portName) {
                                                    QGroundControl.portScanner.disconnectPort(other.portName)
                                                    break
                                                }
                                            }
                                        }
                                        if (!_isOnline && _hasPortScanner) {
                                            setupView._pendingParamRequest = true
                                            QGroundControl.portScanner.connectPort(model.portName)
                                        } else if (_hasPort) {
                                            var av = QGroundControl.multiVehicleManager.activeVehicle
                                            if (av) av.parameterManager.refreshAllParameters()
                                        }
                                    }
                                }

                                QGCButton {
                                    // 시리얼 포트: 실제 링크 해제 / device: 선택 해제(표시·데이터만 내림, 링크 유지)
                                    visible:  _isPort ? (_isOnline && _hasPort && _hasPortScanner)
                                                      : _rowIsActiveVehicle
                                    text:     qsTr("해제")
                                    onClicked: {
                                        if (_isPort)
                                            QGroundControl.portScanner.disconnectPort(model.portName)
                                        else
                                            mainWindow.selectFlyViewDevice("")
                                    }
                                }
                            }
                        }
                    }

                    // 구분선
                    Rectangle {
                        width:  parent.width
                        height: 1
                        color:  qgcPal.windowShade
                    }
                }

                SubMenuButton {
                    id:             summaryButton
                    imageResource:  "/qmlimages/VehicleSummaryIcon.png"
                    autoExclusive:  true
                    checked:        true
                    text:           qsTr("Summary")

                    onClicked: showSummaryPanel()
                }

                SubMenuButton {
                    autoExclusive:  true
                    visible:        QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle.flowImageIndex > 0 : false
                    text:           qsTr("Optical Flow")
                    onClicked:      showPanel(this, "qrc:/qml/QGroundControl/VehicleSetup/OpticalFlowSensor.qml")
                }

                SubMenuButton {
                    id:             joystickButton
                    imageResource:  "/qmlimages/Joystick.png"
                    autoExclusive:  true
                    setupComplete:  _activeJoystick ? _activeJoystick.calibrated || _buttonsOnly : false
                    visible:        _fullParameterVehicleAvailable && joystickManager.joysticks.length !== 0
                    text:           _forcedToButtonsOnly ? qsTr("Buttons") : qsTr("Joystick")
                    onClicked:      showPanel(this, "qrc:/qml/QGroundControl/VehicleSetup/JoystickConfig.qml")

                    property var    _activeJoystick:        joystickManager.activeJoystick
                    property bool   _buttonsOnly:           _activeJoystick ? _activeJoystick.axisCount == 0 : false
                    property bool   _forcedToButtonsOnly:   !QGroundControl.corePlugin.options.allowJoystickSelection && _buttonsOnly
                }

                Repeater {
                    id:     componentRepeater
                    model:  _fullParameterVehicleAvailable ? QGroundControl.multiVehicleManager.activeVehicle.autopilotPlugin.vehicleComponents : 0

                    onCountChanged: buttonColumn.reflowWidths()

                    SubMenuButton {
                        imageResource:  modelData.iconResource
                        autoExclusive:  true
                        setupComplete:  modelData.setupComplete
                        text:           modelData.name
                        visible:        modelData.setupSource.toString() !== ""
                        onClicked:      showVehicleComponentPanel(componentUrl)

                        property var componentUrl: modelData
                    }
                }

                SubMenuButton {
                    id:             parametersButton
                    autoExclusive:  true
                    visible:        QGroundControl.multiVehicleManager.parameterReadyVehicleAvailable &&
                                    !QGroundControl.multiVehicleManager.activeVehicle.usingHighLatencyLink &&
                                    _corePlugin.showAdvancedUI
                    text:           qsTr("Parameters")
                    imageResource:  "/qmlimages/subMenuButtonImage.png"
                    onClicked:      showPanel(this, "qrc:/qml/QGroundControl/VehicleSetup/SetupParameterEditor.qml")
                }

                SubMenuButton {
                    id:             firmwareButton
                    imageResource:  "/qmlimages/FirmwareUpgradeIcon.png"
                    autoExclusive:  true
                    visible:        !ScreenTools.isMobile && _corePlugin.options.showFirmwareUpgrade
                    text:           qsTr("Firmware")

                    onClicked: {
                        // [Custom] 펌웨어 진입은 disconnectAll()로 모든 링크를 끊는다.
                        // 살아있는 네트워크 링크(TCP/UDP)가 있으면 경고 후 사용자가 계속을 눌러야 진행.
                        if (setupView._hasConnectedNetworkLink()) {
                            mainWindow.showMessageDialog(
                                qsTr("펌웨어 업그레이드"),
                                qsTr("펌웨어 업그레이드를 시작하면 현재 모든 네트워크(TCP/UDP) 연결이 종료되며, 앱을 재시작하기 전까지 자동으로 재접속되지 않습니다.\n\n계속하시겠습니까?"),
                                Dialog.Ok | Dialog.Cancel,
                                function () { showPanel(firmwareButton, "qrc:/qml/QGroundControl/VehicleSetup/FirmwareUpgrade.qml") })
                            return
                        }
                        showPanel(this, "qrc:/qml/QGroundControl/VehicleSetup/FirmwareUpgrade.qml")
                    }
                }
            }
        }

        Rectangle {
            id:                     divider
            anchors.topMargin:      _verticalMargin
            anchors.bottomMargin:   _verticalMargin
            anchors.right:          parent.right
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            width:                  1
            color:                  qgcPal.windowShade
        }
    }

    Loader {
        id:                     panelLoader
        anchors.topMargin:      _verticalMargin
        anchors.bottomMargin:   _verticalMargin
        anchors.leftMargin:     _horizontalMargin
        anchors.rightMargin:    _horizontalMargin
        anchors.left:           buttonArea.right
        anchors.right:          parent.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom

        function setSource(source, vehicleComponent) {
            panelLoader.source = ""
            panelLoader.vehicleComponent = vehicleComponent
            panelLoader.source = source
        }

        function setSourceComponent(sourceComponent, vehicleComponent) {
            panelLoader.sourceComponent = undefined
            panelLoader.vehicleComponent = vehicleComponent
            panelLoader.sourceComponent = sourceComponent
        }

        property var vehicleComponent
    }
}
