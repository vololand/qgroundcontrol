/****************************************************************************
 *
 * QGroundControl Open Source Ground Control Station
 *
 * 그룹 상세 페이지 (Read-only)
 * 트리거: 좌측 트리 group/subGroup 노드 우클릭 → 그룹 상세
 *
 * 표시 항목:
 *   parent group name, groupName, description
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
    // TODO: 서버 GroupDetailRes 수신 후 각 property에 실제 데이터 바인딩
    property string initParentName:  ""
    property string initGroupName:   ""
    property string initDescription: ""

    onInitGroupNameChanged: _groupNameField.text = initGroupName
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
        height:           _fH * 14.5
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
                text:                   qsTr("그룹 정보")
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

        ColumnLayout {
            anchors.top:     _titleBar.bottom
            anchors.left:    parent.left
            anchors.right:   parent.right
            anchors.bottom:  parent.bottom
            anchors.margins: _margin
            spacing:         _fH * 0.6

            QGCLabel {
                text:           qsTr("기본 정보")
                font.pointSize: _fPt
                font.bold:      true
                color:          qgcPal.text
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing:          _fH * 0.8

                readonly property real _lblW: _fW * 8
                readonly property real _gap:  _fW * 1.0

                // 행 1: 상위 그룹 | 그룹명
                Item {
                    Layout.fillWidth: true
                    height:           _fH * 2.2

                    RowLayout {
                        anchors.left:           parent.left
                        anchors.right:          parent.horizontalCenter
                        anchors.rightMargin:    parent.parent._gap
                        anchors.verticalCenter: parent.verticalCenter
                        spacing:                _fW * 0.8

                        QGCLabel {
                            text:                  qsTr("상위 그룹")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: parent.parent.parent._lblW
                        }
                        QGCTextField {
                            Layout.fillWidth: true
                            text:             _root.initParentName
                            readOnly:         true
                        }
                    }

                    RowLayout {
                        anchors.left:           parent.horizontalCenter
                        anchors.leftMargin:     parent.parent._gap
                        anchors.right:          parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing:                _fW * 0.8

                        QGCLabel {
                            text:                  qsTr("그룹명")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: parent.parent.parent._lblW
                        }
                        QGCTextField {
                            id:               _groupNameField
                            Layout.fillWidth: true
                            text:             _root.initGroupName
                            readOnly:         true
                        }
                    }
                }

                // 행 2: 설명
                RowLayout {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: _fH * 4.5
                    spacing:                _fW * 0.8

                    QGCLabel {
                        text:                  qsTr("설명")
                        font.pointSize:        _fPt
                        color:                 qgcPal.text
                        Layout.preferredWidth: parent._lblW
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
                                background:     null
                                color:          qgcPal.textFieldText
                                font.pointSize: _fPt
                                text:           _root.initDescription
                                readOnly:       true
                                wrapMode:       TextArea.Wrap
                                selectByMouse:  true
                            }
                        }
                    }
                }
            }
        }
    }
}
