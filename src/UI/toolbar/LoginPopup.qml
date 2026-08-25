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

    signal loginClicked(string userId, string password, bool saveLoginInfo)
    signal findIdClicked()
    signal findPasswordClicked()
    signal registerClicked()

    property real _contentMargin: ScreenTools.defaultFontPixelHeight / 2
    property real _edgeMargin: ScreenTools.defaultFontPixelHeight
    property real _fieldHeight: ScreenTools.defaultFontPixelHeight * 2.2
    // UI 스케일에 비례하되, 항상 root(오버레이) 안으로 clamp
    property real _idealWidth: ScreenTools.defaultFontPixelWidth * 36
    property real _popupWidth: Math.min(_idealWidth, Math.max(0, root.width - _edgeMargin * 2))
    property real _popupHeight: Math.min(
        contentCol.implicitHeight + _contentMargin * 3,
        Math.max(0, root.height - _edgeMargin * 2)
    )

    // CheckBox의 checked: false 바인딩과 충돌하지 않도록 SSoT
    property bool saveLoginChecked: false

    onOpened: {
        QGroundControl.loginIdHistory.reload()
        var lastId = QGroundControl.loginIdHistory.lastUserId
        idField.text = lastId
        // 저장된 ID가 있으면 체크 복원 (로그아웃 후에도 유지)
        root.saveLoginChecked = lastId.length > 0
    }

    background: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.4)
        anchors.fill: parent
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: root._popupWidth
        height: root._popupHeight
        color: qgcPal.windowShade
        radius: 4
        border.width: 1
        border.color: qgcPal.windowShadeLight
        clip: true

        // contentItem Text 정렬이 아니라 버튼 자체를 패널 구석에 고정
        ToolButton {
            id: closeBtn
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 2
            anchors.rightMargin: 2
            z: 2
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

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: root._contentMargin * 1.5
            contentWidth: width
            contentHeight: contentCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            ColumnLayout {
                id: contentCol
                width: flick.width
                spacing: root._contentMargin

                Image {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(root._popupWidth * 0.45, contentCol.width)
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.5
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    source: "/res/VololandWhite.svg"
                }

                Item { Layout.preferredHeight: root._contentMargin * 1.5 }

                QGCTextField {
                    id: idField
                    Layout.fillWidth: true
                    Layout.preferredHeight: root._fieldHeight
                    placeholderText: qsTr("아이디를 입력해주세요")
                    verticalAlignment: TextInput.AlignVCenter
                }

                // 토글을 필드 위에 올리지 않고 같은 박스 안에 Row로 배치 → 캐럿/패딩 충돌 방지
                Rectangle {
                    id: passwordFieldWrap
                    Layout.fillWidth: true
                    Layout.preferredHeight: root._fieldHeight
                    color: qgcPal.textField
                    radius: ScreenTools.buttonBorderRadius
                    border.width: qgcPal.globalTheme === QGCPalette.Light ? 1 : 0
                    border.color: qgcPal.buttonBorder

                    property bool passwordVisible: false
                    readonly property real _toggleSize: ScreenTools.defaultFontPixelHeight * 0.85
                    readonly property real _toggleHitSize: ScreenTools.defaultFontPixelHeight * 1.4

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 0
                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.35
                        spacing: 0

                        QGCTextField {
                            id: passwordField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            echoMode: passwordFieldWrap.passwordVisible ? TextInput.Normal : TextInput.Password
                            placeholderText: qsTr("비밀번호를 입력해주세요")
                            verticalAlignment: TextInput.AlignVCenter
                            // 바깥 Rectangle이 보더/배경을 담당
                            background: Item { }
                        }

                        ToolButton {
                            id: showPasswordBtn
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: passwordFieldWrap._toggleHitSize
                            Layout.preferredHeight: passwordFieldWrap._toggleHitSize
                            focusPolicy: Qt.NoFocus
                            background: Item { }
                            contentItem: QGCColoredImage {
                                width: passwordFieldWrap._toggleSize
                                height: passwordFieldWrap._toggleSize
                                source: passwordFieldWrap.passwordVisible
                                        ? "qrc:/qmlimages/PasswordHide.svg"
                                        : "qrc:/qmlimages/PasswordShow.svg"
                                color: showPasswordBtn.hovered ? qgcPal.colorGrey : qgcPal.textFieldText
                                fillMode: Image.PreserveAspectFit
                                sourceSize.height: passwordFieldWrap._toggleSize
                            }
                            onClicked: passwordFieldWrap.passwordVisible = !passwordFieldWrap.passwordVisible
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root._contentMargin * 1.5

                    QGCCheckBox {
                        id: saveLoginCheck
                        text: qsTr("로그인 정보 저장")
                        checked: root.saveLoginChecked
                        // 바인딩 SSoT: 클릭 시 소스 속성을 직접 토글
                        onClicked: root.saveLoginChecked = !root.saveLoginChecked
                    }

                    Item { Layout.fillWidth: true }
                }

                QGCButton {
                    text: qsTr("로그인")
                    Layout.fillWidth: true
                    Layout.preferredHeight: root._fieldHeight
                    onClicked: root.loginClicked(idField.text, passwordField.text, root.saveLoginChecked)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root._contentMargin

                    Row {
                        spacing: ScreenTools.defaultFontPixelWidth * 0.5
                        Layout.alignment: Qt.AlignVCenter

                        QGCLabel {
                            text: qsTr("아이디 찾기")
                            font.pointSize: ScreenTools.smallFontPointSize
                            color: qgcPal.text

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.findIdClicked()
                            }
                        }

                        QGCLabel {
                            text: "|"
                            font.pointSize: ScreenTools.smallFontPointSize
                            color: qgcPal.windowShadeLight
                        }

                        QGCLabel {
                            text: qsTr("비밀번호 찾기")
                            font.pointSize: ScreenTools.smallFontPointSize
                            color: qgcPal.text

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.findPasswordClicked()
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    QGCLabel {
                        text: qsTr("계정 등록")
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: qgcPal.text
                        Layout.alignment: Qt.AlignVCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.registerClicked()
                        }
                    }
                }
            }
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }
}
