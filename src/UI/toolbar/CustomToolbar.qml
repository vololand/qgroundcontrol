import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QGroundControl.Palette
import QGroundControl.ScreenTools
import QGroundControl
import QGroundControl.Controls
import QGroundControl.Toolbar

Rectangle {
    id: root
    width: parent.width
    height: ScreenTools.toolbarHeight
    implicitHeight: ScreenTools.toolbarHeight

    property bool showPlanReturnButton: false
    property var  returnAction: function() { mainWindow.showCustomFlyView() }

    // UI only — 세션/인증 연동 전 분기 플래그
    property bool userLoggedIn: false
    property string _stubUserId: ""

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }
    color: qgcPal.toolbarBackground

    readonly property real dragAreaLeft: CustomToolbarMetrics.horizontalMargin
        + (showPlanReturnButton ? returnButtonRow.width : toolSelectBtn.width)
        + CustomToolbarMetrics.spacing
    readonly property real dragAreaRight: _rightBlockWidth

    // 우측 블록 고정 너비 (앵커 배치용). RowLayout 재계산과 무관하게 항상 동일
    readonly property real _rightBlockWidth: CustomToolbarMetrics.horizontalMargin
        + root.height                       // Connection State
        + CustomToolbarMetrics.spacing
        + root.height                       // MultiView 버튼
        + CustomToolbarMetrics.spacing
        + root.height                       // UserInfo
        + CustomToolbarMetrics.spacing
        + (windowControlButtons.visible ? (3 * CustomToolbarMetrics.windowControlButtonSize + 2 * CustomToolbarMetrics.windowControlButtonsSpacing) : 0)
        + CustomToolbarMetrics.horizontalMargin

    RowLayout {
        id: toolbarLayout
        anchors.fill: parent
        anchors.leftMargin: CustomToolbarMetrics.horizontalMargin
        anchors.rightMargin: _rightBlockWidth
        spacing: CustomToolbarMetrics.spacing

        ToolButton {
            id: toolSelectBtn
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            padding: 0
            visible: !root.showPlanReturnButton
            readonly property real logoHeight: CustomToolbarMetrics.toolButtonSize * 0.6
            readonly property real logoWidth: (logoImage.status === Image.Ready && logoImage.implicitHeight > 0)
                ? logoImage.implicitWidth * logoHeight / logoImage.implicitHeight
                : 0
            implicitWidth: logoWidth
            implicitHeight: logoHeight
            width: logoWidth
            height: logoHeight
            Layout.preferredWidth: logoWidth
            Layout.preferredHeight: logoHeight
            Layout.maximumWidth: logoWidth
            Layout.maximumHeight: logoHeight
            background: Rectangle { color: "transparent" }
            contentItem: Image {
                id: logoImage
                source: "/res/VololandWhite.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                width: toolSelectBtn.logoWidth
                height: toolSelectBtn.logoHeight
                sourceSize.width: width
                sourceSize.height: height
            }
            z: 1
            onClicked: mainWindow.showToolSelectDialog()
        }

        Item {
            id: returnButtonRow
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumHeight: root.height
            visible: root.showPlanReturnButton
            implicitWidth: returnLabelsRow.width
            implicitHeight: returnLabelsRow.height
            z: 1000
            Row {
                id: returnLabelsRow
                anchors.centerIn: parent
                spacing: ScreenTools.defaultFontPixelWidth / 2
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    source: "/res/BackArrowWhite.svg"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    height: ScreenTools.largeFontPixelHeight
                }
            }
            MouseArea {
                anchors.fill: parent
                z: 1001
                preventStealing: true
                onClicked: root.returnAction()
                onPressed: (mouse) => { mouse.accepted = true }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.height
        }
    }

    Item {
        id: rightBlock
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: _rightBlockWidth

        RowLayout {
            id: rightBlockRow
            anchors.fill: parent
            anchors.rightMargin: CustomToolbarMetrics.horizontalMargin
            anchors.leftMargin: CustomToolbarMetrics.horizontalMargin
            spacing: CustomToolbarMetrics.spacing

            Item {
                Layout.fillWidth: true
            }

            // ConnectionState
            CryptoAlertIndicator {
                id: cryptoAlertIndicator
                Layout.preferredWidth: root.height
                Layout.preferredHeight: root.height
                Layout.alignment: Qt.AlignVCenter
            }
/*
            // 멀티뷰
            Item {
                id: multiViewButton
                Layout.preferredWidth: root.height
                Layout.preferredHeight: root.height
                Layout.alignment: Qt.AlignVCenter
                QGCColoredImage {
                    anchors.centerIn: parent
                    width: root.height * 0.55
                    height: root.height * 0.55
                    fillMode: Image.PreserveAspectFit
                    source: "qrc:/qmlimages/camera_video.svg"
                    color: multiViewMouse.containsMouse ? "#00BFFF" : "white"
                }
                MouseArea {
                    id: multiViewMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: multiViewWindow.openWindow()
                }
            }
*/
            Item {
                id: userInfoIcon
                Layout.preferredWidth: root.height
                Layout.preferredHeight: root.height
                Layout.alignment: Qt.AlignVCenter
                visible: true
                Image {
                    anchors.centerIn: parent
                    width: root.height
                    height: root.height
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    source: "qrc:/qmlimages/UserInfo.png"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.userLoggedIn) {
                            if (userInfoPopupComponent.status === Component.Ready) {
                                var infoPopup = userInfoPopupComponent.createObject(mainWindow, {
                                    "userId": root._stubUserId,
                                    "userRole": qsTr("사용자")
                                })
                                infoPopup.open()
                            }
                        } else if (loginPopupComponent.status === Component.Ready) {
                            loginPopupComponent.createObject(mainWindow).open()
                        }
                    }
                }
            }

            Component {
                id: loginPopupComponent
                LoginPopup {
                    onLoginClicked: (userId, password, saveLoginInfo) => {
                        // UI stub — 검증/서버 없이 유저정보 창으로 전환
                        var trimmedId = userId.trim()
                        root._stubUserId = trimmedId.length > 0 ? trimmedId : qsTr("사용자")
                        root.userLoggedIn = true
                        if (saveLoginInfo && trimmedId.length > 0)
                            QGroundControl.loginIdHistory.remember(trimmedId)
                        else
                            QGroundControl.loginIdHistory.clear()
                        close()
                        if (userInfoPopupComponent.status === Component.Ready) {
                            var infoPopup = userInfoPopupComponent.createObject(mainWindow, {
                                "userId": root._stubUserId,
                                "userRole": qsTr("사용자")
                            })
                            infoPopup.open()
                        }
                    }
                }
            }

            Component {
                id: userInfoPopupComponent
                UserInfoPopup {
                    onLogoutClicked: {
                        root.userLoggedIn = false
                        root._stubUserId = ""
                    }
                }
            }

            RowLayout {
                id: windowControlButtons
                Layout.alignment: Qt.AlignVCenter
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

    // 멀티뷰 그리드 이동창
    MultiViewWindow { id: multiViewWindow }
}

