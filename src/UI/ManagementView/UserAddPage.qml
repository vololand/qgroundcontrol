/****************************************************************************
 *
 * QGroundControl Open Source Ground Control Station
 *
 * 사용자 등록 페이지
 * 트리거:
 *   - 우측 패널 "신규 등록" 버튼
 *   - 좌측 트리 userMgmt 노드 우클릭 → 사용자 등록
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

    // ManagementView가 onLoaded에서 주입 — 그룹 콤보 목록
    property var groupModel: []

    // ── ID 중복체크 잠금 상태 (true = 중복체크 완료, 등록 가능)
    property bool _idLocked: false

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    readonly property real _fPt:    ScreenTools.defaultFontPointSize
    readonly property real _fH:     ScreenTools.defaultFontPixelHeight
    readonly property real _fW:     ScreenTools.defaultFontPixelWidth
    readonly property real _margin: _fH * 0.75

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

    // ── 다이얼로그 본체
    Rectangle {
        id:               _dialog
        anchors.centerIn: parent
        width:            _fW * 72
        height:           _fH * 18
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
                text:                   qsTr("사용자 등록")
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
                anchors.top:   parent.top
                anchors.left:  parent.left
                anchors.right: parent.right
                spacing:       _fH * 0.8

                // ── 행 1: 사용자명 | ID + 중복체크
                RowLayout {
                    Layout.fillWidth: true
                    spacing:          _fW * 1.5

                    // 왼쪽: 사용자명
                    RowLayout {
                        spacing: _fW

                        QGCLabel {
                            text:                  qsTr("사용자명 *")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: _fW * 9
                        }

                        QGCTextField {
                            id:                    _usernameField
                            Layout.preferredWidth: _fW * 18
                            placeholderText:       ""
                        }
                    }

                    // 오른쪽: ID + 중복체크
                    RowLayout {
                        Layout.fillWidth: true
                        spacing:          _fW

                        QGCLabel {
                            text:                  qsTr("ID *")
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
                                // ID 변경 시 잠금 해제
                                onTextChanged: _root._idLocked = false
                            }
                        }

                        // 중복체크 기능
                        // TODO: 서버 ID 중복체크 API 호출 → 결과에 따라 _idLocked 결정
                        QGCButton {
                            text:      qsTr("중복체크")
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

                // ── 행 2: 휴대폰 번호 (단독 행)
                RowLayout {
                    Layout.fillWidth: true
                    spacing:          _fW

                    QGCLabel {
                        text:                  qsTr("휴대폰 번호")
                        font.pointSize:        _fPt
                        color:                 qgcPal.text
                        Layout.preferredWidth: _fW * 9
                    }

                    QGCTextField {
                        id:                    _phoneField
                        Layout.preferredWidth: _fW * 18
                        placeholderText:       ""
                    }
                }

                // ── 행 3: 비밀번호 | 비밀번호 확인 + 일치 여부 표시
                RowLayout {
                    Layout.fillWidth: true
                    spacing:          _fW * 1.5

                    RowLayout {
                        spacing: _fW

                        QGCLabel {
                            text:                  qsTr("비밀번호 *")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: _fW * 9
                        }

                        QGCTextField {
                            id:                    _pwField
                            Layout.preferredWidth: _fW * 18
                            echoMode:              TextInput.Password
                            placeholderText:       ""
                        }
                    }

                    // 비밀번호 확인 + 일치 여부 피드백 (입력창 아래에만 위치)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing:          _fW

                        QGCLabel {
                            text:                  qsTr("비밀번호 확인 *")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: _fW * 10
                            Layout.alignment:      Qt.AlignTop
                        }

                        // 입력창 + 피드백 묶음 (피드백이 입력창 바로 아래 정렬)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing:          _fH * 0.2

                            QGCTextField {
                                id:               _pwConfirmField
                                Layout.fillWidth: true
                                echoMode:         TextInput.Password
                                placeholderText:  ""
                            }

                            // 비밀번호 일치 여부 피드백 (숨김 시 공간 제거)
                            QGCLabel {
                                visible:                _pwConfirmField.text.length > 0
                                Layout.preferredHeight: visible ? implicitHeight : 0
                                text:                   (_pwConfirmField.text === _pwField.text)
                                                        ? qsTr("비밀번호가 같습니다.")
                                                        : qsTr("비밀번호가 다릅니다.")
                                font.pointSize:         _fPt * 0.9
                                color:                  (_pwConfirmField.text === _pwField.text)
                                                        ? "#4CAF50" : "#F44336"
                            }
                        }
                    }
                }

                // ── 행 4: 그룹 | ROLE
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
                        //           USER         계정 → 사용자 등록 권한 없음
                        QGCComboBox {
                            id:               _roleCombo
                            Layout.fillWidth: true
                            model:            [
                                qsTr("SUPER_ADMIN"),
                                qsTr("GROUP_ADMIN"),
                                qsTr("USER")
                            ]
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
                text:      qsTr("등록")
                onClicked: {
                    // ── 필수 항목(*) 공백 검증
                    if (_usernameField.text.trim().length === 0) {
                        _root._showAlert(qsTr("사용자명을 입력해주세요."))
                        return
                    }
                    if (!_root._idLocked) {
                        _root._showAlert(qsTr("ID 중복체크를 먼저 진행해주세요."))
                        return
                    }
                    if (_pwField.text.length === 0) {
                        _root._showAlert(qsTr("비밀번호를 입력해주세요."))
                        return
                    }
                    if (_pwConfirmField.text.length === 0) {
                        _root._showAlert(qsTr("비밀번호 확인을 입력해주세요."))
                        return
                    }
                    // ── 비밀번호 일치 검증
                    if (_pwField.text !== _pwConfirmField.text) {
                        _root._showAlert(qsTr("비밀번호가 일치하지 않습니다."))
                        return
                    }
                    // [사용자등록] 현재 서버 미연결 → 클라이언트 측에서 accepted 신호만 발송
                    // TODO: 서버 사용자등록 API 호출 후 성공 시 accepted() 처리
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
