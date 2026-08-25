import QtQuick
import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Controls

/// 암호화 링크 오류를 알리는 툴바 아이콘. 미확인 건수를 배지로 표시하고,
/// 클릭하면 CryptoAlertPopup 으로 오류 목록과 수신 통계를 보여준다.
Item {
    id: root

    readonly property var  monitor:    QGroundControl.cryptoLinkMonitor
    readonly property int  unread:     monitor ? monitor.unreadCount : 0
    readonly property int  worstLevel: monitor ? monitor.worstUnreadLevel : -1
    readonly property bool suspended:  monitor ? monitor.suspended : false
    readonly property bool hasAlert:   suspended || unread > 0
    // 0 정보 / 1 경고 / 2 오류
    readonly property color alertColor: (suspended || worstLevel >= 2) ? "#ff4d4f"
                                      : worstLevel === 1 ? "#faad14"
                                      : "#40a9ff"

    property real iconSize: height * 0.55

    QGCColoredImage {
        id: icon
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        fillMode: Image.PreserveAspectFit
        source: "qrc:/qmlimages/Yield.svg"
        opacity: root.hasAlert ? 1 : 0.5
        color: root.hasAlert ? root.alertColor
             : (mouse.containsMouse ? "#00BFFF" : "white")
    }

    Rectangle {
        id: badge
        visible: root.unread > 0
        anchors.horizontalCenter: icon.right
        anchors.verticalCenter: icon.top
        height: ScreenTools.defaultFontPixelHeight * 0.85
        width: Math.max(height, badgeLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 0.6)
        radius: height / 2
        color: root.alertColor

        Text {
            id: badgeLabel
            anchors.centerIn: parent
            text: root.unread > 99 ? "99+" : root.unread
            color: "black"
            font.bold: true
            font.pixelSize: badge.height * 0.72
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (popupComponent.status === Component.Ready) {
                popupComponent.createObject(mainWindow).open()
            }
        }
    }

    Component {
        id: popupComponent
        CryptoAlertPopup {
            onClosed: destroy()
        }
    }
}
