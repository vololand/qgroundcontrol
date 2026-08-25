/****************************************************************************
 *
 * QGroundControl Open Source Ground Control Station
 *
 * 그룹 등록 다이얼로그
 * 사용: parent에 overlay 형태로 올려서 사용
 *       visible 바인딩 또는 Loader로 열고 닫기
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
    // parentGroupModel : 트리에서 추출한 실제 부모 후보 목록 (콤보 모델로 사용)
    // presetParentName : 우클릭 대상 → 콤보에서 자동 선택
    property var    parentGroupModel: []
    property string presetParentName: ""

    // ── 중복체크 잠금 상태 (true = 중복체크 완료, 등록 가능)
    property bool _nameLocked: false

    // parentGroupModel이 먼저 설정된 후 presetParentName이 설정되므로
    // onPresetParentNameChanged 시점에 모델이 이미 준비되어 있음
    onPresetParentNameChanged: _applyPresetParent()

    function _applyPresetParent() {
        // 콤보 모델: index 0 = "신규 그룹 생성", index 1~ = parentGroupModel 항목
        // presetParentName이 빈 문자열(하단 버튼)이면 index 0으로 복귀
        if (presetParentName === "") {
            _parentGroupCombo.currentIndex = 0
            return
        }
        var m = _root.parentGroupModel
        for (var i = 0; i < m.length; i++) {
            if (m[i] === presetParentName) {
                _parentGroupCombo.currentIndex = i + 1  // +1: "신규 그룹 생성" 오프셋
                return
            }
        }
        _parentGroupCombo.currentIndex = 0
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    readonly property real _fPt:    ScreenTools.defaultFontPointSize
    readonly property real _fH:     ScreenTools.defaultFontPixelHeight
    readonly property real _fW:     ScreenTools.defaultFontPixelWidth
    readonly property real _margin: _fH * 0.75

    // ── 뒷배경 반투명 오버레이 (클릭 차단)
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

        // 팝업 뒤 어둡게
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
        id:             _dialog
        anchors.centerIn: parent
        width:          _fW  * 70
        height:         _fH  * 24
        color:          qgcPal.window
        radius:         4

        // ── 타이틀 바
        Rectangle {
            id:     _titleBar
            width:  parent.width
            height: _fH * 2.5
            color:  qgcPal.windowShade
            radius: 4

            // 하단 라운드 제거 (상단만 라운드)
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
                text:                   qsTr("그룹 등록")
                font.pointSize:         _fPt * 1.1
                font.bold:              true
                color:                  qgcPal.text
            }

            // X 닫기 버튼
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

                    // 왼쪽: 그룹명
                    RowLayout {
                        spacing: _fW

                        QGCLabel {
                            text:           qsTr("그룹명 *")
                            font.pointSize: _fPt
                            color:          qgcPal.text
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
                                id:              _groupNameField
                                anchors.fill:    parent
                                placeholderText: ""
                                color:           "white"
                                background:      null
                                // 그룹명 변경 시 잠금 해제
                                onTextChanged:   _root._nameLocked = false
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

                    // 오른쪽: 상위 그룹
                    RowLayout {
                        Layout.fillWidth: true
                        spacing:          _fW

                        QGCLabel {
                            text:           qsTr("상위 그룹")
                            font.pointSize: _fPt
                            color:          qgcPal.text
                            Layout.preferredWidth: _fW * 9
                        }

                        QGCComboBox {
                            id:               _parentGroupCombo
                            Layout.fillWidth: true
                            // "신규 그룹 생성"을 항상 첫 번째 항목으로 고정
                            model:            [qsTr("신규 그룹 생성")].concat(_root.parentGroupModel)
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
                            id:               _descField
                            anchors.fill:     parent
                            anchors.margins:  _fW * 0.5
                            color:            qgcPal.text
                            font.pointSize:   _fPt
                            wrapMode:         TextEdit.Wrap
                            selectByMouse:    true
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
                    // 중복체크가 완료(잠김)되어 있을 때만 등록 진행
                    if (!_root._nameLocked) {
                        // 미잠금 상태: 중복체크 요청 팝업 표시
                        _root._showAlert(qsTr("중복체크를 먼저 진행해주세요."))
                        return
                    }
                    // [그룹등록] 현재 서버 미연결 → 클라이언트 측에서 accepted 신호만 발송
                    // TODO: 서버 그룹등록 API 호출 후 성공 시 accepted() 처리
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
