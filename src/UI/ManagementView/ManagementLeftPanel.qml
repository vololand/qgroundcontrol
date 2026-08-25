/****************************************************************************
 *
 * QGroundControl Open Source Ground Control Station
 *
 * Left tree panel – data-driven recursive tree (arbitrary depth)
 *
 * 구조:
 *   _treeData (JS 트리)
 *     → refreshTree() → _flatModel (ListModel) + _nodeRefs (refs 배열)
 *     → Repeater가 _flatModel 구독 → 변경 즉시 반응
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Palette
import QGroundControl.Controls
import QGroundControl.ScreenTools

Rectangle {
    id:     _root
    color:  qgcPal.windowShade

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    readonly property real _rowH:    ScreenTools.defaultFontPixelHeight * 2.2
    readonly property real _fPt:     ScreenTools.defaultFontPointSize*1.5
    readonly property real _fW:      ScreenTools.defaultFontPixelWidth
    readonly property real _fH:      ScreenTools.defaultFontPixelHeight
    readonly property real _indSize: _fW * 1.1
    property bool _listRefreshing: false

    signal requestGroupAdd(string parentName)
    signal requestGroupEdit(string groupName, string parentName, string nodeType)
    signal requestGroupDetail(string groupName, string parentName, string nodeType)
    signal requestGroupDelete(string groupName)
    signal requestGroupRefresh(string groupName)   // group·subGroup: 해당 그룹 데이터 갱신
    signal requestTreeRefresh()                    // org: 트리 전체 갱신
    signal requestUserAdd()
    signal requestUserEdit(string userName)
    signal requestUserDelete(string userName)
    signal requestUserDetail(string userName)
    signal requestUserManagementListRefresh()
    signal requestAssetAdd(string groupName)
    signal requestAssetEdit(string assetName)
    signal requestAssetDelete(string assetName)
    signal requestAssetDetail(string assetName)
    signal requestAssetManagementListRefresh()

    // 우클릭 시점에 선택된 flatModel 인덱스
    property int _rightClickIdx: -1

    property string _activeTab: "users"   // users | assets
    property var    _expandedStateByTab: ({ users: ({}), assets: ({}) })

    // ── 좌측 리스트 새로고침 상태 (서버 연동 전 플레이스홀더)
    Timer {
        id:       _listRefreshTimer
        interval: 900
        onTriggered: _root._listRefreshing = false
    }

    // ── 노드 타입 정의
    // org      : 조직 컨테이너 (VOLOLAND, 1개 고정)
    // group    : 1뎁스 그룹    (org 직속, 여러 개 가능)
    // subGroup : 2뎁스 그룹    (group 직속)
    // user     : 사용자 노드   (그룹 경로 하위 리프)
    // asset    : 자산 노드     (그룹 경로 하위 리프)

    // ── 트리 원본 데이터 (서버 연동 시 교체)
    // TODO: 서버에서 그룹 목록, 사용자 목록, 자산 목록을 분리 수신한 뒤
    //       org/group/subGroup 경로에 users/assets 배열을 매핑해 이 객체를 구성
    //       예) function loadTree(serverData) { _treeData = serverData; refreshTree() }
    property var _treeData: ({
        name: "VOLOLAND",   type: "org",
        expanded: true,
        users: [],
        assets: [],
        children: [
            {
                name: "미래항공모빌리티연구소", type: "group",
                expanded: true,
                users: [],
                assets: [],
                children: [
                    {
                        name: "볼로 무인기 & 지상플랫폼그룹", type: "subGroup",
                        expanded: false,
                        users: [
                            { name: "admin1", type: "user" },
                            { name: "user1",  type: "user" }
                        ],
                        assets: [
                            { name: "A-1", type: "asset" },
                            { name: "VLS-770C", type: "asset" }
                        ],
                        children: []
                    },
                    {
                        name: "볼로 자율비행플랫폼 그룹", type: "subGroup",
                        expanded: false,
                        users: [
                            { name: "user2", type: "user" }
                        ],
                        assets: [
                            { name: "B-1", type: "asset" },
                            { name: "VLS-400C", type: "asset" }
                        ],
                        children: []
                    }
                ]
            },
            {
                name: "경영지원실", type: "group",
                expanded: false,
                users: [
                    { name: "user3", type: "user" }
                ],
                assets:[

                ],
                children: []
            }
        ]
    })

    // ── Repeater 모델: ListModel (clear+append로 항상 반응 보장)
    ListModel { id: _flatModel }

    // ── 원본 노드 참조 배열 (_flatModel 인덱스와 1:1 대응)
    property var _nodeRefs: []

    // ── 상위 그룹 콤보 목록 (org·group 노드만) — 그룹 등록/수정에서 사용
    property var parentGroupNames: []

    // ── 사용자 등록 그룹 콤보 목록 (org·group·subGroup 전체) — 사용자 등록에서 사용
    property var allGroupNames: []

    function _tabTitle(tabName) {
        if (tabName === "users")  return qsTr("사용자")
        return qsTr("자산")
    }

    function _visibleChildCount(node) {
        var count = node.children ? node.children.length : 0
        if (_activeTab === "users" && node.users) {
            count += node.users.length
        } else if (_activeTab === "assets" && node.assets) {
            count += node.assets.length
        }
        return count
    }

    function _isNodeExpanded(node, nodeKey) {
        var tabState = _expandedStateByTab[_activeTab]
        if (tabState && tabState[nodeKey] !== undefined) {
            return tabState[nodeKey]
        }
        return node.expanded
    }

    function _setNodeExpanded(nodeKey, expanded) {
        var state = _expandedStateByTab
        var tabState = state[_activeTab]
        if (!tabState) {
            tabState = ({})
        }
        tabState[nodeKey] = expanded
        state[_activeTab] = tabState
        _expandedStateByTab = state
    }

    // DFS 순회 → _flatModel 및 _nodeRefs 재빌드
    // parentName: 부모 노드의 name (root는 빈 문자열)
    function buildFlatList(node, depth, refs, parentName, nodeKey) {
        var expanded = _isNodeExpanded(node, nodeKey)
        _flatModel.append({
            itemName:    node.name,
            itemDepth:   depth,
            nodeType:    node.type,
            hasChildren: _visibleChildCount(node) > 0,
            isExpanded:  expanded,
            parentName:  parentName,      // 상위 그룹명 (수정 페이지 pre-fill용)
            itemKey:     nodeKey
        })
        refs.push(node)

        if (!expanded) {
            return
        }

        if (node.children) {
            for (var i = 0; i < node.children.length; i++) {
                buildFlatList(node.children[i], depth + 1, refs, node.name, nodeKey + "/" + i)
            }
        }

        var leafList = []
        if (_activeTab === "users" && node.users) {
            leafList = node.users
        } else if (_activeTab === "assets" && node.assets) {
            leafList = node.assets
        }

        for (var j = 0; j < leafList.length; j++) {
            var leaf = leafList[j]
            _flatModel.append({
                itemName:    leaf.name,
                itemDepth:   depth + 1,
                nodeType:    leaf.type,
                hasChildren: false,
                isExpanded:  false,
                parentName:  node.name,
                itemKey:     nodeKey + "/leaf/" + j
            })
            refs.push(leaf)
        }
    }

    // org·group 노드 이름만 추출 → 그룹 등록/수정 상위 그룹 콤보 모델로 사용
    function _buildParentGroupNames() {
        var list = []
        function traverse(node) {
            if (node.type === "org" || node.type === "group") {
                list.push(node.name)
            }
            if (node.children) {
                for (var i = 0; i < node.children.length; i++) {
                    traverse(node.children[i])
                }
            }
        }
        traverse(_treeData)
        parentGroupNames = list
    }

    // org·group·subGroup 노드 이름 모두 추출 → 사용자 등록 그룹 콤보 모델로 사용
    function _buildAllGroupNames() {
        var list = []
        function traverse(node) {
            if (node.type === "org" || node.type === "group" || node.type === "subGroup") {
                list.push(node.name)
            }
            if (node.children) {
                for (var i = 0; i < node.children.length; i++) {
                    traverse(node.children[i])
                }
            }
        }
        traverse(_treeData)
        allGroupNames = list
    }

    function refreshTree() {
        _flatModel.clear()
        var refs = []
        buildFlatList(_treeData, 0, refs, "", "root")
        _nodeRefs = refs
        _buildParentGroupNames()
        _buildAllGroupNames()
    }

    Component.onCompleted: refreshTree()

    // ── 그룹 노드용 컨텍스트 메뉴 (org · group · subGroup)
    Menu {
        id: _groupContextMenu

        MenuItem {
            text: qsTr("그룹 추가")
            onTriggered: {
                var parentName = _flatModel.get(_root._rightClickIdx).itemName
                _root.requestGroupAdd(parentName)
            }
        }

        MenuItem {
            text: qsTr("그룹 수정")
            onTriggered: {
                var node = _flatModel.get(_root._rightClickIdx)
                _root.requestGroupEdit(node.itemName, node.parentName, node.nodeType)
            }
        }

        MenuItem {
            text: qsTr("그룹 상세")
            onTriggered: {
                var node = _flatModel.get(_root._rightClickIdx)
                _root.requestGroupDetail(node.itemName, node.parentName, node.nodeType)
            }
        }

        MenuItem {
            text: _root._activeTab === "users" ? qsTr("사용자 등록") : qsTr("자산 등록")
            onTriggered: {
                if (_root._activeTab === "users") {
                    _root.requestUserAdd()
                } else {
                    var groupName = _flatModel.get(_root._rightClickIdx).itemName
                    _root.requestAssetAdd(groupName)
                }
            }
        }

        // ── 구분선
        MenuSeparator {}

        // 업데이트: org → 트리 전체 갱신, group·subGroup → 해당 그룹 데이터 갱신
        // TODO: 서버에서 최신 데이터 수신 후 트리 갱신
        MenuItem {
            text: qsTr("업데이트")
            onTriggered: {
                var node = _flatModel.get(_root._rightClickIdx)
                if (node.nodeType === "org") {
                    _root.requestTreeRefresh()
                } else {
                    _root.requestGroupRefresh(node.itemName)
                }
            }
        }

        // 그룹 삭제: org(고정 노드)는 비활성, group·subGroup(1~2뎁스)만 활성
        // TODO: 서버 그룹삭제 API 호출 — 하위 노드 존재 시 처리 정책 서버와 협의 필요
        MenuItem {
            text:    qsTr("그룹 삭제")
            enabled: _root._rightClickIdx >= 0 &&
                     (_flatModel.count > _root._rightClickIdx) &&
                     (_flatModel.get(_root._rightClickIdx).nodeType === "group" ||
                      _flatModel.get(_root._rightClickIdx).nodeType === "subGroup")

            contentItem: Text {
                text:  parent.text
                color: parent.enabled ? "#F44336" : "#666666"
                font:  parent.font
                verticalAlignment: Text.AlignVCenter
            }

            onTriggered: {
                var groupName = _flatModel.get(_root._rightClickIdx).itemName
                _root.requestGroupDelete(groupName)
            }
        }
    }

    // ── 사용자 노드용 컨텍스트 메뉴 (user)
    Menu {
        id: _userContextMenu

        MenuItem {
            text: qsTr("사용자 수정")
            onTriggered: {
                var userName = _flatModel.get(_root._rightClickIdx).itemName
                _root.requestUserEdit(userName)
            }
        }

        // ── 구분선
        MenuSeparator {}

        // TODO: 서버 사용자삭제 API 호출
        MenuItem {
            text: qsTr("사용자 삭제")

            contentItem: Text {
                text:  parent.text
                color: "#F44336"
                font:  parent.font
                verticalAlignment: Text.AlignVCenter
            }

            onTriggered: {
                var userName = _flatModel.get(_root._rightClickIdx).itemName
                _root.requestUserDelete(userName)
            }
        }
    }

    // ── 자산 노드용 컨텍스트 메뉴 (asset)
    Menu {
        id: _assetContextMenu

        MenuItem {
            text: qsTr("자산 수정")
            onTriggered: {
                var assetName = _flatModel.get(_root._rightClickIdx).itemName
                _root.requestAssetEdit(assetName)
            }
        }

        // ── 구분선
        MenuSeparator {}

        // TODO: 서버 자산삭제 API 호출
        MenuItem {
            text: qsTr("자산 삭제")

            contentItem: Text {
                text:  parent.text
                color: "#F44336"
                font:  parent.font
                verticalAlignment: Text.AlignVCenter
            }

            onTriggered: {
                var assetName = _flatModel.get(_root._rightClickIdx).itemName
                _root.requestAssetDelete(assetName)
            }
        }
    }

    // ── 좌측 패널 탭
    Row {
        id:              _tabBar
        anchors.left:    parent.left
        anchors.right:   parent.right
        anchors.top:     parent.top
        anchors.margins: _fH * 0.5
        height:          _fH * 2.2
        spacing:         _fW * 0.4

        Repeater {
            model: [ "users", "assets" ]

            Rectangle {
                width:  (_tabBar.width - _tabBar.spacing) / 2
                height: _tabBar.height
                radius: 3
                color:  _root._activeTab === modelData ? qgcPal.buttonHighlight : qgcPal.windowShadeDark
                border.color: qgcPal.windowShadeDark
                border.width: 1

                QGCLabel {
                    anchors.centerIn: parent
                    text:             _root._tabTitle(modelData)
                    font.pointSize:   ScreenTools.defaultFontPointSize
                    font.bold:        _root._activeTab === modelData
                    color:            _root._activeTab === modelData ? qgcPal.buttonHighlightText : qgcPal.text
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        _root._activeTab = modelData
                        _root.refreshTree()
                    }
                }
            }
        }
    }

    // ── 스크롤 가능한 트리 영역
    QGCFlickable {
        id:                  _flick
        anchors.left:        parent.left
        anchors.right:       parent.right
        anchors.top:         _tabBar.bottom
        anchors.topMargin:   _fH * 0.4
        anchors.bottom:      _addGroupBtn.top
        anchors.bottomMargin: _fH * 0.5
        contentHeight:       _treeCol.height
        flickableDirection:  Flickable.VerticalFlick
        clip:                true

        Column {
            id:    _treeCol
            width: _flick.width

            Repeater {
                model: _flatModel

                Item {
                    id:     _delegate
                    width:  _treeCol.width
                    height: _root._rowH

                    // nodeType 기반 리프 판단 (user·asset은 항상 리프)
                    readonly property bool   _isLeaf:      nodeType === "user" || nodeType === "asset"
                    readonly property bool   _hasChildren: hasChildren
                    readonly property real   _indent:   itemDepth * _root._indSize + _root._fW
                    // 모델 롤을 프로퍼티로 명시 캡처 (signal handler 내에서 안정적 접근 보장)
                    readonly property string _nodeName: itemName
                    readonly property string _nodeType: nodeType
                    readonly property string _nodeKey:  itemKey

                    // 호버 강조
                    Rectangle {
                        anchors.fill: parent
                        color:        _ma.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    }

                    // 좌클릭: 그룹 계열 토글 / 우클릭: 컨텍스트 메뉴
                    MouseArea {
                        id:              _ma
                        anchors.fill:    parent
                        hoverEnabled:    true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                if (!_delegate._isLeaf && _delegate._hasChildren) {
                                    _root._setNodeExpanded(_delegate._nodeKey, !isExpanded)
                                    _root.refreshTree()
                                }
                            } else if (mouse.button === Qt.RightButton) {
                                _root._rightClickIdx = index
                                if (_delegate._nodeType === "org" || _delegate._nodeType === "group" || _delegate._nodeType === "subGroup") {
                                    _groupContextMenu.popup()
                                } else if (_delegate._nodeType === "user") {
                                    _userContextMenu.popup()
                                } else if (_delegate._nodeType === "asset") {
                                    _assetContextMenu.popup()
                                }
                            }
                        }

                        onDoubleClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton && _delegate._nodeType === "user") {
                                _root.requestUserDetail(_delegate._nodeName)
                            } else if (mouse.button === Qt.LeftButton && _delegate._nodeType === "asset") {
                                _root.requestAssetDetail(_delegate._nodeName)
                            }
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left:           parent.left
                        anchors.leftMargin:     _delegate._indent
                        spacing:                _root._fW * 0.5

                        // 아이콘: user → "👤"  asset → "○"  그룹 → ▼▶
                        QGCLabel {
                            text: {
                                if (_delegate._nodeType === "user")  return "👤"
                                if (_delegate._nodeType === "asset") return "○"
                                if (!_delegate._hasChildren) return "•"
                                return isExpanded ? "▼" : "▶"
                            }
                            font.pointSize: _delegate._isLeaf ? _root._fPt * 0.8 : _root._fPt * 0.85
                            color:          qgcPal.text
                        }

                        QGCLabel {
                            text:           _delegate._nodeName
                            font.pointSize: _root._fPt
                            font.bold:      _delegate._nodeType === "org"
                            color:          qgcPal.text
                        }
                    }

                    // ── 0뎁스 리스트 새로고침 버튼 (우측패널 새로고침과 동일한 아이콘형 UI)
                    Rectangle {
                        visible:              itemDepth === 0
                        anchors.right:        parent.right
                        anchors.rightMargin:  _root._fW * 0.8
                        anchors.verticalCenter: parent.verticalCenter
                        width:                _root._fH * 1.8
                        height:               _root._fH * 1.8
                        radius:               4
                        color:                _leftRefreshMa.containsMouse ? qgcPal.windowShade : "transparent"
                        z:                    2

                        QGCLabel {
                            id:             _leftRefreshIcon
                            anchors.centerIn: parent
                            text:           "↺"
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.2
                            color:          _root._listRefreshing ? qgcPal.primaryButton : qgcPal.text

                            NumberAnimation on rotation {
                                running:  _root._listRefreshing
                                from:     0; to: 360
                                duration: 900
                                loops:    Animation.Infinite
                            }
                            onRotationChanged: if (!_root._listRefreshing) rotation = 0
                        }

                        MouseArea {
                            id:           _leftRefreshMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: {
                                if (_root._listRefreshing) return
                                _root._listRefreshing = true
                                _listRefreshTimer.restart()

                                if (_root._activeTab === "users") {
                                    _root.requestUserManagementListRefresh()
                                } else {
                                    _root.requestAssetManagementListRefresh()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 그룹 추가 버튼
    QGCButton {
        id:              _addGroupBtn
        anchors.left:    parent.left
        anchors.right:   parent.right
        anchors.bottom:  parent.bottom
        anchors.margins: _fH * 0.5
        text:      qsTr("그룹 추가")
        onClicked: _root.requestGroupAdd("")   // 일반 추가: 상위 그룹 비지정
    }
}
