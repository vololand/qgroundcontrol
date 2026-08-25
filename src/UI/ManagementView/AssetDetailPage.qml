/****************************************************************************
 *
 * QGroundControl Open Source Ground Control Station
 *
 * 자산 상세 페이지 (Read-only)
 * 트리거: 좌측 트리 asset 노드 더블클릭
 *
 * UserDetailPage.qml과 동일한 레이아웃·색상·간격 기준
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
    focus:        true

    signal closed()

    // ManagementView가 onLoaded에서 주입
    // TODO: 서버 연동 시 각 property에 실제 데이터 바인딩
    property string initAssetName:  ""
    property string initGroupName:  ""
    property string initAssetType:  ""
    property string initCategory:   ""
    property string initWidth:      ""
    property string initDepth:      ""
    property string initHeight:     ""
    property string initStatus:     ""
    property string initRtspUrl:    ""
    property string initRegDate:    ""

    onInitAssetNameChanged: _assetNameField.text = initAssetName
    Component.onCompleted: forceActiveFocus()

    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Escape) {
            event.accepted = true
            _root.closed()
        }
    }

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

    // ── 다이얼로그 본체
    Rectangle {
        id:               _dialog
        anchors.centerIn: parent
        width:            _fW * 72
        height:           _fH * 22
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
                text:                   qsTr("자산 정보")
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
                    onClicked:    _root.closed()
                }
            }
        }

        // ── 컨텐츠 (UserDetailPage와 동일 구조)
        ColumnLayout {
            anchors.top:     _titleBar.bottom
            anchors.left:    parent.left
            anchors.right:   parent.right
            anchors.bottom:  parent.bottom
            anchors.margins: _margin
            spacing:         _fH * 0.6

            // ── 정보 섹션 헤더
            QGCLabel {
                text:           qsTr("기본 정보")
                font.pointSize: _fPt
                font.bold:      true
                color:          qgcPal.text
            }

            // ── 정보 섹션 (읽기 전용 폼)
            ColumnLayout {
                Layout.fillWidth: true
                spacing:          _fH * 0.8

                // ── 공통 상수
                readonly property real _lblW: _fW * 8
                readonly property real _gap:  _fW * 1.0

                // 행 1: 자산명 | 그룹
                Item {
                    Layout.fillWidth: true
                    height:           _fH * 2.2

                    RowLayout {
                        anchors.left:           parent.left
                        anchors.right:          parent.horizontalCenter
                        anchors.rightMargin:    parent.parent._gap
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: _fW * 0.8

                        QGCLabel {
                            text:                  qsTr("자산명")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: parent.parent.parent._lblW
                        }
                        QGCTextField {
                            id:               _assetNameField
                            Layout.fillWidth: true
                            text:             _root.initAssetName
                            readOnly:         true
                        }
                    }

                    RowLayout {
                        anchors.left:           parent.horizontalCenter
                        anchors.leftMargin:     parent.parent._gap
                        anchors.right:          parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: _fW * 0.8

                        QGCLabel {
                            text:                  qsTr("그룹")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: parent.parent.parent._lblW
                        }
                        QGCTextField {
                            Layout.fillWidth: true
                            text:             _root.initGroupName
                            readOnly:         true
                        }
                    }
                }

                // 행 2: 자산 타입 | 유형
                Item {
                    Layout.fillWidth: true
                    height:           _fH * 2.2

                    RowLayout {
                        anchors.left:           parent.left
                        anchors.right:          parent.horizontalCenter
                        anchors.rightMargin:    parent.parent._gap
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: _fW * 0.8

                        QGCLabel {
                            text:                  qsTr("자산 타입")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: parent.parent.parent._lblW
                        }
                        QGCTextField {
                            Layout.fillWidth: true
                            text:             _root.initAssetType
                            readOnly:         true
                        }
                    }

                    RowLayout {
                        anchors.left:           parent.horizontalCenter
                        anchors.leftMargin:     parent.parent._gap
                        anchors.right:          parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: _fW * 0.8

                        QGCLabel {
                            text:                  qsTr("유형")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: parent.parent.parent._lblW
                        }
                        QGCTextField {
                            Layout.fillWidth: true
                            text:             _root.initCategory
                            readOnly:         true
                        }
                    }
                }

                // 행 3: 가로 | 세로
                Item {
                    Layout.fillWidth: true
                    height:           _fH * 2.2

                    RowLayout {
                        anchors.left:           parent.left
                        anchors.right:          parent.horizontalCenter
                        anchors.rightMargin:    parent.parent._gap
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: _fW * 0.8

                        QGCLabel {
                            text:                  qsTr("가로 (mm)")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: parent.parent.parent._lblW
                        }
                        QGCTextField {
                            Layout.fillWidth: true
                            text:             _root.initWidth
                            readOnly:         true
                        }
                    }

                    RowLayout {
                        anchors.left:           parent.horizontalCenter
                        anchors.leftMargin:     parent.parent._gap
                        anchors.right:          parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: _fW * 0.8

                        QGCLabel {
                            text:                  qsTr("세로 (mm)")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: parent.parent.parent._lblW
                        }
                        QGCTextField {
                            Layout.fillWidth: true
                            text:             _root.initDepth
                            readOnly:         true
                        }
                    }
                }

                // 행 4: 높이 | 자산 상태
                Item {
                    Layout.fillWidth: true
                    height:           _fH * 2.2

                    RowLayout {
                        anchors.left:           parent.left
                        anchors.right:          parent.horizontalCenter
                        anchors.rightMargin:    parent.parent._gap
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: _fW * 0.8

                        QGCLabel {
                            text:                  qsTr("높이 (mm)")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: parent.parent.parent._lblW
                        }
                        QGCTextField {
                            Layout.fillWidth: true
                            text:             _root.initHeight
                            readOnly:         true
                        }
                    }

                    RowLayout {
                        anchors.left:           parent.horizontalCenter
                        anchors.leftMargin:     parent.parent._gap
                        anchors.right:          parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: _fW * 0.8

                        QGCLabel {
                            text:                  qsTr("자산 상태")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: parent.parent.parent._lblW
                        }
                        QGCTextField {
                            Layout.fillWidth: true
                            text:             _root.initStatus
                            readOnly:         true
                        }
                    }
                }

                // 행 5: RTSP 주소 | 등록일
                Item {
                    Layout.fillWidth: true
                    height:           _fH * 2.2

                    RowLayout {
                        anchors.left:           parent.left
                        anchors.right:          parent.horizontalCenter
                        anchors.rightMargin:    parent.parent._gap
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: _fW * 0.8

                        QGCLabel {
                            text:                  qsTr("RTSP 주소")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: parent.parent.parent._lblW
                        }
                        QGCTextField {
                            Layout.fillWidth: true
                            text:             _root.initRtspUrl
                            readOnly:         true
                        }
                    }

                    RowLayout {
                        anchors.left:           parent.horizontalCenter
                        anchors.leftMargin:     parent.parent._gap
                        anchors.right:          parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: _fW * 0.8

                        QGCLabel {
                            text:                  qsTr("등록일")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: parent.parent.parent._lblW
                        }
                        QGCTextField {
                            Layout.fillWidth: true
                            text:             _root.initRegDate
                            readOnly:         true
                        }
                    }
                }
            }
        }
    }
}
