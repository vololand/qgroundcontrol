/****************************************************************************
 *
 * QGroundControl Open Source Ground Control Station
 *
 * 사용자 수정 페이지
 * 트리거:
 *   - 좌측 트리 user 노드 우클릭 → 사용자 수정
 *   - 우측 사용자 목록 "수정" 버튼
 *
 * 구성:
 *   상단: 사용자 정보 폼 (사용자명·ID·휴대폰·비밀번호·그룹·ROLE·계정상태)
 *   하단: 그룹 / 자산 권한 설정 테이블 (V/C/A 토글)
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
    id:           _root
    anchors.fill: parent

    signal accepted()
    signal cancelled()

    // ManagementView가 onLoaded에서 주입
    // TODO: 서버 연동 시 각 property에 실제 데이터 바인딩
    property string initUserName:      ""
    property string initPhone:         ""
    property string initRole:          ""
    property string initAccountStatus: ""
    property var    groupModel:        []
    // TODO: 서버에서 수신한 그룹/자산 권한 데이터로 교체
    property var    groupPermModel:    []
    property var    assetPermModel:    []

    // ── ID 중복체크 잠금 상태 (수정 페이지: 원본 ID 동일 시 잠금 유지)
    property bool   _idLocked: false
    property string _origId:   ""     // 페이지 열릴 때 저장된 원본 ID

    onInitUserNameChanged: _usernameField.text = initUserName

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    readonly property real _fPt:    ScreenTools.defaultFontPointSize
    readonly property real _fH:     ScreenTools.defaultFontPixelHeight
    readonly property real _fW:     ScreenTools.defaultFontPixelWidth
    readonly property real _margin: _fH * 0.75

    // ── 권한 더미 데이터
    // 수정 페이지는 좌측 트리에 있는 모든 그룹을 표시한다.
    // org는 기본적으로 View 권한을 가진다.
    // perm 비트 구조: bit0=View(1), bit1=Control(2), bit2=Admin(4)
    //   예) perm:3 → View+Control 권한 보유, perm:7 → 모든 권한 보유
    // hasPermRow: true=권한 관리 행 존재, false=권한 관리 행이 없는 항목(권한 관리 추가 필요)
    // TODO: 서버에서 해당 사용자의 그룹/자산 권한 데이터를 각각 수신하여 모델에 바인딩
    ListModel {
        id: _groupPermModel
        ListElement { itemName: "VOLOLAND";                         perm: 1; hasPermRow: true  }
        ListElement { itemName: "미래항공모빌리티연구소";             perm: 3; hasPermRow: true  }
        ListElement { itemName: "볼로 무인기 & 지상 플랫폼 그룹";     perm: 7; hasPermRow: true  }
        ListElement { itemName: "볼로 자율비행플랫폼 그룹";           perm: 0; hasPermRow: true  }
        ListElement { itemName: "개인사용자";                        perm: 0; hasPermRow: false }
    }
    ListModel {
        id: _assetPermModel
        ListElement { itemName: "A-1";   perm: 3; hasPermRow: true  }
        ListElement { itemName: "B-1";   perm: 1; hasPermRow: true  }
        ListElement { itemName: "VLS-770C"; perm: 0; hasPermRow: false }
        ListElement { itemName: "VLS-400C"; perm: 1; hasPermRow: true }
        ListElement { itemName: "THEO-3"; perm: 0; hasPermRow: false }
    }

    // ── 반투명 오버레이
    Rectangle {
        anchors.fill: parent
        color:        Qt.rgba(0, 0, 0, 0.5)
        MouseArea { anchors.fill: parent }
    }

    // ── 공용 알림 팝업
    Rectangle {
        id:               _alertPopup
        anchors.centerIn: _dialog
        visible:          false
        width:            _fW * 42
        height:           _fH * 9
        color:            qgcPal.window
        radius:           6
        z:                20
        border.color:     qgcPal.windowShadeDark
        border.width:     1

        property string message: ""

        Rectangle {
            anchors.fill:  _dialog
            color:         Qt.rgba(0, 0, 0, 0.35)
            z:             -1
            visible:       _alertPopup.visible
        }

        Column {
            anchors.centerIn: parent
            spacing:          _fH * 0.9

            QGCLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                text:                     _alertPopup.message
                font.pointSize:           _fPt
                color:                    qgcPal.text
            }

            QGCButton {
                anchors.horizontalCenter: parent.horizontalCenter
                text:                     qsTr("확인")
                onClicked:                _alertPopup.visible = false
            }
        }
    }

    function _showAlert(msg) {
        _alertPopup.message = msg
        _alertPopup.visible = true
    }

    // ── 권한 관리 제거 확인 팝업
    Rectangle {
        id:               _removePermConfirmPopup
        anchors.centerIn: _dialog
        visible:          false
        width:            _fW * 48
        height:           _fH * 10
        color:            qgcPal.window
        radius:           6
        z:                20
        border.color:     qgcPal.windowShadeDark
        border.width:     1

        property string targetName: ""
        property int    targetIndex: -1
        property var    targetModel: null

        Rectangle {
            anchors.fill:  _dialog
            color:         Qt.rgba(0, 0, 0, 0.35)
            z:             -1
            visible:       _removePermConfirmPopup.visible
        }

        Column {
            anchors.centerIn: parent
            spacing:          _fH * 1.0

            QGCLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                text:                     qsTr("\"%1\"에 대한 권한 관리 설정을 제거하겠습니까?").arg(_removePermConfirmPopup.targetName)
                font.pointSize:           _fPt
                color:                    qgcPal.text
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing:                  _fW

                QGCButton {
                    text: qsTr("취소")
                    onClicked: _removePermConfirmPopup.visible = false
                }

                QGCButton {
                    text: qsTr("확인")
                    onClicked: {
                        if (_removePermConfirmPopup.targetModel &&
                                _removePermConfirmPopup.targetIndex >= 0 &&
                                _removePermConfirmPopup.targetModel.setProperty) {
                            // TODO: 서버 권한 관리 제거 API 호출 후 성공 시 hasPermRow/perm 갱신
                            _removePermConfirmPopup.targetModel.setProperty(_removePermConfirmPopup.targetIndex, "hasPermRow", false)
                            _removePermConfirmPopup.targetModel.setProperty(_removePermConfirmPopup.targetIndex, "perm", 0)
                        }
                        _removePermConfirmPopup.visible = false
                    }
                }
            }
        }
    }

    function _showRemovePermConfirm(targetModel, targetIndex, targetName) {
        _removePermConfirmPopup.targetModel = targetModel
        _removePermConfirmPopup.targetIndex = targetIndex
        _removePermConfirmPopup.targetName = targetName
        _removePermConfirmPopup.visible = true
    }

    // ── 그룹/자산 권한 테이블 공통 UI
    component PermissionTable: Rectangle {
        id: _table

        property alias model: _permRows.model
        property string nameHeader: ""
        property bool editable: true

        color:        "transparent"
        border.color: qgcPal.windowShadeDark
        border.width: 1
        clip:         true

        readonly property real _leftW: (width - 2) * 0.38

        Row {
            id:     _permHeader
            x:      1
            y:      1
            width:  parent.width - 2
            height: _root._fH * 2.0

            Rectangle {
                width:  _table._leftW
                height: parent.height
                color:  qgcPal.windowShade
                QGCLabel {
                    anchors.centerIn: parent
                    text:             _table.nameHeader
                    font.pointSize:   _root._fPt
                    font.bold:        true
                    color:            qgcPal.text
                }
            }
            Rectangle { width: 1; height: parent.height; color: qgcPal.windowShadeDark }
            Rectangle {
                width:  parent.width - _table._leftW - 1
                height: parent.height
                color:  qgcPal.windowShade
                QGCLabel {
                    anchors.centerIn: parent
                    text:             qsTr("권한 설정")
                    font.pointSize:   _root._fPt
                    font.bold:        true
                    color:            qgcPal.text
                }
            }
        }

        Rectangle {
            id:     _permHeaderDiv
            x:      1
            y:      _permHeader.height + 1
            width:  parent.width - 2
            height: 1
            color:  qgcPal.windowShadeDark
        }

        Flickable {
            anchors.top:    _permHeaderDiv.bottom
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin:  1
            anchors.rightMargin: 1
            clip:          true
            contentWidth:  width
            contentHeight: _permData.implicitHeight

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id:    _permData
                width: parent.width

                Repeater {
                    id: _permRows

                    Item {
                        width:  _permData.width
                        height: _root._fH * 2.4

                        Row {
                            anchors.fill: parent

                            Item {
                                width:  _table._leftW
                                height: parent.height

                                QGCLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left:           parent.left
                                    anchors.leftMargin:     _root._fW * 0.8
                                    text:                   itemName
                                    font.pointSize:         _root._fPt
                                    color:                  qgcPal.text
                                    elide:                  Text.ElideRight
                                    width:                  parent.width - _root._fW * 3.2
                                }

                                QGCLabel {
                                    visible:        hasPermRow
                                    anchors.top:    parent.top
                                    anchors.right:  parent.right
                                    anchors.margins: _root._fW * 0.35
                                    text:           "x"
                                    font.pointSize: _root._fPt * 0.85
                                    font.bold:      true
                                    color:          "#F44336"

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape:  Qt.PointingHandCursor
                                        onClicked:    _root._showRemovePermConfirm(_permRows.model, index, itemName)
                                    }
                                }
                            }

                            Rectangle { width: 1; height: parent.height; color: qgcPal.windowShadeDark }

                            Item {
                                width:  _permData.width - _table._leftW - 1
                                height: parent.height

                                Row {
                                    visible:                hasPermRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left:           parent.left
                                    anchors.leftMargin:     _root._fW * 0.6
                                    spacing:                _root._fW * 0.45

                                    Repeater {
                                        // 파란색(활성) = 권한 보유 → 클릭 시 권한 제거
                                        // 회색(비활성) = 권한 없음  → 클릭 시 권한 부여
                                        // TODO: 클릭 시 서버 권한 변경 API 호출 (grant / revoke)
                                        model: [ { label: qsTr("View"),    bit: 1 },
                                                 { label: qsTr("Control"), bit: 2 },
                                                 { label: qsTr("Admin"),   bit: 4 } ]

                                        Rectangle {
                                            id:     _permBox
                                            width:  _root._fW * 5.8
                                            height: _root._fH * 1.5
                                            radius: 3

                                            property bool _active: (perm & modelData.bit) !== 0

                                            color:        _active ? "#1a6bbf" : "transparent"
                                            border.color: _active ? "#1a6bbf" : "#666666"
                                            border.width: 1

                                            QGCLabel {
                                                anchors.centerIn: parent
                                                text:             modelData.label
                                                font.pointSize:   _root._fPt * 0.78
                                                font.bold:        _permBox._active
                                                color:            _permBox._active ? "#ffffff" : "#aaaaaa"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                enabled:      _table.editable
                                                cursorShape:  enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked:    _permBox._active = !_permBox._active
                                            }
                                        }
                                    }
                                }

                                QGCButton {
                                    visible:                !hasPermRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left:           parent.left
                                    anchors.leftMargin:     _root._fW * 0.6
                                    text:                   qsTr("권한 관리 추가")

                                    onClicked: {
                                        // TODO: 서버 권한 관리 추가 API 호출 후 성공 시 hasPermRow/perm 갱신
                                        if (_permRows.model && _permRows.model.setProperty) {
                                            _permRows.model.setProperty(index, "hasPermRow", true)
                                            _permRows.model.setProperty(index, "perm", 0)
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible:        index < _permRows.count - 1
                            anchors.bottom: parent.bottom
                            width:          parent.width
                            height:         1
                            color:          qgcPal.windowShadeDark
                        }
                    }
                }
            }
        }
    }

    // ── 다이얼로그 본체
    Rectangle {
        id:               _dialog
        anchors.centerIn: parent
        width:            _fW * 72
        height:           _fH * 28
        color:            qgcPal.window
        radius:           4

        // ── 타이틀 바
        Rectangle {
            id:     _titleBar
            width:  parent.width
            height: _fH * 2.5
            color:  qgcPal.windowShade
            radius: 4

            Rectangle {
                anchors.bottom: parent.bottom
                width:          parent.width
                height:         parent.radius
                color:          parent.color
            }

            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left:           parent.left
                anchors.leftMargin:     _margin
                text:                   qsTr("사용자 수정")
                font.pointSize:         _fPt * 1.1
                font.bold:              true
                color:                  qgcPal.text
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right:          parent.right
                anchors.rightMargin:    _margin
                width:                  _fH * 1.8
                height:                 _fH * 1.8

                QGCLabel {
                    anchors.centerIn: parent
                    text:             "✕"
                    font.pointSize:   _fPt * 1.1
                    color:            qgcPal.text
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked:    _root.cancelled()
                }
            }
        }

        // ── 상단 폼 + 버튼 + 하단 권한 트리를 세로로 배치
        ColumnLayout {
            anchors.top:        _titleBar.bottom
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.bottom:     parent.bottom
            anchors.margins:    _margin
            spacing:            _fH * 0.6

            // ── 폼 섹션
            ColumnLayout {
                Layout.fillWidth: true
                spacing:          _fH * 0.8

                // 행 1: 사용자명 | ID + 중복체크
                RowLayout {
                    Layout.fillWidth: true
                    spacing:          _fW * 1.5

                    RowLayout {
                        spacing: _fW

                        QGCLabel {
                            text:                  qsTr("사용자명")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: _fW * 9
                        }
                        QGCTextField {
                            id:                    _usernameField
                            Layout.preferredWidth: _fW * 18
                            text:                  _root.initUserName
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing:          _fW

                        QGCLabel {
                            text:                  qsTr("ID")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: _fW * 10
                        }

                        // ID 입력 필드 (잠금 상태에 따라 배경 불투명도 변경)
                        Rectangle {
                            Layout.fillWidth: true
                            height:           _idField.implicitHeight > 0
                                              ? _idField.implicitHeight : _fH * 1.6
                            color:            _root._idLocked
                                              ? Qt.rgba(1, 1, 1, 0.15)
                                              : qgcPal.windowShade
                            border.color:     qgcPal.windowShadeDark
                            border.width:     1
                            radius:           2
                            opacity:          _root._idLocked ? 0.5 : 1.0

                            QGCTextField {
                                id:            _idField
                                anchors.fill:  parent
                                color:         "white"
                                background:    null
                                // 원본 ID와 같으면 잠금 유지, 다르면 잠금 해제
                                onTextChanged: {
                                    _root._idLocked = (text.trim() === _root._origId.trim()
                                                       && _root._origId.trim().length > 0)
                                }
                                Component.onCompleted: {
                                    // 페이지 열릴 때 원본 ID 저장 및 잠금 상태 초기화
                                    _root._origId   = text
                                    _root._idLocked = (text.trim().length > 0)
                                }
                            }
                        }

                        // 중복체크 기능
                        // TODO: 서버 ID 중복체크 API 호출 → 결과에 따라 _idLocked 결정
                        QGCButton {
                            text:      qsTr("중복 체크")
                            onClicked: {
                                if (_idField.text.trim().length === 0) {
                                    _root._showAlert(qsTr("ID를 입력해주세요."))
                                    return
                                }
                                // [중복체크기능] 현재 서버 미연결 → 항상 사용 가능(잠금) 처리
                                _root._idLocked = true
                            }
                        }
                    }
                }

                // 행 2: 휴대폰 번호 | 계정상태
                RowLayout {
                    Layout.fillWidth: true
                    spacing:          _fW * 1.5

                    RowLayout {
                        spacing: _fW

                        QGCLabel {
                            text:                  qsTr("휴대폰 번호")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: _fW * 9
                        }
                        QGCTextField {
                            id:                    _phoneField
                            Layout.preferredWidth: _fW * 18
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing:          _fW

                        QGCLabel {
                            text:                  qsTr("계정상태")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: _fW * 10
                        }
                        QGCComboBox {
                            id:               _statusCombo
                            Layout.fillWidth: true
                            model:            [ qsTr("활성화"), qsTr("잠금") ]
                        }
                    }
                }

                // 행 3: 비밀번호 | 비밀번호 확인
                RowLayout {
                    Layout.fillWidth: true
                    spacing:          _fW * 1.5

                    RowLayout {
                        spacing: _fW

                        QGCLabel {
                            text:                  qsTr("비밀번호")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: _fW * 9
                        }
                        QGCTextField {
                            id:                    _pwField
                            Layout.preferredWidth: _fW * 18
                            echoMode:              TextInput.Password
                            placeholderText:       qsTr("선택입력 / 비워두면 기존 유지")
                        }
                    }

                    // 비밀번호 확인 + 일치 여부 피드백 (입력창 아래 정렬)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing:          _fW

                        QGCLabel {
                            text:                  qsTr("비밀번호 확인")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: _fW * 10
                            Layout.alignment:      Qt.AlignTop
                        }

                        // 입력창 + 피드백 묶음
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing:          _fH * 0.2

                            QGCTextField {
                                id:               _pwConfirmField
                                Layout.fillWidth: true
                                echoMode:         TextInput.Password
                                placeholderText:  qsTr("비밀번호 변경 시 입력")
                            }

                            // 비밀번호 일치 여부 피드백
                            // 둘 다 비어있으면 숨김(선택 입력), 하나라도 입력 시 표시
                            QGCLabel {
                                visible: _pwConfirmField.text.length > 0 || _pwField.text.length > 0
                                Layout.preferredHeight: visible ? implicitHeight : 0
                                text: {
                                    if (_pwField.text.length === 0 && _pwConfirmField.text.length === 0)
                                        return ""
                                    return (_pwConfirmField.text === _pwField.text)
                                           ? qsTr("비밀번호가 같습니다.")
                                           : qsTr("비밀번호가 다릅니다.")
                                }
                                font.pointSize: _fPt * 0.9
                                color: (_pwConfirmField.text === _pwField.text && _pwField.text.length > 0)
                                       ? "#4CAF50" : "#F44336"
                            }
                        }
                    }
                }

                // 행 4: 그룹 | ROLE
                RowLayout {
                    Layout.fillWidth: true
                    spacing:          _fW * 1.5

                    RowLayout {
                        spacing: _fW

                        QGCLabel {
                            text:                  qsTr("그룹")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: _fW * 9
                        }
                        QGCComboBox {
                            id:                    _groupCombo
                            Layout.preferredWidth: _fW * 18
                            model:                 _root.groupModel
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing:          _fW

                        QGCLabel {
                            text:                  qsTr("ROLE")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: _fW * 10
                        }

                        // ROLE 선택 콤보
                        // TODO: 로그인한 계정의 권한 레벨에 따라 부여 가능한 ROLE 목록을 제한
                        //       예) SUPER_ADMIN 계정 → 모든 ROLE 부여 가능
                        //           GROUP_ADMIN  계정 → GROUP_ADMIN, USER 만 부여 가능
                        //           USER         계정 → 사용자 수정 권한 없음
                        QGCComboBox {
                            id:               _roleCombo
                            Layout.fillWidth: true
                            model:            [ "SUPER_ADMIN", "GROUP_ADMIN", "USER" ]
                        }
                    }
                }
            }

            // ── 수정 / 취소 버튼 (폼 바로 아래, 권한 섹션 위)
            Row {
                Layout.alignment: Qt.AlignRight
                spacing:          _fW

                QGCButton {
                    text:      qsTr("수정")
                    onClicked: {
                        // ID가 변경됐는데 중복체크를 안 한 경우
                        if (!_root._idLocked) {
                            _root._showAlert(qsTr("ID 중복체크를 먼저 진행해주세요."))
                            return
                        }
                        // 비밀번호를 하나만 입력한 경우
                        if (_pwField.text.length > 0 && _pwConfirmField.text.length === 0) {
                            _root._showAlert(qsTr("비밀번호 확인을 입력해주세요."))
                            return
                        }
                        if (_pwField.text.length === 0 && _pwConfirmField.text.length > 0) {
                            _root._showAlert(qsTr("비밀번호를 입력해주세요."))
                            return
                        }
                        // 비밀번호 불일치
                        if (_pwField.text.length > 0 && _pwField.text !== _pwConfirmField.text) {
                            _root._showAlert(qsTr("비밀번호가 일치하지 않습니다."))
                            return
                        }
                        // [사용자수정] 현재 서버 미연결 → 클라이언트 측에서 accepted 신호만 발송
                        // TODO: 서버 사용자수정 API 호출 후 성공 시 accepted() 처리
                        _root.accepted()
                    }
                }
                QGCButton {
                    text:      qsTr("취소")
                    onClicked: _root.cancelled()
                }
            }

            // ── 섹션 구분선
            Rectangle {
                Layout.fillWidth: true
                height:           1
                color:            qgcPal.windowShadeDark
            }

            // ── 권한 설정 테이블
            // 그룹과 자산을 분리 표시해 서버 프로토콜의 그룹/자산 권한 구조와 맞춘다.
            RowLayout {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                spacing:           _fW

                ColumnLayout {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    spacing:           _fH * 0.35

                    QGCLabel {
                        text:           qsTr("그룹 권한")
                        font.pointSize: _root._fPt
                        font.bold:      true
                        color:          qgcPal.text
                    }

                    PermissionTable {
                        Layout.fillWidth:  true
                        Layout.fillHeight: true
                        nameHeader:        qsTr("그룹")
                        model:             _groupPermModel
                        editable:          true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    spacing:           _fH * 0.35

                    QGCLabel {
                        text:           qsTr("자산 권한")
                        font.pointSize: _root._fPt
                        font.bold:      true
                        color:          qgcPal.text
                    }

                    PermissionTable {
                        Layout.fillWidth:  true
                        Layout.fillHeight: true
                        nameHeader:        qsTr("자산")
                        model:             _assetPermModel
                        editable:          true
                    }
                }
            }
        }
    }
}
