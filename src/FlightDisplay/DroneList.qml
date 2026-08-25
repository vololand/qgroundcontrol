// import QtQuick 6.5
// import QtQuick.Controls 6.5
// import QtQuick.Layouts 1.15

// // (필요 없으면 지워도 되지만, 나중에 QGC 객체 쓸 수 있으니 남겨둬도 OK)
// import QGroundControl
// import QGroundControl.Controls
// import QGroundControl.ScreenTools

// Item {
//     id: root
//     //anchors.fill: parent
//      implicitWidth: droneList.implicitWidth
//      implicitHeight: droneList.implicitHeight

//     // ------------------------------------------------------------
//     // MainWindow.qml이 FlyView에 "반드시" 기대하는 인터페이스
//     // ------------------------------------------------------------
//     // globals.planMasterControllerFlyView: flyView.planController
//     // globals.guidedControllerFlyView:     flyView.guidedController
//     property var planController: null
//     property var guidedController: null

//     // MainWindow에서 넘겨줌: FlyView { utmspSendActTrigger: _utmspSendActTrigger }
//     property bool utmspSendActTrigger: false

//     // criticalVehicleMessagePopup에서 호출됨
//     function dropMainStatusIndicatorTool() {
//         // 커스텀 UI에서는 아무 동작 안 해도 됨
//     }

//     // ------------------------------------------------------------
//     // 네 UI가 쓰는 외부 주입 객체들
//     // ------------------------------------------------------------
//     // C++/상위에서 contextProperty로 "deviceListModel"을 올려둔 상태면 자동으로 잡힘
//     // (없으면 null이므로 ListView가 안 뜸)
//     property var deviceListModel: (typeof deviceListModel !== "undefined") ? deviceListModel : null

//     // C++/상위에서 "backend"를 올려둔 상태면 backend.status로 LED 표시
//     property var backend: (typeof backend !== "undefined") ? backend : null

//     Rectangle {
//         id: droneList
//         width: parent.width
//         height: parent.height

//         implicitWidth: 350
//         color: "#1a1a1a"
//         property string selectedDevice: ""
//         property var backend: root.backend

//         ColumnLayout {
//             anchors.fill: parent
//             anchors.centerIn: parent
//             anchors.topMargin: 10
//             anchors.bottomMargin: 10
//             spacing: 10
//             clip: true

//             // 선택 장비 예시
//             Rectangle {
//                 id: selectedBar_border
//                 Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
//                 Layout.preferredWidth: 280
//                 Layout.preferredHeight: 30
//                 color: "transparent"
//                 border.color: "white"
//                 border.width: 1
//                 radius: 4
//                 clip: true

//                 Rectangle {
//                     id: selectedBar
//                     anchors.left: parent.left
//                     anchors.right: parent.right
//                     height: 28
//                     color: "#111"
//                     border.color: "#333"
//                     z: 100

//                     Text {
//                         anchors.verticalCenter: parent.verticalCenter
//                         anchors.left: parent.left
//                         anchors.leftMargin: 12
//                         color: "white"
//                         font.pixelSize: 12
//                         text: droneList.selectedDevice === ""
//                               ? "선택된 장비: 없음"
//                               : ("선택된 장비: " + droneList.selectedDevice)
//                     }
//                 }
//             }

//             RowLayout {
//                 Layout.fillWidth: true
//                 Layout.leftMargin: 10
//                 Layout.rightMargin: 10
//                 spacing: 10

//                 Rectangle {
//                     id: serverConnectionStatus
//                     Layout.leftMargin: 10
//                     Layout.alignment: Qt.AlignTop
//                     Layout.preferredWidth: 20
//                     Layout.preferredHeight: 20
//                     color: {
//                         if (backend && backend.status === 0) return "#44ff44" // 초록
//                         if (backend && backend.status === 1) return "#ffb300" // 노랑
//                         return "#ff4444" // 빨강 (기본값)
//                     }

//                     radius: width /2
//                     clip: true
//                 }

//                 Item { Layout.fillWidth: true }

//                 TextField {
//                     id: deviceSearchBox
//                     placeholderText: "장치 검색..."
//                     placeholderTextColor: "#ffffff"
//                     horizontalAlignment: Text.AlignLeft
//                     verticalAlignment: Text.AlignVCenter
//                     Layout.preferredWidth: 180
//                     Layout.preferredHeight: 30
//                     leftPadding: 10
//                     color: "white"
//                     font.pixelSize: 12

//                     background: Rectangle {
//                         color: "#2a2a2a"
//                         border.color: deviceSearchBox.activeFocus ? "#00BFFF" : "#444"
//                         border.width: 1
//                         radius: 4
//                     }

//                     onTextChanged: {
//                         if (!root.deviceListModel) return
//                         root.deviceListModel.toggleSection(-1, text)
//                     }
//                 }
//             }

//             Rectangle {
//                 id: droneScroll
//                 Layout.preferredWidth: parent.width - 10
//                 Layout.fillHeight: true
//                 Layout.alignment: Qt.AlignHCenter
//                 color: "transparent"
//                 border.color: "white"
//                 border.width: 1
//                 radius: 4
//                 clip: true

//                 ScrollView {
//                     id: viewContainer
//                     anchors.fill: parent
//                     anchors.margins: 10
//                     clip: true

//                     ListView {
//                         id: listView
//                         width: viewContainer.availableWidth
//                         model: root.deviceListModel
//                         spacing: 2

