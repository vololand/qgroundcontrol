import QtQuick
import QtQuick.Window

import QGroundControl

// [Custom] 프레임리스 창 공통 타이틀바.
// 드론/스테이션 확대창, MultiViewWindow 등에서 복제되던 (드래그 이동 + Aero Snap +
// 우클릭 시스템메뉴 + 더블클릭 최대화 토글 + 최소/최대/닫기) 로직을 통합한다.
// 창 상태 변경 자체는 창마다 방식이 달라(visibility 직접 토글 vs WindowHelper) 시그널로 위임한다.
Rectangle {
    id: titleBar

    // 대상 Window. 필수 주입.
    property var    targetWindow
    // 좌측에 표시할 제목 텍스트.
    property string titleText:          ""
    // 최대화 버튼 글리프. MultiViewWindow는 최대화 상태에서 "❐"로 토글하므로 외부에서 바인딩.
    property string maximizeText:       "\u25A1"  // □
    property real   buttonWidth:        36
    property real   closeButtonWidth:   40

    signal minimizeRequested()
    signal maximizeToggleRequested()
    signal closeRequested()

    height:         30
    color:          "#222222"
    border.width:   1
    border.color:   "#3a3a3a"
    z:              1

    readonly property real _buttonRowWidth: buttonWidth * 2 + closeButtonWidth

    // MouseArea 로컬 좌표 → 창 콘텐츠(창 원점 기준) 좌표로 환산.
    // 기존 확대창의 mapToItem(content,...) 및 MultiViewWindow의 직접 좌표와 동일 결과를 보장.
    function _winPoint(mx, my) {
        return mapToItem(targetWindow.contentItem, mx, my)
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left:           parent.left
        anchors.leftMargin:     10
        text:                   titleBar.titleText
        color:                  "white"
        font.pixelSize:         12
    }

    MouseArea {
        id:                     dragArea
        anchors.fill:           parent
        anchors.rightMargin:    titleBar._buttonRowWidth
        acceptedButtons:        Qt.LeftButton | Qt.RightButton
        hoverEnabled:           true

        property point _pressPos:       Qt.point(0, 0)
        property bool  _dragStarted:    false

        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                _pressPos = Qt.point(mouse.x, mouse.y)
                _dragStarted = false
            } else if (mouse.button === Qt.RightButton) {
                var p = titleBar._winPoint(mouse.x, mouse.y)
                WindowHelper.showSystemMenu(titleBar.targetWindow, titleBar.targetWindow.x + p.x, titleBar.targetWindow.y + p.y)
            }
        }
        onPositionChanged: (mouse) => {
            if ((mouse.buttons & Qt.LeftButton) && !_dragStarted) {
                if (Math.abs(mouse.x - _pressPos.x) > 5 || Math.abs(mouse.y - _pressPos.y) > 5) {
                    _dragStarted = true
                    // 창 모드에서만 이동(최대화 상태는 더블클릭/□로 복원 후 이동).
                    if (titleBar.targetWindow.visibility === Window.Windowed) {
                        var p = titleBar._winPoint(_pressPos.x, _pressPos.y)
                        WindowHelper.startSystemMove(titleBar.targetWindow, p.x, p.y)
                    }
                }
            }
        }
        onReleased: (mouse) => {
            if (_dragStarted && mouse.button === Qt.LeftButton) {
                var p = titleBar._winPoint(mouse.x, mouse.y)
                WindowHelper.handleAeroSnap(titleBar.targetWindow, titleBar.targetWindow.x + p.x, titleBar.targetWindow.y + p.y)
            }
            _dragStarted = false
        }
        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton)
                titleBar.maximizeToggleRequested()
        }
    }

    Row {
        anchors.right:          parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing:                2
        height:                 parent.height
        z:                      2

        Rectangle {
            width:  titleBar.buttonWidth
            height: titleBar.height
            color:  minBtnArea.containsMouse ? "#2f2f2f" : "transparent"
            Text { anchors.centerIn: parent; text: "\u2014"; color: "white"; font.pixelSize: 14 }  // —
            MouseArea { id: minBtnArea; anchors.fill: parent; hoverEnabled: true; onClicked: titleBar.minimizeRequested() }
        }
        Rectangle {
            width:  titleBar.buttonWidth
            height: titleBar.height
            color:  maxBtnArea.containsMouse ? "#2f2f2f" : "transparent"
            Text { anchors.centerIn: parent; text: titleBar.maximizeText; color: "white"; font.pixelSize: 12 }
            MouseArea { id: maxBtnArea; anchors.fill: parent; hoverEnabled: true; onClicked: titleBar.maximizeToggleRequested() }
        }
        Rectangle {
            width:  titleBar.closeButtonWidth
            height: titleBar.height
            color:  closeBtnArea.containsMouse ? "#C42B1C" : "transparent"
            Text { anchors.centerIn: parent; text: "\u00D7"; color: "white"; font.pixelSize: 16 }  // ×
            MouseArea { id: closeBtnArea; anchors.fill: parent; hoverEnabled: true; onClicked: titleBar.closeRequested() }
        }
    }
}
