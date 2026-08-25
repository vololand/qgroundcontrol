import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Window

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Palette
import QGroundControl.MultiVehicleManager
import QGroundControl.ScreenTools
import QGroundControl.Controllers
import QGroundControl.Toolbar

Rectangle{

    id: root
    width: parent.width
    height: ScreenTools.toolbarHeight
    
    // QGCPalette 정의 (색상 사용을 위해 필요)
    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }
    
    color:  qgcPal.toolbarBackground

    property var    planMasterController

    property real   _controllerProgressPct: planMasterController && planMasterController.missionController ? planMasterController.missionController.progressPct : 0
    
    // 우측 블록 너비 (드래그 영역·툴바 레이아웃 계산용). 앵커 기반이라 전환 시 위치 고정.
    readonly property real _rightBlockWidth: CustomToolbarMetrics.horizontalMargin
        + root.height
        + CustomToolbarMetrics.spacing
        + (windowControlButtons.visible ? (3 * CustomToolbarMetrics.windowControlButtonSize + 2 * CustomToolbarMetrics.windowControlButtonsSpacing) : 0)
        + CustomToolbarMetrics.horizontalMargin
    readonly property real dragAreaLeft: CustomToolbarMetrics.horizontalMargin + viewButtonRow.width + CustomToolbarMetrics.spacing
    readonly property real dragAreaRight: _rightBlockWidth

    RowLayout {
        id:                     toolbarLayout
        anchors.fill:           parent
        anchors.leftMargin:     CustomToolbarMetrics.horizontalMargin
        anchors.rightMargin:    CustomToolbarMetrics.horizontalMargin
        spacing:                CustomToolbarMetrics.spacing

        // RowLayout 자식에는 anchors 사용 불가 → Item으로 감싸고 내부에 Row + MouseArea
        Item {
            id:                     viewButtonRow
            Layout.maximumHeight:   root.height
            Layout.alignment:       Qt.AlignVCenter
            implicitWidth:          returnLabelsRow.width
            implicitHeight:        returnLabelsRow.height
            z: 1000

            Row {
                id:                 returnLabelsRow
                anchors.centerIn:   parent
                spacing:            ScreenTools.defaultFontPixelWidth / 2
                QGCLabel {
                    font.pointSize: ScreenTools.largeFontPointSize
                    text:           "<"
                }
                QGCLabel {
                    text:           qsTr("Return")
                    font.pointSize: ScreenTools.largeFontPointSize
                }
            }

            MouseArea {
                anchors.fill:       parent
                z: 1001
                preventStealing:    true
                onClicked:          mainWindow.showCustomFlyView()
                onPressed:          (mouse) => { mouse.accepted = true }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.height
        }
    }

    // 서버 아이콘·윈도우 버튼: 앵커로 고정해 Plan 전환 시 위치가 바뀌지 않음
    Item {
        id:                     rightBlock
        anchors.right:          parent.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        width:                  _rightBlockWidth

        Row {
            id:                 rightBlockRow
            anchors.right:       parent.right
            anchors.rightMargin: CustomToolbarMetrics.horizontalMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing:             CustomToolbarMetrics.spacing

            Item {
                id:                 serverConnectionIcon
                width:              root.height
                height:             root.height
                visible:            true
                Image {
                    anchors.centerIn: parent
                    width:          root.height
                    height:         root.height
                    fillMode:       Image.PreserveAspectFit
                    smooth:         true
                    mipmap:         true
                    source: {
                        if (mainWindow.serverConnectionStatus === 0) return "qrc:/qmlimages/ServerConnected.png"
                        if (mainWindow.serverConnectionStatus === 1) return "qrc:/qmlimages/ServerConnecting.png"
                        return "qrc:/qmlimages/ServerDisconnected.png"
                    }
                }
            }

            RowLayout {
                id: windowControlButtons
                spacing: CustomToolbarMetrics.windowControlButtonsSpacing
                visible: !ScreenTools.isMobile && mainWindow.visibility !== Window.FullScreen

                ToolButton {
                    id: minimizeBtn
                    implicitWidth: CustomToolbarMetrics.windowControlButtonSize
                    implicitHeight: CustomToolbarMetrics.windowControlButtonSize
                    background: Rectangle {
                        color: minimizeBtn.hovered ? (minimizeBtn.pressed ? qgcPal.buttonHighlight : qgcPal.button) : "transparent"
                        radius: CustomToolbarMetrics.windowControlButtonRadius
                    }
                    contentItem: Text {
                        text: "−"
                        font.pixelSize: CustomToolbarMetrics.windowControlMinimizeFontSize
                        color: qgcPal.buttonText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        mainWindow.saveVisibilityBeforeMinimize()
                        mainWindow.showMinimized()
                    }
                }

                ToolButton {
                    id: maximizeBtn
                    implicitWidth: CustomToolbarMetrics.windowControlButtonSize
                    implicitHeight: CustomToolbarMetrics.windowControlButtonSize
                    background: Rectangle {
                        color: maximizeBtn.hovered ? (maximizeBtn.pressed ? qgcPal.buttonHighlight : qgcPal.button) : "transparent"
                        radius: CustomToolbarMetrics.windowControlButtonRadius
                    }
                    contentItem: Text {
                        text: mainWindow.visibility === Window.Maximized ? "❐" : "□"
                        font.pixelSize: CustomToolbarMetrics.windowControlIconFontSize
                        color: qgcPal.buttonText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        mainWindow.setUserInitiatedStateChange()
                        if (mainWindow.visibility === Window.Maximized) {
                            mainWindow.showNormal()
                        } else {
                            mainWindow.showMaximized()
                        }
                    }
                }

                ToolButton {
                    id: closeBtn
                    implicitWidth: CustomToolbarMetrics.windowControlButtonSize
                    implicitHeight: CustomToolbarMetrics.windowControlButtonSize
                    background: Rectangle {
                        color: closeBtn.hovered ? (closeBtn.pressed ? "#e81123" : "#c42b1c") : "transparent"
                        radius: CustomToolbarMetrics.windowControlButtonRadius
                    }
                    contentItem: Text {
                        text: "✕"
                        font.pixelSize: CustomToolbarMetrics.windowControlIconFontSize
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        if (mainWindow.allowViewSwitch()) {
                            mainWindow.performCloseChecks()
                        }
                    }
                }
            }
        }
    }
}