//                         delegate: Item {
//                             id: delegateItem
//                             width: listView.width
//                             height: isVisible ? (nodeType === "device" ? 60 : 40) : 0
//                             visible: isVisible
//                             clip: true

//                             Behavior on height {
//                                 NumberAnimation { duration: 150 }
//                             }

//                             Rectangle {
//                                 id: bgRect
//                                 anchors.fill: parent
//                                 anchors.margins: 2
//                                 z: 0

//                                 color: nodeType === "company"
//                                        ? "#252525"
//                                        : (nodeType.includes("department") ? "#1e1e1e" : "#151515")

//                                 border.color: (nodeType === "device"
//                                                && droneList.selectedDevice === deviceName) ? "#00BFFF" : "#333"
//                                 border.width: (nodeType === "device"
//                                                && droneList.selectedDevice === deviceName) ? 3 : 1
//                                 radius: 4
//                             }

//                             RowLayout {
//                                 id: contentLayout
//                                 anchors.fill: bgRect
//                                 anchors.leftMargin: 10
//                                 anchors.rightMargin: 2
//                                 spacing: 10
//                                 z: 1

//                                 Text {
//                                     text: isExpanded ? "▼" : "▶"
//                                     Layout.alignment: Qt.AlignVCenter
//                                     Layout.preferredWidth: 15
//                                     color: "white"
//                                     font.pixelSize: 12
//                                     visible: nodeType !== "device"
//                                 }

//                                 Item {
//                                     width: 12
//                                     height: 12
//                                     visible: nodeType === "device"
//                                 }

//                                 Text {
//                                     id: iconText
//                                     font.pixelSize: 16
//                                     text: nodeType === "device"
//                                           ? (flighttype === "copter" ? "🚁" : flighttype === "plane" ? "✈️" : "🛸")
//                                           : (nodeType === "company" ? "🏢" : "📂")
//                                     Layout.preferredWidth: 25
//                                 }

//                                 Text {
//                                     text: {
//                                         if (nodeType === "device") return model.deviceName || "Unknown"
//                                         return model.groupName || ""
//                                     }
//                                     color: nodeType === "company"
//                                            ? "#00BFFF"
//                                            : (nodeType.includes("department") ? "#FFD700" : "white")
//                                     font.bold: nodeType !== "device"
//                                     font.pixelSize: 14
//                                     elide: Text.ElideRight
//                                     Layout.fillWidth: true
//                                     verticalAlignment: Text.AlignVCenter
//                                 }

//                                 RowLayout {
//                                     visible: nodeType === "device"
//                                     spacing: 15
//                                     Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

//                                     Text {
//                                         id: heartbeatIcon
//                                         text: status === "ONLINE" ? "📶" : "⚠️"
//                                         font.pixelSize: 14
//                                         Layout.preferredWidth: 20
//                                         Layout.alignment: Qt.AlignVCenter
//                                         color: status === "ONLINE" ? "#44ff44" : "#ff4444"
//                                     }

//                                     Text {
//                                         text: flightmode || "Mode"
//                                         color: "white"
//                                         font.pixelSize: 11
//                                         Layout.preferredWidth: 40
//                                         horizontalAlignment: Text.AlignHCenter
//                                     }

//                                     Text {
//                                         text: isArmed ? "ARM" : "DISR"
//                                         color: isArmed ? "#ff4444" : "#44ff44"
//                                         font.pixelSize: 11
//                                         font.bold: true
//                                         Layout.preferredWidth: 35
//                                     }

//                                     Text {
//                                         id: stateIndicator
//                                         width: 12
//                                         height: 12
//                                         text: "!"
//                                         font.bold: true
//                                         font.pixelSize: 14
//                                         horizontalAlignment: Text.AlignHCenter
//                                         verticalAlignment: Text.AlignVCenter
//                                         Layout.alignment: Qt.AlignVCenter
//                                         Layout.preferredWidth: 12
//                                         Layout.preferredHeight: 12

//                                         readonly property int currentState:
//                                             (typeof model.systemState !== "undefined") ? Number(model.systemState) : 0

//                                         color: (currentState === 3) ? "#44ff44" : "#ff4444"
//                                     }
//                                 }
//                             }

//                             MouseArea {
//                                 id: clickArea
//                                 anchors.fill: parent
//                                 z: 2

//                                 onClicked: {
//                                     if (nodeType === "device") {
//                                         droneList.selectedDevice =
//                                             (droneList.selectedDevice === deviceName) ? "" : deviceName
//                                     } else {
//                                         if (!root.deviceListModel) return
//                                         root.deviceListModel.toggleSection(index, deviceSearchBox.text)
//                                     }
//                                 }
//                             }
//                         }
//                     }
//                 }
//             }
//         }
//     }
// }

import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 1.15

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools

