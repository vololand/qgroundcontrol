import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Palette
import QGroundControl.Controls
import QGroundControl.ScreenTools

ApplicationWindow {
    id:             mainWindow
    visible:        true
    width:          ScreenTools.isMobile ? ScreenTools.screenWidth : 1280
    height:         ScreenTools.isMobile ? ScreenTools.screenHeight : 720

    // [핵심] QGC 팔레트 및 상태 보존 기능 유지
    QGCPalette { id: qgcPal; colorGroupEnabled: true }
    MainWindowSavedState { window: mainWindow }

    // 1. 배경 설정
    background: Rectangle {
        anchors.fill: parent
        color: qgcPal.window
    }

    // 2. 메인 컨텐츠 영역 (이곳에 UI를 그리세요)
    Item {
        id: customContentArea
        anchors.fill: parent

        // 예시: 상단 커스텀 헤더
        Rectangle {
            id: myHeader
            width: parent.width
            height: ScreenTools.defaultFontPixelHeight * 3
            color: qgcPal.toolbarBackground

            QGCLabel {
                anchors.centerIn: parent
                text: "My Custom QGC UI (v" + QGroundControl.qgcVersion + ")"
                font.pointSize: ScreenTools.largeFontPointSize
            }
        }

        // 예시: 중앙 작업 영역
        Rectangle {
            anchors.top: myHeader.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            color: "transparent"
            QGCLabel {
                anchors.centerIn: parent
                text: "이곳에 나만의 버튼이나 맵을 배치하세요."
            }
        }
    }

    // [중요] 앱 종료 시 데이터 유실 방지 로직 (유지 권장) [cite: 22, 29]
    property bool _forceClose: false
    function performCloseChecks() {
        // 미저장 미션이나 파라미터 확인 후 종료 [cite: 24, 26]
        if (QGroundControl.multiVehicleManager.activeVehicle) {
            // 연결된 드론이 있을 때 경고 등 로직 추가 가능 [cite: 27]
        }
        _forceClose = true
        mainWindow.close()
    }

    onClosing: (close) => {
        if (!_forceClose) {
            close.accepted = false
            performCloseChecks()
        }
    }
}
