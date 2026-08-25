import QtQuick
import QtQuick.Window

import QGroundControl

// [Custom] 프레임리스 창 공통 8방향 리사이즈 레이어.
// 드론/스테이션 확대창, MultiViewWindow 등에서 동일하게 복제되던 8개 MouseArea를 하나로 통합.
// Windowed 상태에서만 활성(최대화 시 리사이즈 차단) → 기존 동작 그대로.
Item {
    id: resizeLayer

    // 리사이즈 대상 Window. 필수 주입.
    property var targetWindow
    // 변/모서리 히트 영역 크기(px). 기존 확대창/ MultiViewWindow와 동일 기본값.
    property int edgeSize:   5
    property int cornerSize: 10

    anchors.fill: parent
    z:            50
    visible:      targetWindow && targetWindow.visibility === Window.Windowed

    MouseArea {
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: resizeLayer.edgeSize; cursorShape: Qt.SizeHorCursor; acceptedButtons: Qt.LeftButton
        onPressed: (m) => { if (m.button === Qt.LeftButton) WindowHelper.startSystemResize(resizeLayer.targetWindow, Qt.LeftEdge) }
    }
    MouseArea {
        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: resizeLayer.edgeSize; cursorShape: Qt.SizeHorCursor; acceptedButtons: Qt.LeftButton
        onPressed: (m) => { if (m.button === Qt.LeftButton) WindowHelper.startSystemResize(resizeLayer.targetWindow, Qt.RightEdge) }
    }
    MouseArea {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: resizeLayer.edgeSize; cursorShape: Qt.SizeVerCursor; acceptedButtons: Qt.LeftButton
        onPressed: (m) => { if (m.button === Qt.LeftButton) WindowHelper.startSystemResize(resizeLayer.targetWindow, Qt.TopEdge) }
    }
    MouseArea {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: resizeLayer.edgeSize; cursorShape: Qt.SizeVerCursor; acceptedButtons: Qt.LeftButton
        onPressed: (m) => { if (m.button === Qt.LeftButton) WindowHelper.startSystemResize(resizeLayer.targetWindow, Qt.BottomEdge) }
    }
    MouseArea {
        anchors.left: parent.left; anchors.top: parent.top
        width: resizeLayer.cornerSize; height: resizeLayer.cornerSize
        cursorShape: Qt.SizeFDiagCursor; acceptedButtons: Qt.LeftButton
        onPressed: (m) => { if (m.button === Qt.LeftButton) WindowHelper.startSystemResize(resizeLayer.targetWindow, Qt.TopEdge | Qt.LeftEdge) }
    }
    MouseArea {
        anchors.right: parent.right; anchors.top: parent.top
        width: resizeLayer.cornerSize; height: resizeLayer.cornerSize
        cursorShape: Qt.SizeBDiagCursor; acceptedButtons: Qt.LeftButton
        onPressed: (m) => { if (m.button === Qt.LeftButton) WindowHelper.startSystemResize(resizeLayer.targetWindow, Qt.TopEdge | Qt.RightEdge) }
    }
    MouseArea {
        anchors.left: parent.left; anchors.bottom: parent.bottom
        width: resizeLayer.cornerSize; height: resizeLayer.cornerSize
        cursorShape: Qt.SizeBDiagCursor; acceptedButtons: Qt.LeftButton
        onPressed: (m) => { if (m.button === Qt.LeftButton) WindowHelper.startSystemResize(resizeLayer.targetWindow, Qt.BottomEdge | Qt.LeftEdge) }
    }
    MouseArea {
        anchors.right: parent.right; anchors.bottom: parent.bottom
        width: resizeLayer.cornerSize; height: resizeLayer.cornerSize
        cursorShape: Qt.SizeFDiagCursor; acceptedButtons: Qt.LeftButton
        onPressed: (m) => { if (m.button === Qt.LeftButton) WindowHelper.startSystemResize(resizeLayer.targetWindow, Qt.BottomEdge | Qt.RightEdge) }
    }
}