Item {
    id: root
    implicitWidth:  mainWindow.sidebarTargetWidth
    implicitHeight: droneList.implicitHeight

    property alias selectedDevice: droneList.selectedDevice

    // ------------------------------------------------------------
    // 로컬 모델 정의
    // planController / guidedController / utmsp: 본 파일에서 미사용이었음(제거).
    // MainWindow globals.planMasterControllerFlyView 등은 CustomFlyView.planController 경유.
    // ------------------------------------------------------------

    // ListView가 참조할 모델 (기존 root.deviceListModel 참조 유지)
    property var deviceListModel: localDeviceModel
    //property var backend: (typeof backend !== "undefined") ? backend : null
    property var backend: null
    property string currentSearchText: "" // 현재 검색어 저장
    property var    _localVehicleIds: []  // QGC 직접 연결 기체의 vehicle.id 목록
    property var    _portVehicleMap:  ({}) // portName → vehicleId (PortScanner 연결 시 채워짐)
    property var    _deviceNameToVehicleId: ({}) // deviceName → vehicleId (선택 → Vehicle 매핑)

    // 선택된 항목의 QGC Vehicle 객체 반환 (일반 기체 + PortScanner 기체 모두 지원)
    readonly property var selectedQgcVehicle: {
        var sel = droneList.selectedDevice
        if (sel === "") return null
        var vid = root._deviceNameToVehicleId[sel]
        if (vid !== undefined)
            return QGroundControl.multiVehicleManager.getVehicleById(vid)
        return null
    }

    ListModel {
        id: localDeviceModel
    }

    function initializeData() {
        var rawListData = [
            { "depth": 0, "nodeType": "company", "groupName": "VoloLand", "deviceName": "" },
            { "depth": 1, "nodeType": "parent department", "groupName": "미래항공모빌리티연구소", "deviceName": "" },
            { "depth": 2, "nodeType": "department", "groupName": "볼로 무인기 & 지상플랫폼 그룹", "deviceName": "" },
            { "depth": 3, "nodeType": "device", "groupName": "", "deviceName": "A-1" },
            { "depth": 2, "nodeType": "department", "groupName": "볼로 자율비행플랫폼 그룹", "deviceName": "" },
            { "depth": 3, "nodeType": "device", "groupName": "", "deviceName": "B-1" },
            { "depth": 0, "nodeType": "company", "groupName": "개인사용자", "deviceName": "" },
            { "depth": 1, "nodeType": "device", "groupName": "", "deviceName": "C-1" },
            { "depth": 0, "nodeType": "company", "groupName": "로컬기기", "deviceName": "" }
        ];

        localDeviceModel.clear();
        for (var i = 0; i < rawListData.length; i++) {
            var item = rawListData[i];
            item.status = "OFFLINE";
            item.isArmed = false;
            item.systemState = 0;
            item.flightmode = "N/A";
            item.flighttype = "copter";
            item.isVisible = true;
            item.isExpanded = true;
            item.portName = "";    // PortScanner 항목 전용 필드 (일반 항목은 빈 문자열)
            item.boardName = "";
            localDeviceModel.append(item);
        }
    }

    // ── QGC 직접 연결 기체 헬퍼 ─────────────────────────────────────────────────
    function _qgcFlightType(vehicle) {
        if (vehicle.fixedWing || vehicle.vtol) return "plane"
        return "copter"
    }

    /// QGC VehicleLinkManager 기준 실질 링크 여부
    /// linkNames 는 신호 처리 순서에 따라 일시적으로 비어있을 수 있으므로
    /// communicationLost 만을 기준으로 판단한다.
    function _qgcVehicleOnline(vehicle) {
        if (!vehicle || !vehicle.vehicleLinkManager)
            return false
        return !vehicle.vehicleLinkManager.communicationLost
    }

    // ── PortScanner 헬퍼 ─────────────────────────────────────────────────────
    /// 로컬기기 그룹 내 다음 삽입 위치 반환
    function _findLocalGroupInsertIdx() {
        var insertIdx = localDeviceModel.count
        for (var j = 0; j < localDeviceModel.count; j++) {
            if (localDeviceModel.get(j).groupName === "로컬기기" && localDeviceModel.get(j).nodeType === "company") {
                insertIdx = j + 1
                for (var k = j + 1; k < localDeviceModel.count; k++) {
                    if (localDeviceModel.get(k).depth <= 0) { insertIdx = k; break }
                    insertIdx = k + 1
                }
                break
            }
        }
        return insertIdx
    }

    /// vehicle의 primaryLinkName 에서 PortScanner가 생성한 portName을 추출한다.
    /// "Pixhawk-<portName>" 형식일 때만 유효한 값 반환, 아니면 ""
    function _getPortNameForVehicle(vehicle) {
        if (!vehicle || !vehicle.vehicleLinkManager) return ""
        var lname = vehicle.vehicleLinkManager.primaryLinkName
        var prefix = "Pixhawk-"
        if (typeof lname === "string" && lname.indexOf(prefix) === 0)
            return lname.substring(prefix.length)
        return ""
    }

    /// PortScanner로 연결된 vehicle 이 올라왔을 때 기존 port 항목을 vehicle 데이터로 업그레이드
    function _upgradePortEntry(portName, vehicle) {
        for (var i = 0; i < localDeviceModel.count; i++) {
            var entry = localDeviceModel.get(i)
            if (entry.nodeType === "port" && entry.portName === portName) {
                localDeviceModel.setProperty(i, "status",      "ONLINE")
                localDeviceModel.setProperty(i, "isArmed",     vehicle.armed)
                localDeviceModel.setProperty(i, "systemState", vehicle.allSensorsHealthy ? 3 : 1)
                localDeviceModel.setProperty(i, "flightmode",  vehicle.flightMode || "N/A")
                localDeviceModel.setProperty(i, "flighttype",  root._qgcFlightType(vehicle))
                // deviceName → vehicleId 매핑 등록
                var map = Object.assign({}, root._deviceNameToVehicleId)
                map[entry.deviceName] = vehicle.id
                root._deviceNameToVehicleId = map
                break
            }
        }
        // _portVehicleMap 갱신
        var pm = Object.assign({}, root._portVehicleMap)
        pm[portName] = vehicle.id
        root._portVehicleMap = pm
        // _localVehicleIds 에 추가
        if (root._localVehicleIds.indexOf(vehicle.id) < 0) {
            var ids = root._localVehicleIds.slice()
            ids.push(vehicle.id)
            root._localVehicleIds = ids
        }
    }

    /// PortScanner port 항목을 OFFLINE 상태로 되돌린다 (vehicle이 사라진 후)
    function _downgradePortEntry(portName, vehicleId) {
        for (var i = 0; i < localDeviceModel.count; i++) {
            var entry = localDeviceModel.get(i)
            if (entry.nodeType === "port" && entry.portName === portName) {
                localDeviceModel.setProperty(i, "status",      "OFFLINE")
                localDeviceModel.setProperty(i, "isArmed",     false)
                localDeviceModel.setProperty(i, "systemState", 0)
                localDeviceModel.setProperty(i, "flightmode",  "N/A")
                if (droneList.selectedDevice === entry.deviceName)
                    droneList.selectedDevice = ""
                break
            }
        }
        // 매핑 정리
        var pm = Object.assign({}, root._portVehicleMap)
        delete pm[portName]
        root._portVehicleMap = pm
        var map = Object.assign({}, root._deviceNameToVehicleId)
        for (var k in map) { if (map[k] === vehicleId) { delete map[k]; break } }
        root._deviceNameToVehicleId = map
        root._localVehicleIds = root._localVehicleIds.filter(function(vid) { return vid !== vehicleId })
    }

    /// PortScanner 포트 목록 변경 시 localDeviceModel 의 로컬기기 그룹을 동기화
    function _syncPortScannerPorts() {
        if (typeof QGroundControl.portScanner === "undefined" || QGroundControl.portScanner === null) return
        var ports = QGroundControl.portScanner.availablePorts  // Array of {portName, displayName, boardName, connected}

        // 사용 가능한 포트명 집합 구성
        var availableSet = {}
        for (var i = 0; i < ports.length; i++)
            availableSet[ports[i].portName] = ports[i]

        // 없어진 포트는 제거 (OFFLINE 상태인 것만 - ONLINE은 vehicleRemoved가 처리)
        for (var j = localDeviceModel.count - 1; j >= 0; j--) {
            var item = localDeviceModel.get(j)
            if (item.nodeType !== "port") continue
            if (availableSet[item.portName]) continue
            if (item.status === "ONLINE") continue  // 연결 중이면 vehicle 정리 후 제거
            if (droneList.selectedDevice === item.deviceName)
                droneList.selectedDevice = ""
            localDeviceModel.remove(j)
        }

        // 새 포트 추가
        for (var portName in availableSet) {
            var info = availableSet[portName]
            var found = false
            for (var k = 0; k < localDeviceModel.count; k++) {
                if (localDeviceModel.get(k).portName === portName) { found = true; break }
            }
            if (!found) {
                localDeviceModel.insert(_findLocalGroupInsertIdx(), {
                    "depth": 1, "nodeType": "port", "groupName": "",
                    "deviceName": info.displayName,
                    "portName":   portName,
                    "boardName":  info.boardName,
                    "status":     "OFFLINE",
                    "isArmed": false, "systemState": 0,
                    "flightmode": "N/A", "flighttype": "copter",
                    "isVisible": true, "isExpanded": true
                })
            }
        }
    }
    // ────────────────────────────────────────────────────────────────────────────

    function addLocalVehicle(vehicle) {
        if (root._localVehicleIds.indexOf(vehicle.id) >= 0) return

        // 1차: primaryLinkName "Pixhawk-<portName>" 형식으로 포트 식별
        var portName = root._getPortNameForVehicle(vehicle)

        // 2차 fallback: primaryLinkName 이 비어있을 경우 PortScanner 의 연결 상태로 포트 식별
        // (PortScanner 가 isConnected() 라고 보고하지만 아직 vehicleId 가 매핑되지 않은 port 항목)
        if (portName === "" &&
                typeof QGroundControl.portScanner !== "undefined" &&
                QGroundControl.portScanner !== null) {
            for (var fi = 0; fi < localDeviceModel.count; fi++) {
                var fe = localDeviceModel.get(fi)
                if (fe.nodeType === "port" && fe.portName !== "" &&
                        QGroundControl.portScanner.isConnected(fe.portName) &&
                        root._portVehicleMap[fe.portName] === undefined) {
                    portName = fe.portName
                    break
                }
            }
        }

        if (portName !== "") {
            root._upgradePortEntry(portName, vehicle)
            return
        }

        // 일반 기체: 로컬기기 그룹에 새 항목 삽입
        var devName = "Vehicle " + vehicle.id
        localDeviceModel.insert(root._findLocalGroupInsertIdx(), {
            "depth": 1, "nodeType": "device", "groupName": "",
            "deviceName": devName,
            "portName": "",
            "status": root._qgcVehicleOnline(vehicle) ? "ONLINE" : "OFFLINE",
            "isArmed": vehicle.armed,
            "systemState": vehicle.allSensorsHealthy ? 3 : 1,
            "flightmode": vehicle.flightMode || "N/A",
            "flighttype": root._qgcFlightType(vehicle),
            "isVisible": true, "isExpanded": true
        })
        var ids = root._localVehicleIds.slice()
        ids.push(vehicle.id)
        root._localVehicleIds = ids
        // deviceName → vehicleId 매핑
        var map = Object.assign({}, root._deviceNameToVehicleId)
        map[devName] = vehicle.id
        root._deviceNameToVehicleId = map
    }

    function removeLocalVehicle(vehicle) {
        // USB 분리 시점에는 _primaryLink 가 이미 reset() 되어 primaryLinkName 이 ""를 반환한다.
        // 따라서 _getPortNameForVehicle 대신 _portVehicleMap 역조회로 portName 을 구한다.
        var portName = ""
        var pm = root._portVehicleMap
        for (var pn in pm) {
            if (pm[pn] === vehicle.id) { portName = pn; break }
        }
        if (portName !== "") {
            root._downgradePortEntry(portName, vehicle.id)
            // 물리적으로 포트가 사라졌으면 즉시 목록 동기화하여 항목 제거
            if (typeof QGroundControl.portScanner !== "undefined" && QGroundControl.portScanner !== null)
                root._syncPortScannerPorts()
            return
        }

        // 일반 기체 제거
        var name = "Vehicle " + vehicle.id
        for (var i = 0; i < localDeviceModel.count; i++) {
            if (localDeviceModel.get(i).deviceName === name) {
                if (droneList.selectedDevice === name) droneList.selectedDevice = ""
                localDeviceModel.remove(i)
                break
            }
        }
        var map = Object.assign({}, root._deviceNameToVehicleId)
        delete map[name]
        root._deviceNameToVehicleId = map
        root._localVehicleIds = root._localVehicleIds.filter(function(vid) { return vid !== vehicle.id })
    }

    function updateLocalVehicle(vehicle) {
        // 1차: primaryLinkName 으로 포트 식별
        var portName = root._getPortNameForVehicle(vehicle)

        // 2차 fallback: _portVehicleMap 역조회 (vehicleId → portName)
        if (portName === "") {
            var upm = root._portVehicleMap
            for (var upn in upm) {
                if (upm[upn] === vehicle.id) { portName = upn; break }
            }
        }

        // PortScanner를 통해 연결된 기체: port 항목을 직접 갱신
        if (portName !== "") {
            for (var i = 0; i < localDeviceModel.count; i++) {
                var e = localDeviceModel.get(i)
                if (e.nodeType === "port" && e.portName === portName) {
                    localDeviceModel.setProperty(i, "status",      root._qgcVehicleOnline(vehicle) ? "ONLINE" : "OFFLINE")
                    localDeviceModel.setProperty(i, "isArmed",     vehicle.armed)
                    localDeviceModel.setProperty(i, "systemState", vehicle.allSensorsHealthy ? 3 : 1)
                    localDeviceModel.setProperty(i, "flightmode",  vehicle.flightMode || "N/A")
                    localDeviceModel.setProperty(i, "flighttype",  root._qgcFlightType(vehicle))
                    break
                }
            }
            return
        }

        // 일반 기체
        updateHeartbeat({
            "deviceName": "Vehicle " + vehicle.id,
            "status": root._qgcVehicleOnline(vehicle) ? "ONLINE" : "OFFLINE",
            "isArmed": vehicle.armed,
            "systemState": vehicle.allSensorsHealthy ? 3 : 1,
            "flightmode": vehicle.flightMode || "N/A",
            "flighttype": root._qgcFlightType(vehicle)
        })
    }
    // ────────────────────────────────────────────────────────────────────────────

    function updateHeartbeat(hb) {
        for (var i = 0; i < localDeviceModel.count; i++) {
            if (localDeviceModel.get(i).deviceName === hb.deviceName) {
                localDeviceModel.setProperty(i, "status", hb.status);
                localDeviceModel.setProperty(i, "isArmed", hb.isArmed);
                localDeviceModel.setProperty(i, "systemState", hb.systemState);
                localDeviceModel.setProperty(i, "flightmode", hb.flightmode);
                localDeviceModel.setProperty(i, "flighttype", hb.flighttype);
                break;
            }
        }
    }

    function filterDevices(searchText) {
        root.currentSearchText = searchText // 현재 검색어 저장
        var searchLower = searchText.toLowerCase().trim()
        
        if (searchLower === "") {
            // 검색어가 비어있으면 접기/펼치기 상태만 확인
            for (var i = 0; i < localDeviceModel.count; i++) {
                var shouldBeVisible = root.shouldItemBeVisible(i)
                localDeviceModel.setProperty(i, "isVisible", shouldBeVisible)
            }
            return
        }
        
        // 1단계: 각 항목이 직접 매칭되는지 확인하고, 자식이 매칭되면 부모도 표시
        var itemMatches = []
        for (var i = localDeviceModel.count - 1; i >= 0; i--) {
            var item = localDeviceModel.get(i)
            var deviceName = (item.deviceName || "").toLowerCase()
            var groupName = (item.groupName || "").toLowerCase()
            var directMatch = deviceName.indexOf(searchLower) !== -1 || groupName.indexOf(searchLower) !== -1
            
            // 자식 중 하나라도 매칭되면 부모도 표시
            var childMatches = false
            if (!directMatch && item.depth < 3) {
                for (var j = i + 1; j < localDeviceModel.count; j++) {
                    var childItem = localDeviceModel.get(j)
                    if (childItem.depth <= item.depth) break
                    if (itemMatches[j]) {
                        childMatches = true
                        break
                    }
                }
            }
            
            itemMatches[i] = directMatch || childMatches
        }
        
        // 2단계: 매칭 결과와 접기/펼치기 상태를 함께 확인
        for (var i = 0; i < localDeviceModel.count; i++) {
            if (!itemMatches[i]) {
                localDeviceModel.setProperty(i, "isVisible", false)
                continue
            }
            var shouldBeVisible = root.shouldItemBeVisible(i)
            localDeviceModel.setProperty(i, "isVisible", shouldBeVisible)
        }
    }
    
    function shouldItemBeVisible(itemIndex) {
        var item = localDeviceModel.get(itemIndex)
        var searchLower = root.currentSearchText.toLowerCase().trim()
        
        // 검색 필터링은 이미 filterDevices에서 처리되었으므로, 여기서는 접기/펼치기 상태만 확인
        // 모든 부모 항목의 접기/펼치기 상태를 재귀적으로 확인
        if (item.depth > 0) {
            for (var j = itemIndex - 1; j >= 0; j--) {
                var parentItem = localDeviceModel.get(j)
                if (parentItem.depth < item.depth) {
                    // 직접 부모가 접혀있으면 숨김
                    if (!parentItem.isExpanded) return false
                    // 직접 부모의 부모도 확인 (재귀적으로)
                    return root.shouldItemBeVisible(j)
                }
            }
        }
        
        return true
    }

    Component.onCompleted: {
        initializeData();
        updateHeartbeat({"deviceName": "A-1", "status": "ONLINE", "isArmed": true, "systemState": 3, "flightmode": "Loiter", "flighttype": "copter"});
        // 이미 연결된 QGC 기체 초기 등록
        var vms = QGroundControl.multiVehicleManager.vehicles
        for (var i = 0; i < vms.count; i++)
            root.addLocalVehicle(vms.get(i))
        // PortScanner 초기 포트 동기화 (시리얼 링크 지원 환경에서만)
        if (typeof QGroundControl.portScanner !== "undefined" && QGroundControl.portScanner !== null)
            root._syncPortScannerPorts()
    }

    // QGC 기체 연결/해제 감지 → 로컬기기 그룹 항목 추가/제거
    Connections {
        target: QGroundControl.multiVehicleManager
        function onVehicleAdded(vehicle)   { root.addLocalVehicle(vehicle) }
        function onVehicleRemoved(vehicle) { root.removeLocalVehicle(vehicle) }
    }

    // PortScanner 포트 목록 변경 감지 → 로컬기기 그룹 동기화
    // QGC_NO_SERIAL_LINK 환경에서는 portScanner 가 undefined 이므로 null guard 적용
    Connections {
        target: (typeof QGroundControl.portScanner !== "undefined") ? QGroundControl.portScanner : null
        function onAvailablePortsChanged() { root._syncPortScannerPorts() }
    }

    // QGC 기체 실시간 속성 감시 → localDeviceModel 갱신
    Repeater {
        model: QGroundControl.multiVehicleManager.vehicles
        delegate: Item {
            width: 0; height: 0
            Connections {
                target: object
                function onFlightModeChanged()        { root.updateLocalVehicle(object) }
                function onArmedChanged()             { root.updateLocalVehicle(object) }
                function onAllSensorsHealthyChanged() { root.updateLocalVehicle(object) }
                function onVehicleTypeChanged()       { root.updateLocalVehicle(object) }
            }
            Connections {
                target: object && object.vehicleLinkManager ? object.vehicleLinkManager : null
                // 통신 두절(OFF) 시 수동 Disconnect와 동일하게 기체 제거 → 파라미터 등 UI 초기화
                function onCommunicationLostChanged() {
                    if (!object || !object.vehicleLinkManager)
                        return
                    if (object.vehicleLinkManager.communicationLost)
                        object.closeVehicle()
                    else
                        root.updateLocalVehicle(object)
                }
                function onLinkNamesChanged() { root.updateLocalVehicle(object) }
            }
        }
    }

    function dropMainStatusIndicatorTool() { }

    Rectangle {
        id: droneList
        //implicitHeight:500
        width: parent.width
        height: parent.height

        color: "#1a1a1a"
        property string selectedDevice: ""
        property var backend: root.backend

        ColumnLayout {
            anchors.fill: parent
            anchors.centerIn: parent
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            spacing: 10
            clip: true
/*
            Rectangle {
                id: selectedBar_border
                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                Layout.preferredWidth: 280
                Layout.preferredHeight: 30
                color: "transparent"
                //border.color: "white"
                //border.width: 1
                radius: 4
                clip: true

                Rectangle {
                    id: selectedBar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 28
                    color: "#111"
                    border.color: "#333"
                    z: 100

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        color: "white"
                        font.pixelSize: 12
                        text: droneList.selectedDevice === ""
                              ? "선택된 장비: 없음"
                              : ("선택된 장비: " + droneList.selectedDevice)
                    }
                }

            }
*/
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                spacing: 10

                // 서버 연결 상태는 상단바(CustomToolbar)로 이동. mainWindow.serverConnectionStatus와 동기화
                Binding {
                    target: mainWindow
                    property: "serverConnectionStatus"
                    value: {
                        if (backend && backend.status === 0) return 0
                        if (backend && backend.status === 1) return 1
                        return 2
                    }
                }

                Item { Layout.fillWidth: true }

                TextField {
                    id: deviceSearchBox
                    placeholderText: "장치 검색..."
                    placeholderTextColor: "#ffffff"
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 30
                    leftPadding: 10
                    color: "white"
                    font.pointSize: ScreenTools.smallFontPointSize

                    background: Rectangle {
                        color: "#2a2a2a"
                        border.color: deviceSearchBox.activeFocus ? "#00BFFF" : "#444"
                        border.width: 1
                        radius: 4
                    }

                    onTextChanged: {
                        root.filterDevices(text)
                    }
                }
            }

            Rectangle {
                id: droneScroll
                Layout.preferredWidth: parent.width - 10
                Layout.fillWidth: true // 1.27
                Layout.fillHeight: true

                Layout.preferredHeight: droneStatus.width * 0.86 //1.27
                Layout.minimumHeight: 200 // 1.27
                Layout.alignment: Qt.AlignHCenter
                color: "transparent"
                //border.color: "white"
                //border.width: 1
                radius: 4
                clip: true

                ScrollView {
                    id: viewContainer
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true

                    ListView {
                        id: listView
                        width: viewContainer.availableWidth
                        model: root.deviceListModel // 위에서 정의한 localDeviceModel 연결됨
                        // 높이 0인 숨김 행 사이에서 spacing 이 누적되어 최상위 그룹 간 간격이 달라지는 것을 방지:
                        // 행간은 델리게이트 높이에만 포함한다.
                        spacing: 0

                        delegate: Item {
                            id: delegateItem
                            width: listView.width
                            // 본문 높이(40/60) + 다음 보이는 행까지의 간격(기존 ListView spacing 2 와 동일)
                            readonly property int _rowBodyHeight: (nodeType === "device" || nodeType === "port") ? 60 : 40
                            readonly property int _listRowSpacing: 2
                            // 수정 전: depth 들여쓰기 없음 — 아래 _depthIndentStep / _depthIndent 두 줄 없이 바로 height 로 이어짐
                            // depth 들여쓰기: 배수↑일수록 단계 간 좌측 간격 차이 커짐 (기본 2→1로 완화)
                            readonly property int _depthIndentStep: Math.round(ScreenTools.defaultFontPixelWidth * 1)
                            readonly property int _depthIndent: Math.max(0, Number(model.depth)) * _depthIndentStep
                            readonly property int _rowDepth: Math.max(0, Number(model.depth))
                            height: isVisible ? (_rowBodyHeight + _listRowSpacing) : 0
                            visible: isVisible
                            clip: true

                            Behavior on height {
                                NumberAnimation { duration: 150 }
                            }

                            Rectangle {
                                id: bgRect
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                // --- 수정 전 ---
                                // anchors.leftMargin: 2
                                // 3.30 dronelist depth 별 간격
                                anchors.leftMargin: 2 + delegateItem._depthIndent
                                anchors.rightMargin: 2
                                anchors.topMargin: 2
                                height: _rowBodyHeight - 4
                                z: 0
                                color: {
                                    if (nodeType === "device" || nodeType === "port")
                                        return "#151515"
                                    var d = delegateItem._rowDepth
                                    if (d === 0)
                                        return "#252525"
                                    if (d === 1)
                                        return "#2f2f3c"
                                    if (d === 2)
                                        return "#1e2822"
                                    return "#1a1f24"
                                }
                                border.color: ((nodeType === "device" || nodeType === "port")
                                               && droneList.selectedDevice === deviceName) ? "#00BFFF" : "#333"
                                border.width: ((nodeType === "device" || nodeType === "port")
                                               && droneList.selectedDevice === deviceName) ? 3 : 1
                                radius: 4
                            }

                            RowLayout {
                                id: contentLayout
                                anchors.fill: bgRect
                                anchors.leftMargin: 10
                                // 스크롤 유무와 무관하게 항상 세로 스크롤바 폭만큼 우측 여백 확보 → 간격 일정 + 위험도(!) 안 겹침.
                                anchors.rightMargin: 2 + ((viewContainer.ScrollBar.vertical && viewContainer.ScrollBar.vertical.width > 0)
                                                          ? viewContainer.ScrollBar.vertical.width : 12)
                                spacing: 10
                                z: 1

                                Text {
                                    text: isExpanded ? "▼" : "▶"
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredWidth: 15
                                    color: "white"
                                    font.pointSize: ScreenTools.smallFontPointSize
                                    // device/port 는 자식이 없는 리프 노드 → 화살표 숨김
                                    visible: nodeType !== "device" && nodeType !== "port"
                                }

                                Item {
                                    width: 12
                                    height: 12
                                    // device/port 모두 들여쓰기 스페이서 표시
                                    visible: nodeType === "device" || nodeType === "port"
                                }

                                Text {
                                    id: iconText
                                    font.pointSize: ScreenTools.mediumFontPointSize
                                    // device/port: 기체 타입 / 그룹: depth1·2는 폴더 계열만 쓰면 비슷해 보여서 1=🏬 2=📂 로 구분
                                    text: {
                                        if (nodeType === "device" || nodeType === "port")
                                            return flighttype === "copter" ? "🚁"
                                                 : flighttype === "plane" ? "✈️" : "🛸"
                                        var d = delegateItem._rowDepth
                                        if (d === 0)
                                            return "🏢"
                                        if (d === 1)
                                            return "🏬"
                                        if (d === 2)
                                            return "📂"
                                        return "📋"
                                    }
                                    Layout.preferredWidth: 25
                                }

                                Text {
                                    text: {
                                        if (nodeType === "device" || nodeType === "port")
                                            return model.deviceName || "Unknown"
                                        return model.groupName || ""
                                    }
                                    color: {
                                        if (nodeType === "device" || nodeType === "port")
                                            return "white"
                                        var d = delegateItem._rowDepth
                                        if (d === 0)
                                            return "#00BFFF"
                                        if (d === 1)
                                            return "#9CDCFE"
                                        if (d === 2)
                                            return "#FFD700"
                                        return "#E0C080"
                                    }
                                    // device/port 는 bold 없음 (그룹 헤더만 bold)
                                    font.bold: nodeType !== "device" && nodeType !== "port"
                                    font.pointSize: ScreenTools.defaultFontPointSize
                                    elide: Text.ElideRight
                                    // 이름이 남는 폭을 모두 흡수 → 뒤의 상태 클러스터(hug)를 우측 끝으로 밀어냄(상태값 우측정렬)
                                    Layout.fillWidth: true
                                    verticalAlignment: Text.AlignVCenter
                                }

                                RowLayout {
                                    visible: nodeType === "device" || nodeType === "port"
                                    spacing: 15
                                    // 주의: RowLayout(Layout 타입)은 Layout.fillWidth 기본값이 true → 반드시 false로 명시해야 hug 됨.
                                    // hug → 앞의 이름(fillWidth)이 남는 폭을 먹고 이 클러스터를 우측 끝으로 밀어냄(상태값 우측정렬 + 밀착)
                                    Layout.fillWidth: false
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                                    Text {
                                        id: connectionOnOffLabel
                                        // 로컬 포트는 미연결(OFFLINE) 시 "---" 중립 표시
                                        // 서버 기기(device)는 장비 전원 ON/OFF 그대로 유지
                                        text: (nodeType === "port" && status !== "ONLINE")
                                              ? "---"
                                              : (status === "ONLINE" ? "ON" : "OFF")
                                        font.pointSize: ScreenTools.smallFontPointSize
                                        font.bold: true
                                        Layout.preferredWidth: 32
                                        Layout.alignment: Qt.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        color: (nodeType === "port" && status !== "ONLINE")
                                               ? "#888888"
                                               : (status === "ONLINE" ? "#44ff44" : "#ff4444")
                                    }

                                    Text {
                                        text: flightmode || "Mode"
                                        color: "white"
                                        font.pointSize: ScreenTools.smallFontPointSize
                                        // 반응형: 폭이 넓어지면 전체 표시, 좁으면 최소 40px 유지 후 …로 축약
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 40
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Text {
                                        text: isArmed ? "ARM" : "DISR"
                                        color: isArmed ? "#ff4444" : "#44ff44"
                                        font.pointSize: ScreenTools.smallFontPointSize
                                        font.bold: true
                                        Layout.preferredWidth: 35
                                    }

                                    Text {
                                        id: stateIndicator
                                        text: "!"
                                        font.bold: true
                                        font.pointSize: ScreenTools.defaultFontPointSize
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredWidth: 12
                                        Layout.preferredHeight: 12
                                        readonly property int currentState:
                                            (typeof model.systemState !== "undefined") ? Number(model.systemState) : 0
                                        color: (currentState === 3) ? "#44ff44" : "#ff4444"
                                    }
                                }
                            }

                            MouseArea {
                                id: clickArea
                                anchors.fill: parent
                                z: 2
                                onClicked: {
                                    if (nodeType === "device") {
                                        droneList.selectedDevice = (droneList.selectedDevice === deviceName) ? "" : deviceName
                                    } else if (nodeType === "port") {
                                        // PortScanner 포트: 선택 → 연결 / 재선택 → 연결 해제
                                        var wasSelected = (droneList.selectedDevice === deviceName)
                                        if (wasSelected) {
                                            droneList.selectedDevice = ""
                                            QGroundControl.portScanner.disconnectPort(portName)
                                        } else {
                                            droneList.selectedDevice = deviceName
                                            if (!QGroundControl.portScanner.isConnected(portName))
                                                QGroundControl.portScanner.connectPort(portName)
                                        }
                                    } else {
                                        var newExpanded = !isExpanded
                                        localDeviceModel.setProperty(index, "isExpanded", newExpanded)

                                        // 하위 항목들의 가시성을 결정하는 함수 (필터링 상태 고려, isExpanded 상태는 유지)
                                        function updateChildVisibility(parentIndex, visible) {
                                            var parentDepth = localDeviceModel.get(parentIndex).depth
                                            for (var i = parentIndex + 1; i < localDeviceModel.count; i++) {
                                                var item = localDeviceModel.get(i)

                                                if (item.depth > parentDepth) {
                                                    // 필터링 상태와 접기/펼치기 상태를 모두 확인
                                                    // 부모가 접혀있으면 자식도 숨김 (하지만 isExpanded 상태는 유지)
                                                    var shouldBeVisible = visible && root.shouldItemBeVisible(i)
                                                    localDeviceModel.setProperty(i, "isVisible", shouldBeVisible)
                                                    
                                                    // 부모가 펼쳐져 있고, 자식이 펼쳐져 있으면 그 자식들도 처리
                                                    if (visible && item.isExpanded) {
                                                        // 재귀적으로 자식의 자식들도 업데이트
                                                        var childDepth = item.depth
                                                        for (var j = i + 1; j < localDeviceModel.count; j++) {
                                                            var childItem = localDeviceModel.get(j)
                                                            if (childItem.depth > childDepth) {
                                                                var childShouldBeVisible = root.shouldItemBeVisible(j)
                                                                localDeviceModel.setProperty(j, "isVisible", childShouldBeVisible)
                                                            } else {
                                                                break
                                                            }
                                                        }
                                                    }
                                                } else {
                                                    break
                                                }
                                            }
                                        }
                                        updateChildVisibility(index, newExpanded)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
