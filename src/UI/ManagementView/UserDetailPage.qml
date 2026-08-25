/****************************************************************************
 *
 * QGroundControl Open Source Ground Control Station
 *
 * 사용자 상세 페이지 (Read-only)
 * 트리거: 좌측 트리 user 노드 더블클릭
 *
 * UserEditPage.qml과 동일한 레이아웃·색상·간격 기준
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
    property string initUserName:      ""
    property string initAccountStatus: qsTr("활성화")
    property string initUserId:        ""
    property string initGroup:         ""
    property string initPhone:         ""
    property string initRegDate:       ""
    property string initRole:          ""
    // TODO: 서버에서 수신한 그룹/자산 권한 데이터로 교체
    property var    groupPermModel:    []
    property var    assetPermModel:    []

    onInitUserNameChanged: _usernameField.text = initUserName
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

    // ── 권한 더미 데이터 — 상세 페이지는 View 권한이 있는 항목만 표시
    // TODO: 서버에서 사용자 소속 대그룹 및 하위 그룹/자산 권한 데이터를 각각 수신하여 모델에 바인딩
    ListModel {
        id: _groupPermModel
        ListElement { itemName: "미래항공모빌리티연구소";             perm: 3 }
        ListElement { itemName: "볼로 무인기 & 지상 플랫폼 그룹";     perm: 7 }
        ListElement { itemName: "볼로 자율비행플랫폼 그룹";           perm: 0 }
    }
    ListModel {
        id: _assetPermModel
        ListElement { itemName: "drone1";   perm: 3 }
        ListElement { itemName: "drone2";   perm: 1 }
        ListElement { itemName: "station1"; perm: 0 }
    }

    // ── 그룹/자산 권한 테이블 공통 UI (표시 전용)
    component PermissionTable: Rectangle {
        id: _table

        property alias model: _permRows.model
        property string nameHeader: ""

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
                        readonly property bool _visibleByView: (perm & 1) !== 0

                        width:   _permData.width
                        height:  _visibleByView ? _root._fH * 2.4 : 0
                        visible: _visibleByView

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
                                    width:                  parent.width - _root._fW * 1.2
                                }
                            }

                            Rectangle { width: 1; height: parent.height; color: qgcPal.windowShadeDark }

                            Item {
                                width:  _permData.width - _table._leftW - 1
                                height: parent.height

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left:           parent.left
                                    anchors.leftMargin:     _root._fW * 0.6
                                    spacing:                _root._fW * 0.45

                                    Repeater {
                                        model: [ { label: qsTr("View"),    bit: 1 },
                                                 { label: qsTr("Control"), bit: 2 },
                                                 { label: qsTr("Admin"),   bit: 4 } ]

                                        Rectangle {
                                            width:  _root._fW * 5.8
                                            height: _root._fH * 1.5
                                            radius: 3

                                            readonly property bool _on: (perm & modelData.bit) !== 0

                                            color:        _on ? "#1a6bbf" : "transparent"
                                            border.color: _on ? "#1a6bbf" : "#666666"
                                            border.width: 1

                                            QGCLabel {
                                                anchors.centerIn: parent
                                                text:             modelData.label
                                                font.pointSize:   _root._fPt * 0.78
                                                font.bold:        parent._on
                                                color:            parent._on ? "#ffffff" : "#aaaaaa"
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible:        _visibleByView && index < _permRows.count - 1
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
                text:                   qsTr("사용자 정보")
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

        // ── 컨텐츠 (UserEditPage와 동일 구조)
        ColumnLayout {
            anchors.top:        _titleBar.bottom
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.bottom:     parent.bottom
            anchors.margins:    _margin
            spacing:            _fH * 0.6

            // ── 정보 섹션 (읽기 전용 폼)
            ColumnLayout {
                Layout.fillWidth: true
                spacing:          _fH * 0.8

                // ── 공통 상수
                readonly property real _lblW: _fW * 8
                readonly property real _gap:  _fW * 1.0   // 좌우 컬럼 간 여백 절반

                // 행 1: USERNAME | 계정 상태
                Item {
                    Layout.fillWidth: true
                    height:           _fH * 2.2

                    RowLayout {
                        anchors.left:        parent.left
                        anchors.right:       parent.horizontalCenter
                        anchors.rightMargin: parent.parent._gap
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: _fW * 0.8

                        QGCLabel {
                            text:                  qsTr("USERNAME")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: parent.parent.parent._lblW
                        }
                        QGCTextField {
                            id:               _usernameField
                            Layout.fillWidth: true
                            text:             _root.initUserName
                            readOnly:         true
                        }
                    }

                    RowLayout {
                        anchors.left:        parent.horizontalCenter
                        anchors.leftMargin:  parent.parent._gap
                        anchors.right:       parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: _fW * 0.8

                        QGCLabel {
                            text:                  qsTr("계정 상태")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: parent.parent.parent._lblW
                        }
                        QGCTextField {
                            Layout.fillWidth: true
                            text:             _root.initAccountStatus
                            readOnly:         true
                        }
                    }
                }

                // 행 2: ID | 그룹
                Item {
                    Layout.fillWidth: true
                    height:           _fH * 2.2

                    RowLayout {
                        anchors.left:        parent.left
                        anchors.right:       parent.horizontalCenter
                        anchors.rightMargin: parent.parent._gap
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: _fW * 0.8

                        QGCLabel {
                            text:                  qsTr("ID")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: parent.parent.parent._lblW
                        }
                        QGCTextField {
                            Layout.fillWidth: true
                            text:             _root.initUserId
                            readOnly:         true
                        }
                    }

                    RowLayout {
                        anchors.left:        parent.horizontalCenter
                        anchors.leftMargin:  parent.parent._gap
                        anchors.right:       parent.right
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
                            text:             _root.initGroup
                            readOnly:         true
                        }
                    }
                }

                // 행 3: 휴대폰 번호 | 등록일
                Item {
                    Layout.fillWidth: true
                    height:           _fH * 2.2

                    RowLayout {
                        anchors.left:        parent.left
                        anchors.right:       parent.horizontalCenter
                        anchors.rightMargin: parent.parent._gap
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: _fW * 0.8

                        QGCLabel {
                            text:                  qsTr("휴대폰 번호")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: parent.parent.parent._lblW
                        }
                        QGCTextField {
                            Layout.fillWidth: true
                            text:             _root.initPhone
                            readOnly:         true
                        }
                    }

                    RowLayout {
                        anchors.left:        parent.horizontalCenter
                        anchors.leftMargin:  parent.parent._gap
                        anchors.right:       parent.right
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

                // 행 4: ROLE (왼쪽만)
                Item {
                    Layout.fillWidth: true
                    height:           _fH * 2.2

                    RowLayout {
                        anchors.left:        parent.left
                        anchors.right:       parent.horizontalCenter
                        anchors.rightMargin: parent.parent._gap
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: _fW * 0.8

                        QGCLabel {
                            text:                  qsTr("ROLE")
                            font.pointSize:        _fPt
                            color:                 qgcPal.text
                            Layout.preferredWidth: parent.parent.parent._lblW
                        }
                        QGCTextField {
                            Layout.fillWidth: true
                            text:             _root.initRole
                            readOnly:         true
                        }
                    }
                }
            }

            // ── 섹션 구분선
            Rectangle {
                Layout.fillWidth: true
                height:           1
                color:            qgcPal.windowShadeDark
            }

            // ── 권한 격자 테이블 (표시 전용)
            // 상세 페이지는 View 권한이 있는 그룹/자산만 보여준다.
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing:          _fW

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
                    }
                }
            }
        }
    }
}
