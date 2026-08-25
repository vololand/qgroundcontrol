/****************************************************************************
 *
 * QGroundControl Open Source Ground Control Station
 *
 * 자산 수정 페이지
 * 트리거:
 *   - 우측 패널 자산 탭 "수정" 버튼
 *   - 좌측 트리 asset 노드 우클릭 → 자산 수정
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
    property var    groupModel:     []
    property string initAssetName:  ""
    property string initGroupName:  ""
    property int    initAssetType:  0    // 0=드론, 1=스테이션
    property int    initCategory:   0    // 자산 타입에 따른 유형 인덱스
    property string initRtspUrl:    ""
    property string initWidth:      ""
    property string initDepth:      ""
    property string initHeight:     ""
    property int    initStatus:     0    // 0=사용중, 1=미사용, 2=점검중
    property string initDesc:       ""

    // ── 자산명 중복체크 잠금 상태 (수정 페이지: 원본 이름 동일 시 잠금 유지)
    property bool   _nameLocked: false
    property string _origName:   ""     // 페이지 열릴 때 저장된 원본 자산명

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    readonly property real _fPt:    ScreenTools.defaultFontPointSize
    readonly property real _fH:     ScreenTools.defaultFontPixelHeight
    readonly property real _fW:     ScreenTools.defaultFontPixelWidth
    readonly property real _margin: _fH * 0.75
    readonly property real _lblW:   _fW * 9

    // groupModel 주입 후 initGroupName으로 콤보 인덱스 설정
    function _applyInitGroup() {
        if (_root.initGroupName === "") {
            _groupCombo.currentIndex = 0
            return
        }
        for (var i = 0; i < _root.groupModel.length; i++) {
            if (_root.groupModel[i] === _root.initGroupName) {
                _groupCombo.currentIndex = i
                return
            }
        }
        _groupCombo.currentIndex = 0
    }

    onGroupModelChanged:    Qt.callLater(_applyInitGroup)
    onInitGroupNameChanged: Qt.callLater(_applyInitGroup)

    onInitAssetNameChanged: {
        _assetNameField.text = initAssetName
        // 원본 이름 저장 및 잠금 상태 초기화
        _root._origName   = initAssetName
        _root._nameLocked = (initAssetName.trim().length > 0)
    }
    onInitAssetTypeChanged: _assetTypeCombo.currentIndex = initAssetType
    onInitCategoryChanged:  Qt.callLater(function() { _typeCombo.currentIndex = initCategory })
    onInitStatusChanged:    _statusCombo.currentIndex = initStatus
    onInitDescChanged:      _descField.text = initDesc

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
        width:            _fW * 84
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
                text:                   qsTr("자산 수정")
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
            id:              _formArea
            anchors.top:     _titleBar.bottom
            anchors.left:    parent.left
            anchors.right:   parent.right
            anchors.bottom:  _bottomArea.top
            anchors.margins: _margin

            ColumnLayout {
                anchors.fill: parent
                spacing:      _fH * 0.9

                // ── 상단: 좌/우 반반 필드 (50% 분할)
                Item {
                    Layout.fillWidth: true
                    height: Math.max(_leftTopCol.implicitHeight, _rightTopCol.implicitHeight)

                    readonly property real _gap: _fW * 1.25

                    // 왼쪽 컬럼
                    ColumnLayout {
                        id:                  _leftTopCol
                        anchors.left:        parent.left
                        anchors.right:       parent.horizontalCenter
                        anchors.rightMargin: parent._gap
                        spacing:             _fH * 0.9

                        // 자산명 + 중복체크
                        RowLayout {
                            Layout.fillWidth: true
                            spacing:          _fW * 0.8

                            QGCLabel {
                                text:                  qsTr("자산명 *")
                                font.pointSize:        _fPt
                                color:                 qgcPal.text
                                Layout.preferredWidth: _root._lblW
                            }

                            // 자산명 입력 필드 (잠금 상태에 따라 배경 불투명도 변경)
                            Rectangle {
                                Layout.fillWidth: true
                                height:           _assetNameField.implicitHeight > 0
                                                  ? _assetNameField.implicitHeight : _fH * 1.6
                                color:            _root._nameLocked
                                                  ? Qt.rgba(1, 1, 1, 0.15)
                                                  : qgcPal.windowShade
                                border.color:     qgcPal.windowShadeDark
                                border.width:     1
                                radius:           2
                                opacity:          _root._nameLocked ? 0.5 : 1.0

                                QGCTextField {
                                    id:            _assetNameField
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
                                    if (_assetNameField.text.trim().length === 0) {
                                        _root._showAlert(qsTr("자산명을 입력해주세요."))
                                        return
                                    }
                                    // [중복체크기능] 현재 서버 미연결 → 항상 사용 가능(잠금) 처리
                                    _root._nameLocked = true
                                }
                            }
                        }

                        // 그룹
                        RowLayout {
                            Layout.fillWidth: true
                            spacing:          _fW * 0.8

                            QGCLabel {
                                text:                  qsTr("그룹")
                                font.pointSize:        _fPt
                                color:                 qgcPal.text
                                Layout.preferredWidth: _root._lblW
                            }
                            QGCComboBox {
                                id:               _groupCombo
                                Layout.fillWidth: true
                                model:            _root.groupModel
                            }
                        }

                        // 유형
                        RowLayout {
                            Layout.fillWidth: true
                            spacing:          _fW * 0.8

                            QGCLabel {
                                text:                  qsTr("유형")
                                font.pointSize:        _fPt
                                color:                 qgcPal.text
                                Layout.preferredWidth: _root._lblW
                            }
                            QGCComboBox {
                                id:               _typeCombo
                                Layout.fillWidth: true
                                model:            _assetTypeCombo.currentIndex === 0
                                                  ? [qsTr("멀티콥터"), qsTr("고정익"), qsTr("헬리콥터"), qsTr("로버")]
                                                  : [qsTr("소형"), qsTr("중형"), qsTr("대형")]
                            }
                        }

                        // 세로(mm)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing:          _fW * 0.8

                            QGCLabel {
                                text:                  qsTr("세로(mm)")
                                font.pointSize:        _fPt
                                color:                 qgcPal.text
                                Layout.preferredWidth: _root._lblW
                            }
                            QGCTextField {
                                Layout.fillWidth: true
                                text:             _root.initDepth
                                placeholderText:  qsTr("숫자만 입력")
                                inputMethodHints: Qt.ImhDigitsOnly
                                validator:        IntValidator { bottom: 0; top: 99999 }
                            }
                        }
                    }

                    // 오른쪽 컬럼
                    ColumnLayout {
                        id:                 _rightTopCol
                        anchors.left:       parent.horizontalCenter
                        anchors.leftMargin: parent._gap
                        anchors.right:      parent.right
                        spacing:            _fH * 0.9

                        // 자산 타입
                        RowLayout {
                            Layout.fillWidth: true
                            spacing:          _fW * 0.8

                            QGCLabel {
                                text:                  qsTr("자산 타입")
                                font.pointSize:        _fPt
                                color:                 qgcPal.text
                                Layout.preferredWidth: _root._lblW
                            }
                            QGCComboBox {
                                id:               _assetTypeCombo
                                Layout.fillWidth: true
                                model:            [qsTr("드론"), qsTr("스테이션")]
                                enabled:          false
                                opacity:          0.5
                            }
                        }

                        // RTSP 주소
                        RowLayout {
                            Layout.fillWidth: true
                            spacing:          _fW * 0.8

                            QGCLabel {
                                text:                  qsTr("RTSP 주소")
                                font.pointSize:        _fPt
                                color:                 qgcPal.text
                                Layout.preferredWidth: _root._lblW
                            }
                            QGCTextField {
                                Layout.fillWidth: true
                            }
                        }

                        // 가로(mm)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing:          _fW * 0.8

                            QGCLabel {
                                text:                  qsTr("가로(mm)")
                                font.pointSize:        _fPt
                                color:                 qgcPal.text
                                Layout.preferredWidth: _root._lblW
                            }
                            QGCTextField {
                                Layout.fillWidth: true
                                text:             _root.initWidth
                                placeholderText:  qsTr("숫자만 입력")
                                inputMethodHints: Qt.ImhDigitsOnly
                                validator:        IntValidator { bottom: 0; top: 99999 }
                            }
                        }

                        // 높이(mm)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing:          _fW * 0.8

                            QGCLabel {
                                text:                  qsTr("높이(mm)")
                                font.pointSize:        _fPt
                                color:                 qgcPal.text
                                Layout.preferredWidth: _root._lblW
                            }
                            QGCTextField {
                                Layout.fillWidth: true
                                text:             _root.initHeight
                                placeholderText:  qsTr("숫자만 입력")
                                inputMethodHints: Qt.ImhDigitsOnly
                                validator:        IntValidator { bottom: 0; top: 99999 }
                            }
                        }

                        // 상태
                        RowLayout {
                            Layout.fillWidth: true
                            spacing:          _fW * 0.8

                            QGCLabel {
                                text:                  qsTr("상태")
                                font.pointSize:        _fPt
                                color:                 qgcPal.text
                                Layout.preferredWidth: _root._lblW
                            }
                            QGCComboBox {
                                id:               _statusCombo
                                Layout.fillWidth: true
                                model:            [qsTr("사용중"), qsTr("미사용"), qsTr("점검중")]
                            }
                        }
                    }
                }

                // ── 하단: 설명 (전체 너비)
                RowLayout {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    spacing:           _fW * 0.8

                    QGCLabel {
                        text:                  qsTr("설명")
                        font.pointSize:        _fPt
                        color:                 qgcPal.text
                        Layout.preferredWidth: _root._lblW
                        Layout.alignment:      Qt.AlignTop
                        topPadding:            _fH * 0.3
                    }

                    Rectangle {
                        Layout.fillWidth:  true
                        Layout.fillHeight: true
                        color:             qgcPal.textField
                        border.color:      qgcPal.textFieldBorderColor
                        border.width:      1
                        radius:            2

                        ScrollView {
                            anchors.fill:    parent
                            anchors.margins: 4
                            clip:            true

                            TextArea {
                                id:             _descField
                                background:     null
                                color:          qgcPal.textFieldText
                                font.pointSize: _fPt
                                wrapMode:       TextArea.Wrap
                                selectByMouse:  true
                            }
                        }
                    }
                }
            }
        }

        // ── 하단 버튼
        Item {
            id:              _bottomArea
            anchors.left:    parent.left
            anchors.right:   parent.right
            anchors.bottom:  parent.bottom
            anchors.margins: _margin
            height:          _fH * 2.2

            Row {
                anchors.right:          parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing:                _fW

                QGCButton {
                    text:      qsTr("수정")
                    onClicked: {
                        // 자산명 중복체크 미완료 시 팝업
                        if (!_root._nameLocked) {
                            _root._showAlert(qsTr("자산명 중복체크를 먼저 진행해주세요."))
                            return
                        }
                        // [자산수정] 현재 서버 미연결 → 클라이언트 측에서 accepted 신호만 발송
                        // TODO: 서버 자산수정 API 호출 후 성공 시 accepted() 처리
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
}
