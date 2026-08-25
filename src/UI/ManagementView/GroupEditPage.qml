/****************************************************************************
 *
 * QGroundControl Open Source Ground Control Station
 *
 * 그룹 수정 페이지 (우클릭 → 그룹 수정)
 * initGroupName  : 수정 대상 그룹명 (pre-fill)
 * initParentName : 현재 상위 그룹명 (pre-select)
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

    // ManagementView가 onLoaded에서 주입하는 초기값
    // parentGroupModel : 트리에서 추출한 실제 부모 후보 목록 (콤보 모델로 사용)
    // initGroupName    : 수정 대상 그룹명 (텍스트필드 pre-fill)
    // initParentName   : 현재 상위 그룹명 (콤보 pre-select) — 자신보다 1뎁스 높은 노드
    // initNodeType     : "org" 이면 상위 그룹 콤보 잠금
    // initDescription  : 그룹 설명 (TextEdit pre-fill)
    // TODO: 서버 연동 시 각 property에 실제 데이터 바인딩
    property var    parentGroupModel: []
    property string initGroupName:    ""
    property string initParentName:   ""
    property string initNodeType:     ""
    property string initDescription:  ""

    // ── 중복체크 잠금 상태
    // 페이지 열릴 때 기존 이름이 채워지므로 초기값은 true (변경 없으면 체크 불필요)
    // 이름을 수정하면 false로 해제 → 중복체크 후 다시 true
    // 단, 원본 이름과 동일한 값으로 되돌리면 자동으로 true 복구
    property bool   _nameLocked: false
    property string _origName:   ""   // 페이지 열릴 때 저장된 원본 그룹명

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    readonly property real _fPt:    ScreenTools.defaultFontPointSize
    readonly property real _fH:     ScreenTools.defaultFontPixelHeight
    readonly property real _fW:     ScreenTools.defaultFontPixelWidth
    readonly property real _margin: _fH * 0.75

    // parentGroupModel이 먼저 설정된 후 initParentName이 설정되므로
    // onInitParentNameChanged 시점에 모델이 이미 준비되어 있음
    onInitGroupNameChanged: {
        _groupNameField.text = initGroupName
        // 원본 이름 저장 — 이후 동일 여부 비교에 사용
        _root._origName    = initGroupName
        // 기존 이름이 채워지면 잠금 상태로 시작 (이름 변경 없으면 중복체크 불필요)
        _root._nameLocked  = (initGroupName.trim().length > 0)
    }
    onInitParentNameChanged: _setParentComboIndex(initParentName)

    function _setParentComboIndex(name) {
        var m = _root.parentGroupModel
        for (var i = 0; i < m.length; i++) {
            if (m[i] === name) {
                _parentGroupCombo.currentIndex = i
                return
            }
        }
        _parentGroupCombo.currentIndex = 0
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
        width:            _fW * 38
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

    // ── 다이얼로그 본체
    Rectangle {
        id:               _dialog
        anchors.centerIn: parent
        width:            _fW * 70
        height:           _fH * 24
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
                text:                   qsTr("그룹 수정")
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

        // ── 폼 영역
        Item {
            anchors.top:        _titleBar.bottom
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.bottom:     _btnRow.top
            anchors.margins:    _margin

            ColumnLayout {
                anchors.fill: parent
                spacing:      _fH * 0.8

                // ── 행 1: 그룹명 + 중복체크 | 상위 그룹
                RowLayout {
                    Layout.fillWidth: true
                    spacing:          _fW * 1.5

                    RowLayout {
                        spacing: _fW

                        QGCLabel {
                            text:                  qsTr("그룹명 *")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: _fW * 8
                        }

                        // 그룹명 입력 필드 (잠금 상태에 따라 배경 불투명도 변경)
                        Rectangle {
                            Layout.preferredWidth: _fW * 18
                            height:                _groupNameField.implicitHeight > 0
                                                   ? _groupNameField.implicitHeight : _fH * 1.6
                            color:                 _root._nameLocked
                                                   ? Qt.rgba(1, 1, 1, 0.15)
                                                   : qgcPal.windowShade
                            border.color:          qgcPal.windowShadeDark
                            border.width:          1
                            radius:                2
                            opacity:               _root._nameLocked ? 0.5 : 1.0

                            QGCTextField {
                                id:            _groupNameField
                                anchors.fill:  parent
                                color:         "white"
                                background:    null
                                // 원본 이름과 같으면 잠금 유지, 다르면 잠금 해제
                                onTextChanged: {
                                    _root._nameLocked = (text.trim() === _root._origName.trim()
                                                         && _root._origName.trim().length > 0)
                                }
                            }
                        }

                        // 중복체크 기능
                        // TODO: 서버 중복체크 API 호출 → 결과에 따라 _nameLocked 결정
                        QGCButton {
                            text:      qsTr("중복체크")
                            onClicked: {
                                if (_groupNameField.text.trim().length === 0) {
                                    _root._showAlert(qsTr("그룹명을 입력해주세요."))
                                    return
                                }
                                // [중복체크기능] 현재 서버 미연결 → 항상 사용 가능(잠금) 처리
                                _root._nameLocked = true
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing:          _fW

                        QGCLabel {
                            text:                  qsTr("상위 그룹")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: _fW * 9
                        }

                        QGCComboBox {
                            id:               _parentGroupCombo
                            Layout.fillWidth: true
                            enabled:          _root.initNodeType !== "org"
                            opacity:          enabled ? 1.0 : 0.4
                            model:            _root.parentGroupModel
                        }
                    }
                }

                // ── 행 2: 설명
                RowLayout {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    spacing:           _fW

                    QGCLabel {
                        text:                  qsTr("설명")
                        font.pointSize:        _fPt
                        color:                 qgcPal.text
                        Layout.preferredWidth: _fW * 8
                        Layout.alignment:      Qt.AlignTop
                    }

                    Rectangle {
                        Layout.fillWidth:  true
                        Layout.fillHeight: true
                        color:             qgcPal.windowShade
                        border.color:      qgcPal.windowShadeDark
                        border.width:      1
                        radius:            2

                        TextEdit {
                            id:              _descEdit
                            anchors.fill:    parent
                            anchors.margins: _fW * 0.5
                            color:           qgcPal.text
                            font.pointSize:  _fPt
                            wrapMode:        TextEdit.Wrap
                            selectByMouse:   true
                            text:            _root.initDescription
                        }
                    }
                }
            }
        }

        // ── 하단 버튼 행
        Row {
            id:                   _btnRow
            anchors.right:        parent.right
            anchors.bottom:       parent.bottom
            anchors.rightMargin:  _margin
            anchors.bottomMargin: _margin
            spacing:              _fW

            QGCButton {
                text:      qsTr("수정")
                onClicked: {
                    // 중복체크가 완료(잠김)되어 있을 때만 수정 진행
                    if (!_root._nameLocked) {
                        _root._showAlert(qsTr("중복체크를 먼저 진행해주세요."))
                        return
                    }
                    // [그룹수정] 현재 서버 미연결 → 클라이언트 측에서 accepted 신호만 발송
                    // TODO: 서버 그룹수정 API 호출 후 성공 시 accepted() 처리
                    _root.accepted()
                }
            }

            QGCButton {
                text:      qsTr("취소")
                onClicked: _root.cancelled()
            }
        }
    }
}
