import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 1.15
import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools

Item {
    id: root

    implicitWidth:  mainWindow.sidebarTargetWidth
    implicitHeight: stationBackground.implicitHeight

    property alias selectedStation: stationBackground.selectedStation

    // 데이터 로직 (DroneList의 구조와 동일하게 배치)
    property var backend: null
    property string currentSearchText: "" // 현재 검색어 저장

    ListModel {
        id: stationModel
    }

    function initializeData() {
        var rawListData = [
            { "depth": 0, "nodeType": "company",           "groupName": "VoloLand",                      "stationName": "" },
            { "depth": 1, "nodeType": "parent department", "groupName": "미래항공모빌리티연구소",      "stationName": "" },
            { "depth": 2, "nodeType": "department",        "groupName": "볼로 무인기 & 지상플랫폼 그룹", "stationName": "" },
            { "depth": 3, "nodeType": "station",           "groupName": "",                              "stationName": "VLS-770C" },
            { "depth": 2, "nodeType": "department",        "groupName": "볼로 자율비행플랫폼 그룹",    "stationName": "" },
            { "depth": 3, "nodeType": "station",           "groupName": "",                              "stationName": "VLS-400C" },
            { "depth": 0, "nodeType": "company",           "groupName": "개인사용자",                 "stationName": "" },
            { "depth": 3, "nodeType": "station",           "groupName": "",                              "stationName": "THEO-3" }
        ];

        stationModel.clear();
        for (var i = 0; i < rawListData.length; i++) {
            var item = rawListData[i];
            item.status = "OFFLINE";
            item.isVisible = true;
            item.isExpanded = true;
            item.battery = 100;
            item.isLocked = false;
            stationModel.append(item);
        }
    }

    Component.onCompleted: {
        initializeData();
        updateStationStatus({"stationName": "VLS-770C", "status": "ONLINE"});
    }

    function updateStationStatus(hb) {
        for (var i = 0; i < stationModel.count; i++) {
            if (stationModel.get(i).stationName === hb.stationName) {
                stationModel.setProperty(i, "status", hb.status);
                break;
            }
        }
    }

    function filterStations(searchText) {
        root.currentSearchText = searchText // 현재 검색어 저장
        var searchLower = searchText.toLowerCase().trim()
        
        if (searchLower === "") {
            // 검색어가 비어있으면 접기/펼치기 상태만 확인
            for (var i = 0; i < stationModel.count; i++) {
                var shouldBeVisible = root.shouldItemBeVisible(i)
                stationModel.setProperty(i, "isVisible", shouldBeVisible)
            }
            return
        }
        
        // 1단계: 각 항목이 직접 매칭되는지 확인하고, 자식이 매칭되면 부모도 표시
        var itemMatches = []
        for (var i = stationModel.count - 1; i >= 0; i--) {
            var item = stationModel.get(i)
            var stationName = (item.stationName || "").toLowerCase()
            var groupName = (item.groupName || "").toLowerCase()
            var directMatch = stationName.indexOf(searchLower) !== -1 || groupName.indexOf(searchLower) !== -1
            
            // 자식 중 하나라도 매칭되면 부모도 표시
            var childMatches = false
            if (!directMatch && item.depth < 3) {
                for (var j = i + 1; j < stationModel.count; j++) {
                    var childItem = stationModel.get(j)
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
        for (var i = 0; i < stationModel.count; i++) {
            if (!itemMatches[i]) {
                stationModel.setProperty(i, "isVisible", false)
                continue
            }
            var shouldBeVisible = root.shouldItemBeVisible(i)
            stationModel.setProperty(i, "isVisible", shouldBeVisible)
        }
    }
    
    function shouldItemBeVisible(itemIndex) {
        var item = stationModel.get(itemIndex)
        
        // 검색 필터링은 이미 filterStations에서 처리되었으므로, 여기서는 접기/펼치기 상태만 확인
        // 모든 부모 항목의 접기/펼치기 상태를 재귀적으로 확인
        if (item.depth > 0) {
            for (var j = itemIndex - 1; j >= 0; j--) {
                var parentItem = stationModel.get(j)
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

    Rectangle {
        id: stationBackground
        width: parent.width
        height: parent.height
        color: "#1a1a1a"

        property string selectedStation: ""
        property var backend: root.backend

        ColumnLayout {
            anchors.fill: parent
            anchors.centerIn: parent
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            spacing: 10
            clip: true
/*
            // 상단 선택바 (DroneList와 동일 구조)
            Rectangle {
                id: selectedBar_border
                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                Layout.preferredWidth: 280
                Layout.preferredHeight: 30
                color: "transparent"
                border.color: "white"
                border.width: 1
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
                        text: stationBackground.selectedStation === ""
                              ? "선택된 장비: 없음"
                              : ("선택된 장비: " + stationBackground.selectedStation)
                    }
                }

            }
*/
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                spacing: 10
                Item { Layout.fillWidth: true }
                TextField {
                    id: stationSearchBox
                    placeholderText: "스테이션 검색..."
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
                        border.color: stationSearchBox.activeFocus ? "#00BFFF" : "#444"
                        border.width: 1
                        radius: 4
                    }

                    onTextChanged: {
                        root.filterStations(text)
                    }
                }
            }

            Rectangle {
                id: stationScroll
                Layout.preferredWidth: parent.width - 10
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignHCenter
                color: "transparent"
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
                        model: stationModel
                        // DroneList와 동일: ListView spacing 0, 행 간격은 delegate 높이의 _listRowSpacing 에 포함
                        spacing: 0

                        delegate: Item {
                            id: delegateItem
                            width: listView.width
                            readonly property int _rowBodyHeight: nodeType === "station" ? 60 : 40
                            readonly property int _listRowSpacing: 2
                            // DroneList와 동일: depth 들여쓰기 (배수 2→1로 단계 간 간격 완화)
                            readonly property int _depthIndentStep: Math.round(ScreenTools.defaultFontPixelWidth * 1)
                            readonly property int _depthIndent: Math.max(0, Number(model.depth)) * _depthIndentStep
                            readonly property int _rowDepth: Math.max(0, Number(model.depth))
                            height: isVisible ? (_rowBodyHeight + _listRowSpacing) : 0
                            visible: isVisible
                            clip: true

                            Behavior on height { NumberAnimation { duration: 150 } }

                            Rectangle {
                                id: bgRect
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.leftMargin: 2 + delegateItem._depthIndent
                                anchors.rightMargin: 2
                                anchors.topMargin: 2
                                height: _rowBodyHeight - 4
                                z: 0
                                color: {
                                    if (nodeType === "station")
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
                                border.color: (nodeType === "station" && stationBackground.selectedStation === stationName) ? "#00BFFF" : "#333"
                                border.width: (nodeType === "station" && stationBackground.selectedStation === stationName) ? 3 : 1
                                radius: 4
                            }

                            RowLayout {
                                id: contentLayout
                                anchors.fill: bgRect
                                anchors.leftMargin: 10
                                // 스크롤 유무와 무관하게 세로 스크롤바 폭만큼 우측 여백 확보 (DroneList와 동일)
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
                                    visible: nodeType !== "station"
                                }

                                Item {
                                    width: 12
                                    height: 12
                                    visible: nodeType === "station"
                                }

                                Text {
                                    id: iconText
                                    font.pointSize: ScreenTools.mediumFontPointSize
                                    text: {
                                        if (nodeType === "station")
                                            return "📡"
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
                                    text: nodeType === "station" ? stationName : groupName
                                    color: {
                                        if (nodeType === "station")
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
                                    font.bold: nodeType !== "station"
                                    font.pointSize: ScreenTools.defaultFontPointSize
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    verticalAlignment: Text.AlignVCenter
                                }

                                RowLayout {
                                    visible: nodeType === "station"
                                    spacing: 15
                                    // RowLayout은 Layout.fillWidth 기본 true → false로 명시해야 hug(우측정렬 밀착). DroneList와 동일
                                    Layout.fillWidth: false
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                                    Text {
                                        text: status === "ONLINE" ? "📶" : "⚠️"
                                        font.pointSize: ScreenTools.defaultFontPointSize
                                        Layout.preferredWidth: 20
                                        Layout.alignment: Qt.AlignVCenter
                                        color: status === "ONLINE" ? "#44ff44" : "#ff4444"
                                    }

                                    Text {
                                        text: status
                                        color: status === "ONLINE" ? "#44ff44" : "#ff4444"
                                        font.pointSize: ScreenTools.smallFontPointSize
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                z: 2
                                onClicked: {
                                    if (nodeType === "station") {
                                        stationBackground.selectedStation = (stationBackground.selectedStation === stationName) ? "" : stationName
                                    } else {
                                        var newExpanded = !isExpanded
                                        stationModel.setProperty(index, "isExpanded", newExpanded)
                                        // 하위 항목들의 가시성을 결정 (필터링 상태 고려, isExpanded 상태는 유지)
                                        for (var i = index + 1; i < stationModel.count; i++) {
                                            if (stationModel.get(i).depth > depth) {
                                                // 필터링 상태와 접기/펼치기 상태를 모두 확인
                                                // 부모가 접혀있으면 자식도 숨김 (하지만 isExpanded 상태는 유지)
                                                var shouldBeVisible = newExpanded && root.shouldItemBeVisible(i)
                                                stationModel.setProperty(i, "isVisible", shouldBeVisible)
                                                
                                                // 부모가 펼쳐져 있고, 자식이 펼쳐져 있으면 그 자식들도 처리
                                                if (newExpanded && stationModel.get(i).isExpanded) {
                                                    // 재귀적으로 자식의 자식들도 업데이트
                                                    var childDepth = stationModel.get(i).depth
                                                    for (var j = i + 1; j < stationModel.count; j++) {
                                                        if (stationModel.get(j).depth > childDepth) {
                                                            var childShouldBeVisible = root.shouldItemBeVisible(j)
                                                            stationModel.setProperty(j, "isVisible", childShouldBeVisible)
                                                        } else {
                                                            break
                                                        }
                                                    }
                                                }
                                            } else break
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
}
