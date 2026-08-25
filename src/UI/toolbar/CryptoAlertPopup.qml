import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Palette
import QGroundControl.ScreenTools
import QGroundControl.Controls
import QGroundControl.Toolbar

/// 암호화 링크의 연결 상태와 오류 이력을 보여준다.
/// 데이터 원본은 CryptoLinkMonitor(C++ 싱글톤)이며 이 팝업은 표시/조작만 담당한다.
Popup {
    id: root
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 0
    width: typeof mainWindow !== "undefined" ? mainWindow.width : 800
    height: typeof mainWindow !== "undefined" ? mainWindow.height : 600
    x: 0
    y: 0

    readonly property var monitor: QGroundControl.cryptoLinkMonitor

    property real _contentMargin: ScreenTools.defaultFontPixelHeight / 2
    property real _edgeMargin: ScreenTools.defaultFontPixelHeight
    property real _belowToolbarMargin: 8
    property real _idealWidth: ScreenTools.defaultFontPixelWidth * 62
    property real _idealHeight: ScreenTools.defaultFontPixelHeight * 30
    property real _popupWidth: Math.min(_idealWidth, Math.max(0, root.width - _edgeMargin * 2))
    property real _popupHeight: Math.min(
        _idealHeight,
        Math.max(0, root.height - ScreenTools.toolbarHeight - _belowToolbarMargin - _edgeMargin)
    )

    function _levelColor(level) {
        if (level >= 2) return "#ff4d4f"
        if (level === 1) return "#faad14"
        return qgcPal.text
    }

    onOpened: if (monitor) monitor.markAllRead()

    background: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.4)
        anchors.fill: parent
    }

    Rectangle {
        x: Math.max(root._edgeMargin, root.width - width - CustomToolbarMetrics.horizontalMargin)
        y: Math.min(
            ScreenTools.toolbarHeight + root._belowToolbarMargin,
            Math.max(root._edgeMargin, root.height - height - root._edgeMargin)
        )
        width: root._popupWidth
        height: root._popupHeight
        color: qgcPal.windowShade
        radius: 4
        border.width: 1
        border.color: qgcPal.windowShadeLight
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root._contentMargin
            spacing: root._contentMargin

            RowLayout {
                Layout.fillWidth: true
                spacing: root._contentMargin

                QGCLabel {
                    text: qsTr("Connection State")
                    font.pointSize: ScreenTools.mediumFontPointSize
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                }

                ToolButton {
                    id: closeBtn
                    implicitWidth: CustomToolbarMetrics.windowControlButtonSize
                    implicitHeight: CustomToolbarMetrics.windowControlButtonSize
                    background: Rectangle {
                        color: closeBtn.hovered ? (closeBtn.pressed ? qgcPal.buttonHighlight : qgcPal.button) : "transparent"
                        radius: CustomToolbarMetrics.windowControlButtonRadius
                    }
                    contentItem: Text {
                        text: "✕"
                        font.pixelSize: CustomToolbarMetrics.windowControlIconFontSize
                        color: qgcPal.buttonText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: root.close()
                }
            }

            // 연결 상태
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: statusRow.implicitHeight + root._contentMargin * 2
                color: qgcPal.window
                radius: 2

                RowLayout {
                    id: statusRow
                    anchors.fill: parent
                    anchors.margins: root._contentMargin
                    spacing: root._contentMargin

                    QGCLabel {
                        text: qsTr("상태")
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                    QGCLabel {
                        Layout.fillWidth: true
                        text: !root.monitor ? qsTr("—")
                            : root.monitor.suspended ? qsTr("중지됨 (자동 재연결 꺼짐)")
                            : root.monitor.linkConnected ? qsTr("연결됨")
                            : qsTr("끊김")
                        color: !root.monitor ? qgcPal.text
                             : root.monitor.suspended ? "#ff4d4f"
                             : root.monitor.linkConnected ? qgcPal.text : "#faad14"
                    }
                }
            }

            // 오류 목록
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: qgcPal.window
                radius: 2

                QGCLabel {
                    anchors.centerIn: parent
                    visible: errorList.count === 0
                    text: qsTr("기록된 오류가 없습니다")
                    color: qgcPal.colorGrey
                }

                ListView {
                    id: errorList
                    anchors.fill: parent
                    anchors.margins: root._contentMargin / 2
                    clip: true
                    spacing: 1
                    model: root.monitor ? root.monitor.entries : []
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: ListView.view.width
                        height: entryRow.implicitHeight + ScreenTools.defaultFontPixelHeight / 3
                        color: index % 2 === 0 ? "transparent" : qgcPal.windowShade

                        RowLayout {
                            id: entryRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth / 2
                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth / 2
                            spacing: ScreenTools.defaultFontPixelWidth

                            QGCLabel {
                                text: modelData.time
                                font.pointSize: ScreenTools.smallFontPointSize
                                color: qgcPal.colorGrey
                                Layout.alignment: Qt.AlignTop
                            }
                            QGCLabel {
                                text: modelData.levelText
                                font.pointSize: ScreenTools.smallFontPointSize
                                font.bold: true
                                color: root._levelColor(modelData.level)
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 5
                            }
                            QGCLabel {
                                text: modelData.message
                                font.pointSize: ScreenTools.smallFontPointSize
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                Layout.fillWidth: true
                            }
                            QGCLabel {
                                visible: modelData.count > 1
                                text: "×" + modelData.count
                                font.pointSize: ScreenTools.smallFontPointSize
                                color: qgcPal.colorGrey
                                Layout.alignment: Qt.AlignTop
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: root._contentMargin

                QGCButton {
                    text: qsTr("연결 재개")
                    enabled: root.monitor ? root.monitor.suspended : false
                    Layout.fillWidth: true
                    onClicked: if (root.monitor) root.monitor.requestResume()
                }
                QGCButton {
                    text: qsTr("기록 지우기")
                    Layout.fillWidth: true
                    onClicked: if (root.monitor) root.monitor.clear()
                }
            }
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }
}
