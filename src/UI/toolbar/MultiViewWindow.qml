import QtQuick 6.8
import QtQuick.Window
import QGroundControl
import QGroundControl.Toolbar

// 멀티뷰 그리드를 담는 최상위 프레임리스 창. 드론/스테이션 확대창과 동일한 UX로
// 창 자체가 앱 밖으로 이동 가능(타이틀바 드래그) + 8방향 리사이즈 + 최소/최대/닫기.
Window {
    id: win

    property real _titleBarHeight: 30
    property real _buttonWidth: 36
    property real _closeButtonWidth: 42
    property bool _maximized: false

    // 툴바 멀티뷰 버튼에서 호출.
    function openWindow() {
        if (visibility === Window.Hidden || visibility === Window.Minimized)
            visibility = Window.Windowed
        raise()
        requestActivate()
    }

    // 최대화 <-> 복원 토글. 네이티브 windowState 판독(프레임리스에서 불안정) 대신 QML visibility로 직접 제어.
    function toggleMaximize() {
        visibility = (visibility === Window.Maximized) ? Window.Windowed : Window.Maximized
    }

    // 독립 최상위 창으로 분리(mainWindow의 transient 자식이 아님) → 작업표시줄 버튼 생성 + 정상 최소화.
    // transient 자식이면 프레임리스 최소화 시 Windows 레거시 캡션 스텁("QGroundControl Daily")이 뜬다.
    transientParent: null
    title: qsTr("MultiView")
    width: 960
    height: 680
    x: 160
    y: 100
    minimumWidth: 480
    minimumHeight: 360
    flags: Qt.Window | Qt.FramelessWindowHint
    visibility: Window.Hidden
    color: "#0d0d0d"

    onVisibilityChanged: (newVisibility) => {
        _maximized = (newVisibility === Window.Maximized)
        // 창이 닫히면(숨김) 재생 중이던 모든 뷰의 RTSP 커넥션을 끊는다. (최소화는 유지)
        if (newVisibility === Window.Hidden)
            multiViewGrid.disconnectAll()
    }

    Column {
        anchors.fill: parent
        spacing: 0

        FramelessWindowTitleBar {
            id: topBar
            width: parent.width
            height: win._titleBarHeight
            targetWindow: win
            titleText: qsTr("MultiView")
            maximizeText: win._maximized ? "❐" : "□"
            buttonWidth: win._buttonWidth
            closeButtonWidth: win._closeButtonWidth
            onMinimizeRequested: win.visibility = Window.Minimized
            onMaximizeToggleRequested: win.toggleMaximize()
            onCloseRequested: win.visibility = Window.Hidden
        }

        MultiViewGrid {
            id: multiViewGrid
            width: parent.width
            height: win.height - topBar.height
        }
    }

    // 8방향 리사이즈 (Windowed 상태에서만)
    WindowResizeLayer {
        targetWindow: win
    }
}
