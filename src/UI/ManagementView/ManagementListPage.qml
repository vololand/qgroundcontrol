/****************************************************************************
 *
 * QGroundControl Open Source Ground Control Station
 *
 * Right-side management page – tabs / filter / list / pagination
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Palette
import QGroundControl.Controls
import QGroundControl.ScreenTools

Item {
    id: _root

    // ManagementView가 수신 → 오버레이 표시
    signal requestUserAdd()
    signal requestUserEdit(string userName)
    signal requestUserDetail(string userName)
    signal requestAssetAdd()
    signal requestAssetEdit(string assetName)
    signal requestAssetDetail(string assetName)

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    readonly property real _fPt:    ScreenTools.defaultFontPointSize * 1.2
    readonly property real _fH:     ScreenTools.defaultFontPixelHeight
    readonly property real _fW:     ScreenTools.defaultFontPixelWidth
    readonly property real _rowH:   _fH * 2.2
    readonly property real _margin: _fH * 0.5

    // Table column widths (proportional to available width)
    readonly property real _cNum:    width * 0.055
    readonly property real _cUser:   width * 0.130
    readonly property real _cId:     width * 0.090
    readonly property real _cRole:   width * 0.140
    readonly property real _cGroup:  width * 0.110
    readonly property real _cDate:   width * 0.130
    readonly property real _cStatus: width * 0.120
    readonly property real _cMgmt:   width * 0.225

    property int _activeTab:   0
    property int _currentPage: 1
    property int _totalPages:  1
    property int _pageSize:    10

    // ── 필터 상태 (사용자)
    property string _uf_name:     ""
    property int    _uf_roleIdx:  0
    property int    _uf_grpIdx:   0
    property string _uf_dateFrom: ""
    property string _uf_dateTo:   ""

    // ── 필터 상태 (자산)
    property string _af_name:     ""
    property int    _af_typeIdx:  0
    property int    _af_grpIdx:   0
    property string _af_dateFrom: ""
    property string _af_dateTo:   ""

    // ── 소스 데이터 + 필터 결과 (빈 배열로 시작)
    property var _allUsers:  []
    property var _allAssets: []
    property var _fltUsers:  []
    property var _fltAssets: []
    property var _pageButtons: []

    // ── 콤보박스 모델
    readonly property var _roleComboModel: ["", "SUPER_ADMIN", "GROUP_ADMIN", "USER"]
    readonly property var _userGrpModel:   ["", "볼로랜드"]
    readonly property var _assetTypeModel: ["", "멀티콥터", "스테이션"]
    readonly property var _assetGrpModel:  ["", "볼로 무인기 & 지상플랫폼그룹", "볼로 자율비행플랫폼 그룹", "경영지원실"]

    // ── Display models (필터링된 현재 페이지 데이터)
    ListModel { id: _userModel  }
    ListModel { id: _assetModel }

    // ── 날짜 입력 컴포넌트 (YYYY-MM-DD 자동 형식, 미입력 시 빈칸)
    component DateField: Rectangle {
        property alias text: _ti.text
        property bool  _fmt: false
        implicitWidth:  _fW * 14
        implicitHeight: _fH * 2.2
        color:        qgcPal.windowShade
        radius:       _fH * 0.15
        border.width: 1
        border.color: _ti.activeFocus ? qgcPal.primaryButton : qgcPal.windowShadeDark

        // 숫자 입력 시 YYYY-MM-DD 자동 삽입
        function _doFormat() {
            if (_fmt) return
            _fmt = true
            var d = _ti.text.replace(/[^0-9]/g, "")
            if (d.length > 8) d = d.substring(0, 8)
            var f = d.length <= 4 ? d
                  : d.length <= 6 ? d.substring(0, 4) + "-" + d.substring(4)
                  :                  d.substring(0, 4) + "-" + d.substring(4, 6) + "-" + d.substring(6)
            if (_ti.text !== f) _ti.text = f
            _fmt = false
        }

        // placeholder (포커스 없고 비어있을 때만 표시)
        Text {
            anchors.fill:       parent
            anchors.leftMargin: _fW * 0.5
            text:               "YYYY-MM-DD"
            color:              "#888888"
            font.pointSize:     _fPt
            verticalAlignment:  Text.AlignVCenter
            visible:            _ti.text.length === 0 && !_ti.activeFocus
        }

        TextInput {
            id:                  _ti
            anchors.fill:        parent
            anchors.leftMargin:  _fW * 0.5
            anchors.rightMargin: _fW * 0.5
            font.pointSize:      _fPt
            color:               qgcPal.text
            verticalAlignment:   TextInput.AlignVCenter
            clip:                true
            onTextChanged:       _doFormat()
        }
    }

    // ── 초기화 — TODO: 서버 연동 시 _allUsers / _allAssets 를 API 응답으로 교체
    Component.onCompleted: {
        _allUsers = [
            { seq: 1, username: "superadmin", userId: "----", role: "SUPER_ADMIN", grp: "n/a",      regDate: "2026-04-17", status: "활성화" },
            { seq: 2, username: "admin1",     userId: "----", role: "GROUP_ADMIN", grp: "볼로랜드", regDate: "2026-04-17", status: "활성화" },
            { seq: 3, username: "admin2",     userId: "----", role: "GROUP_ADMIN", grp: "볼로랜드", regDate: "2026-04-17", status: "잠금"   },
            { seq: 4, username: "user",       userId: "----", role: "USER",        grp: "볼로랜드", regDate: "2026-04-17", status: "활성화" }
        ]
        _allAssets = [
            { seq: 1, assetName: "A-1", assetId: "1", assetType: "멀티콥터", grp: "볼로 무인기 & 지상플랫폼그룹", regDate: "2026-04-10", status: "활성화" },
            { seq: 2, assetName: "B-1",  assetId: "2", assetType: "멀티콥터", grp: "볼로 자율비행플랫폼 그룹",     regDate: "2026-04-11", status: "활성화" },
            { seq: 3, assetName: "VLS-770C",  assetId: "3", assetType: "스테이션", grp: "볼로 무인기 & 지상플랫폼 그룹",                   regDate: "2026-04-12", status: "잠금" },
            { seq: 4, assetName: "VLS-400C",  assetId: "4", assetType: "스테이션", grp: "볼로 자율비행플랫폼 그룹",                   regDate: "2026-04-12", status: "잠금" }
        ]
        _applyUserFilter()
    }

    // ── 사용자 필터 적용
    function _applyUserFilter() {
        var selRole  = _uf_roleIdx > 0 ? _roleComboModel[_uf_roleIdx] : ""
        var selGrp   = _uf_grpIdx  > 0 ? _userGrpModel[_uf_grpIdx]   : ""
        // 날짜: YYYY-MM-DD 10자리 완성된 경우에만 필터 적용
        var dateFrom = _uf_dateFrom.length === 10 ? _uf_dateFrom : ""
        var dateTo   = _uf_dateTo.length   === 10 ? _uf_dateTo   : ""
        var r = []
        for (var i = 0; i < _allUsers.length; i++) {
            var u = _allUsers[i]
            if (_uf_name && u.username.toLowerCase().indexOf(_uf_name.toLowerCase()) < 0) continue
            if (selRole  && u.role !== selRole)                                            continue
            if (selGrp   && u.grp  !== selGrp)                                            continue
            if (dateFrom && u.regDate < dateFrom)                                          continue
            if (dateTo   && u.regDate > dateTo)                                            continue
            r.push(u)
        }
        _fltUsers    = r
        _totalPages  = Math.max(1, Math.ceil(r.length / _pageSize))
        _currentPage = 1
        _loadUserPage()
        _rebuildPageButtons()
    }

    function _loadUserPage() {
        var s = (_currentPage - 1) * _pageSize
        _userModel.clear()
        for (var i = s; i < Math.min(s + _pageSize, _fltUsers.length); i++)
            _userModel.append(_fltUsers[i])
    }

    function _resetUserFilter() {
        _uf_name = ""; _uf_roleIdx = 0; _uf_grpIdx = 0
        _uf_dateFrom = ""; _uf_dateTo = ""
        _uiUserName.text          = ""
        _uiUserRole.currentIndex  = 0
        _uiUserGrp.currentIndex   = 0
        _uiUserDateFrom.text      = ""
        _uiUserDateTo.text        = ""
        _applyUserFilter()
    }

    // ── 자산 필터 적용
    function _applyAssetFilter() {
        var selType  = _af_typeIdx > 0 ? _assetTypeModel[_af_typeIdx] : ""
        var selGrp   = _af_grpIdx  > 0 ? _assetGrpModel[_af_grpIdx]  : ""
        // 날짜: YYYY-MM-DD 10자리 완성된 경우에만 필터 적용
        var dateFrom = _af_dateFrom.length === 10 ? _af_dateFrom : ""
        var dateTo   = _af_dateTo.length   === 10 ? _af_dateTo   : ""
        var r = []
        for (var i = 0; i < _allAssets.length; i++) {
            var a = _allAssets[i]
            if (_af_name && a.assetName.toLowerCase().indexOf(_af_name.toLowerCase()) < 0) continue
            if (selType  && a.assetType !== selType)                                        continue
            if (selGrp   && a.grp       !== selGrp)                                         continue
            if (dateFrom && a.regDate < dateFrom)                                            continue
            if (dateTo   && a.regDate > dateTo)                                              continue
            r.push(a)
        }
        _fltAssets   = r
        _totalPages  = Math.max(1, Math.ceil(r.length / _pageSize))
        _currentPage = 1
        _loadAssetPage()
        _rebuildPageButtons()
    }

    function _loadAssetPage() {
        var s = (_currentPage - 1) * _pageSize
        _assetModel.clear()
        for (var i = s; i < Math.min(s + _pageSize, _fltAssets.length); i++)
            _assetModel.append(_fltAssets[i])
    }

    function _resetAssetFilter() {
        _af_name = ""; _af_typeIdx = 0; _af_grpIdx = 0
        _af_dateFrom = ""; _af_dateTo = ""
        _uiAssetName.text         = ""
        _uiAssetType.currentIndex = 0
        _uiAssetGrp.currentIndex  = 0
        _uiAssetDateFrom.text     = ""
        _uiAssetDateTo.text       = ""
        _applyAssetFilter()
    }

    // ── 페이지 이동
    function _rebuildPageButtons() {
        var b = ["<<", "<"]
        var s = Math.max(1, _currentPage - 2)
        var e = Math.min(_totalPages, s + 4)
        if (e - s < 4) s = Math.max(1, e - 4)
        for (var i = s; i <= e; i++) b.push(String(i))
        b.push(">")
        b.push(">>")
        _pageButtons = b
    }

    function _goPage(lbl) {
        var p = _currentPage
        if      (lbl === "<<") p = 1
        else if (lbl === "<")  p = Math.max(1, p - 1)
        else if (lbl === ">>") p = _totalPages
        else if (lbl === ">")  p = Math.min(_totalPages, p + 1)
        else                   p = parseInt(lbl)
        _currentPage = p
        if (_activeTab === 0) _loadUserPage()
        else                  _loadAssetPage()
        _rebuildPageButtons()
    }

    // ──────────────────────────────────────────────────────────
    // Top section  (tabs + filter + list title + table header)
    // ──────────────────────────────────────────────────────────
    Column {
        id:          _topSection
        width:       parent.width
        anchors.top: parent.top
        spacing:     _margin

        // ── Tab buttons
        Row {
            spacing: 0
            Repeater {
                model: [qsTr("사용자"), qsTr("자산")]
                Item {
                    width:  _fW * 8
                    height: _fH * 2
                    Rectangle {
                        anchors.fill: parent
                        color:        _activeTab === index ? qgcPal.window : qgcPal.windowShade
                        border.color: qgcPal.windowShade
                        border.width: 1
                    }
                    // Active underline
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        height:         _activeTab === index ? 2 : 0
                        color:          qgcPal.text
                    }
                    QGCLabel {
                        anchors.centerIn: parent
                        text:             modelData
                        font.pointSize:   _fPt
                        color:            qgcPal.text
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            _activeTab = index
                            if (index === 0) _applyUserFilter()
                            else             _applyAssetFilter()
                        }
                    }
                }
            }
        }

        // ── Filter section (사용자 탭)
        Column {
            width:   parent.width
            spacing: _margin * 0.5
            visible: _activeTab === 0

            // Filter row 1: 이름 / ROLE / 소속기관 / action buttons
            RowLayout {
                width:   parent.width
                spacing: _fW

                QGCLabel    { text: qsTr("이름"); font.pointSize: _fPt; color: qgcPal.text }
                QGCTextField {
                    id:                    _uiUserName
                    Layout.preferredWidth: _fW * 14
                    placeholderText:       ""
                    onTextChanged:         _uf_name = text
                }

                QGCLabel { text: "ROLE"; font.pointSize: _fPt; color: qgcPal.text }
                QGCComboBox {
                    id:                    _uiUserRole
                    Layout.preferredWidth: _fW * 16
                    model:                 _roleComboModel
                    onCurrentIndexChanged: _uf_roleIdx = currentIndex
                }

                QGCLabel    { text: qsTr("그룹"); font.pointSize: _fPt; color: qgcPal.text }
                QGCComboBox {
                    id:                    _uiUserGrp
                    Layout.preferredWidth: _fW * 14
                    model:                 _userGrpModel
                    onCurrentIndexChanged: _uf_grpIdx = currentIndex
                }

                Item { Layout.fillWidth: true }

                QGCButton { text: qsTr("검색");      onClicked: _applyUserFilter() }
                QGCButton { text: qsTr("초기화");    onClicked: _resetUserFilter() }
                QGCButton { text: qsTr("신규 등록"); onClicked: _root.requestUserAdd() }
            }

            // Filter row 2: 기간
            RowLayout {
                width:   parent.width
                spacing: _fW

                QGCLabel { text: qsTr("기간"); font.pointSize: _fPt; color: qgcPal.text }
                DateField {
                    id:                    _uiUserDateFrom
                    Layout.preferredWidth: _fW * 14
                    onTextChanged:         _uf_dateFrom = text
                }
                QGCLabel { text: "~"; font.pointSize: _fPt; color: qgcPal.text }
                DateField {
                    id:                    _uiUserDateTo
                    Layout.preferredWidth: _fW * 14
                    onTextChanged:         _uf_dateTo = text
                }
                Item { Layout.fillWidth: true }
            }
        }

        // ── Filter section (자산 탭)
        Column {
            width:   parent.width
            spacing: _margin * 0.5
            visible: _activeTab === 1

            // Filter row 1: 이름 / 유형 / 소속그룹 / action buttons
            RowLayout {
                width:   parent.width
                spacing: _fW

                QGCLabel { text: qsTr("이름"); font.pointSize: _fPt; color: qgcPal.text }
                QGCTextField {
                    id:                    _uiAssetName
                    Layout.preferredWidth: _fW * 14
                    placeholderText:       ""
                    onTextChanged:         _af_name = text
                }

                QGCLabel { text: qsTr("유형"); font.pointSize: _fPt; color: qgcPal.text }
                QGCComboBox {
                    id:                    _uiAssetType
                    Layout.preferredWidth: _fW * 14
                    model:                 _assetTypeModel
                    onCurrentIndexChanged: _af_typeIdx = currentIndex
                }

                QGCLabel { text: qsTr("그룹"); font.pointSize: _fPt; color: qgcPal.text }
                QGCComboBox {
                    id:                    _uiAssetGrp
                    Layout.preferredWidth: _fW * 18
                    model:                 _assetGrpModel
                    onCurrentIndexChanged: _af_grpIdx = currentIndex
                }

                Item { Layout.fillWidth: true }

                QGCButton { text: qsTr("검색");      onClicked: _applyAssetFilter() }
                QGCButton { text: qsTr("초기화");    onClicked: _resetAssetFilter() }
                QGCButton { text: qsTr("신규 등록"); onClicked: _root.requestAssetAdd() }
            }

            // Filter row 2: 기간
            RowLayout {
                width:   parent.width
                spacing: _fW

                QGCLabel { text: qsTr("기간"); font.pointSize: _fPt; color: qgcPal.text }
                DateField {
                    id:                    _uiAssetDateFrom
                    Layout.preferredWidth: _fW * 14
                    onTextChanged:         _af_dateFrom = text
                }
                QGCLabel { text: "~"; font.pointSize: _fPt; color: qgcPal.text }
                DateField {
                    id:                    _uiAssetDateTo
                    Layout.preferredWidth: _fW * 14
                    onTextChanged:         _af_dateTo = text
                }
                Item { Layout.fillWidth: true }
            }
        }

        // ── List title row
        RowLayout {
            width:   parent.width
            height:  _fH * 2
            spacing: _fW * 0.5

            QGCLabel {
                text:           _activeTab === 0 ? qsTr("사용자 목록") : qsTr("자산 목록")
                font.pointSize: _fPt
                font.bold:      true
                color:          qgcPal.text
            }

            Item { Layout.fillWidth: true }
        }

        // ── Table header
        Rectangle {
            id:     _tableHeader
            width:  parent.width
            height: _rowH
            color:  qgcPal.windowShadeDark

            // 사용자 헤더
            Row {
                anchors.fill:       parent
                anchors.leftMargin: _fW * 0.5
                visible:            _activeTab === 0

                Repeater {
                    model: [
                        { lbl: qsTr("번호"),      cw: _root._cNum    },
                        { lbl: qsTr("USERNAME"),  cw: _root._cUser   },
                        { lbl: qsTr("ID"),        cw: _root._cId     },
                        { lbl: qsTr("ROLE"),      cw: _root._cRole   },
                        { lbl: qsTr("그룹"),      cw: _root._cGroup  },
                        { lbl: qsTr("등록일"),    cw: _root._cDate   },
                        { lbl: qsTr("계정 상태"), cw: _root._cStatus },
                        { lbl: qsTr("관리"),      cw: _root._cMgmt   }
                    ]
                    QGCLabel {
                        width:             modelData.cw
                        height:            _root._rowH
                        text:              modelData.lbl
                        font.pointSize:    _root._fPt
                        font.bold:         true
                        color:             qgcPal.text
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // 자산 헤더
            Row {
                anchors.fill:       parent
                anchors.leftMargin: _fW * 0.5
                visible:            _activeTab === 1

                Repeater {
                    model: [
                        { lbl: qsTr("번호"),    cw: _root._cNum    },
                        { lbl: qsTr("이름"),    cw: _root._cUser   },
                        { lbl: qsTr("자산 ID"), cw: _root._cId     },
                        { lbl: qsTr("유형"),    cw: _root._cRole   },
                        { lbl: qsTr("그룹"),    cw: _root._cGroup  },
                        { lbl: qsTr("등록일"),  cw: _root._cDate   },
                        { lbl: qsTr("상태"),    cw: _root._cStatus },
                        { lbl: qsTr("관리"),    cw: _root._cMgmt   }
                    ]
                    QGCLabel {
                        width:             modelData.cw
                        height:            _root._rowH
                        text:              modelData.lbl
                        font.pointSize:    _root._fPt
                        font.bold:         true
                        color:             qgcPal.text
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    // ──────────────────────────────────────────────────────────
    // Table body  (fills space between top section and pagination)
    // ──────────────────────────────────────────────────────────

    // ── 사용자 목록
    ListView {
        id:                   _tableView
        anchors.top:          _topSection.bottom
        anchors.left:         parent.left
        anchors.right:        parent.right
        anchors.bottom:       _paginationRow.top
        anchors.bottomMargin: _margin
        clip:                 true
        visible:              _activeTab === 0
        model:                _userModel

        delegate: Rectangle {
            width:  _tableView.width
            height: _rowH
            color:  index % 2 === 0 ? qgcPal.window : qgcPal.windowShade

            Row {
                anchors.left:           parent.left
                anchors.leftMargin:     _fW * 0.5
                anchors.verticalCenter: parent.verticalCenter

                QGCLabel { width: _cNum;    height: _rowH; text: ((_currentPage - 1) * _pageSize) + index + 1; font.pointSize: _fPt; color: qgcPal.text; verticalAlignment: Text.AlignVCenter }
                QGCLabel { width: _cUser;   height: _rowH; text: username; font.pointSize: _fPt; color: qgcPal.text; verticalAlignment: Text.AlignVCenter }
                QGCLabel { width: _cId;     height: _rowH; text: userId;   font.pointSize: _fPt; color: qgcPal.text; verticalAlignment: Text.AlignVCenter }
                QGCLabel { width: _cRole;   height: _rowH; text: role;     font.pointSize: _fPt; color: qgcPal.text; verticalAlignment: Text.AlignVCenter }
                QGCLabel { width: _cGroup;  height: _rowH; text: grp;      font.pointSize: _fPt; color: qgcPal.text; verticalAlignment: Text.AlignVCenter }
                QGCLabel { width: _cDate;   height: _rowH; text: regDate;  font.pointSize: _fPt; color: qgcPal.text; verticalAlignment: Text.AlignVCenter }

                QGCLabel {
                    width:             _cStatus
                    height:            _rowH
                    text:              status
                    font.pointSize:    _fPt
                    color:             status === "잠금" ? "#FFA500" : qgcPal.text
                    verticalAlignment: Text.AlignVCenter
                }

                // 관리: 수정 / 삭제
                Row {
                    width:   _cMgmt
                    height:  _rowH
                    spacing: _fW * 0.5
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width:  _editLabel.implicitWidth + _fW * 1.4
                        height: _fH * 1.6
                        radius: 2
                        color:  _editMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                        QGCLabel {
                            id:               _editLabel
                            anchors.centerIn: parent
                            text:             qsTr("수정")
                            font.pointSize:   _fPt
                            color:            qgcPal.text
                        }
                        MouseArea {
                            id:           _editMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    _root.requestUserEdit(username)
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width:  _deleteLabel.implicitWidth + _fW * 1.4
                        height: _fH * 1.6
                        radius: 2
                        color:  _deleteMa.containsMouse ? Qt.rgba(0.75, 0.12, 0.12, 0.22) : "transparent"

                        QGCLabel {
                            id:               _deleteLabel
                            anchors.centerIn: parent
                            text:             qsTr("삭제")
                            font.pointSize:   _fPt
                            color:            qgcPal.colorRed
                        }
                        MouseArea {
                            id:           _deleteMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    {}
                        }
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width:          parent.width
                height:         1
                color:          qgcPal.windowShade
            }
        }
    }

    // ── 자산 목록
    ListView {
        id:                   _assetTableView
        anchors.top:          _topSection.bottom
        anchors.left:         parent.left
        anchors.right:        parent.right
        anchors.bottom:       _paginationRow.top
        anchors.bottomMargin: _margin
        clip:                 true
        visible:              _activeTab === 1
        model:                _assetModel

        delegate: Rectangle {
            width:  _assetTableView.width
            height: _rowH
            color:  index % 2 === 0 ? qgcPal.window : qgcPal.windowShade

            Row {
                anchors.left:           parent.left
                anchors.leftMargin:     _fW * 0.5
                anchors.verticalCenter: parent.verticalCenter

                QGCLabel { width: _cNum;    height: _rowH; text: ((_currentPage - 1) * _pageSize) + index + 1; font.pointSize: _fPt; color: qgcPal.text; verticalAlignment: Text.AlignVCenter }
                QGCLabel { width: _cUser;   height: _rowH; text: assetName; font.pointSize: _fPt; color: qgcPal.text; verticalAlignment: Text.AlignVCenter }
                QGCLabel { width: _cId;     height: _rowH; text: assetId;   font.pointSize: _fPt; color: qgcPal.text; verticalAlignment: Text.AlignVCenter }
                QGCLabel { width: _cRole;   height: _rowH; text: assetType; font.pointSize: _fPt; color: qgcPal.text; verticalAlignment: Text.AlignVCenter }
                QGCLabel { width: _cGroup;  height: _rowH; text: grp;       font.pointSize: _fPt; color: qgcPal.text; verticalAlignment: Text.AlignVCenter }
                QGCLabel { width: _cDate;   height: _rowH; text: regDate;   font.pointSize: _fPt; color: qgcPal.text; verticalAlignment: Text.AlignVCenter }

                QGCLabel {
                    width:             _cStatus
                    height:            _rowH
                    text:              status
                    font.pointSize:    _fPt
                    color:             status === "잠금" ? "#FFA500" : qgcPal.text
                    verticalAlignment: Text.AlignVCenter
                }

                // 관리: 수정 / 삭제
                Row {
                    width:   _cMgmt
                    height:  _rowH
                    spacing: _fW * 0.5
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width:  _aEditLabel.implicitWidth + _fW * 1.4
                        height: _fH * 1.6
                        radius: 2
                        color:  _aEditMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                        QGCLabel {
                            id:               _aEditLabel
                            anchors.centerIn: parent
                            text:             qsTr("수정")
                            font.pointSize:   _fPt
                            color:            qgcPal.text
                        }
                        MouseArea {
                            id:           _aEditMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    _root.requestAssetEdit(assetName)
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width:  _aDeleteLabel.implicitWidth + _fW * 1.4
                        height: _fH * 1.6
                        radius: 2
                        color:  _aDeleteMa.containsMouse ? Qt.rgba(0.75, 0.12, 0.12, 0.22) : "transparent"

                        QGCLabel {
                            id:               _aDeleteLabel
                            anchors.centerIn: parent
                            text:             qsTr("삭제")
                            font.pointSize:   _fPt
                            color:            qgcPal.colorRed
                        }
                        MouseArea {
                            id:           _aDeleteMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    {}
                        }
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width:          parent.width
                height:         1
                color:          qgcPal.windowShade
            }
        }
    }

    // ──────────────────────────────────────────────────────────
    // Pagination  (동적 페이지 버튼)
    // ──────────────────────────────────────────────────────────
    Row {
        id:                       _paginationRow
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     _margin
        anchors.horizontalCenter: parent.horizontalCenter
        spacing:                  _fW * 0.5

        Repeater {
            model: _pageButtons

            Rectangle {
                width:        _fH * 1.8
                height:       _fH * 1.8
                radius:       3
                color:        modelData === String(_currentPage) ? qgcPal.primaryButton : qgcPal.windowShade
                border.color: qgcPal.windowShadeDark
                border.width: 1

                QGCLabel {
                    anchors.centerIn: parent
                    text:             modelData
                    font.pointSize:   _fPt
                    color:            modelData === String(_currentPage) ? qgcPal.primaryButtonText : qgcPal.text
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked:    _goPage(modelData)
                }
            }
        }
    }
}
