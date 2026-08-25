import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Palette
import QGroundControl.ScreenTools
import QGroundControl.Controls
import QGroundControl.Toolbar

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

    property string userId: ""
    property string userRole: ""
    property string loginTime: ""

    // UI only — 세션 연동 전
    signal logoutClicked()

    property real _contentMargin: ScreenTools.defaultFontPixelHeight / 2
    property real _edgeMargin: ScreenTools.defaultFontPixelHeight
    property real _belowToolbarMargin: 8
    property real _idealWidth: ScreenTools.defaultFontPixelWidth * 34
    property real _idealHeight: ScreenTools.defaultFontPixelHeight * 14
    property real _popupWidth: Math.min(_idealWidth, Math.max(0, root.width - _edgeMargin * 2))
    property real _popupHeight: Math.min(
        _idealHeight,
        Math.max(0, root.height - ScreenTools.toolbarHeight - _belowToolbarMargin - _edgeMargin)
    )

    function _roleDisplayText() {
        if (userRole === "슈퍼관리자" || userRole === "관리자" || userRole === "사용자")
            return userRole
        return userRole.length > 0 ? userRole : qsTr("—")
    }

    background: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.4)
        anchors.fill: parent
    }

    Rectangle {
        // 우측 정렬이어도 root 밖으로 나가지 않도록 clamp
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
                    text: qsTr("사용자 정보")
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

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: qgcPal.window
                radius: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root._contentMargin
                    spacing: root._contentMargin

                    QGCLabel {
                        text: qsTr("사용자 ID/이름")
                        font.pointSize: ScreenTools.smallFontPointSize
                        Layout.fillWidth: true
                    }
                    QGCLabel {
                        text: root.userId || qsTr("—")
                        font.pointSize: ScreenTools.defaultFontPointSize
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    Item { Layout.preferredHeight: root._contentMargin }

                    QGCLabel {
                        text: qsTr("권한 레벨")
                        font.pointSize: ScreenTools.smallFontPointSize
                        Layout.fillWidth: true
                    }
                    QGCLabel {
                        text: root._roleDisplayText()
                        font.pointSize: ScreenTools.defaultFontPointSize
                        Layout.fillWidth: true
                    }

                    Item { Layout.fillHeight: true }

                    QGCButton {
                        text: qsTr("로그아웃")
                        Layout.fillWidth: true
                        onClicked: {
                            root.logoutClicked()
                            if (typeof mainWindow !== "undefined" && typeof mainWindow.onLogout === "function")
                                mainWindow.onLogout()
                            root.close()
                        }
                    }
                }
            }
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }
}
