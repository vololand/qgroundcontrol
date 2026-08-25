pragma Singleton
import QtQuick
import QGroundControl.ScreenTools

/// CustomToolbar / CustomPlanViewToolBar 공통: 아이콘·버튼 크기, 간격, 마진 등 한곳에서 관리
QtObject {
    id: root

    // 툴바 레이아웃 (멀티뷰/유저정보와 동일하게 간격은 고정값 유지)
    readonly property real horizontalMargin: 10
    readonly property real spacing: 10
    readonly property real windowControlButtonsSpacing: 5

    // 좌측 메인 버튼(로고/툴 선택) — 멀티뷰/유저정보와 동일하게 툴바 높이에 비례
    readonly property real toolButtonSize: ScreenTools.toolbarHeight

    // 서버 연결 상태 아이콘 (Fly/Plan 툴바 동일 크기)
    readonly property real serverConnectionIconSize: 24

    // 윈도우 제어 버튼 (최소화/최대화/닫기) — 툴바 높이에 비례
    readonly property real windowControlButtonSize: ScreenTools.toolbarHeight * 2 / 3
    readonly property real windowControlButtonRadius: windowControlButtonSize / 10
    readonly property real windowControlMinimizeFontSize: windowControlButtonSize * 0.625
    readonly property real windowControlIconFontSize: windowControlButtonSize * 0.5
}
