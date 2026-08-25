import QtQuick
import QtQuick.Controls

import QGroundControl.ScreenTools

// [Custom] DroneControlPanel / StationControlPanel 에서 각각 인라인 component 로 중복 정의되던
// 패널 버튼을 공통화한 것. 시각/치수는 기존과 동일(디코딩된 값 그대로).
Button {
    id: panelBtn

    // 배경 최소 높이. 기존 controlRoot._buttonHeight 와 동일 기본값.
    property real buttonHeight: ScreenTools.defaultFontPixelHeight * 1.45

    topPadding:     ScreenTools.defaultFontPixelHeight * 0.2
    bottomPadding:  ScreenTools.defaultFontPixelHeight * 0.2
    leftPadding:    ScreenTools.defaultFontPixelWidth * 0.8
    rightPadding:   ScreenTools.defaultFontPixelWidth * 0.8
    font.pointSize: ScreenTools.defaultFontPointSize

    background: Rectangle {
        implicitHeight: panelBtn.buttonHeight
        color: !panelBtn.enabled ? "#2a2a2a"
              : (panelBtn.down ? "#2d2d2d" : (panelBtn.hovered ? "#3d3d3d" : "#333333"))
        border.color: "#555555"
        radius: 3
    }

    contentItem: Text {
        text:                   panelBtn.text
        font:                   panelBtn.font
        color:                  panelBtn.enabled ? "#e8e8e8" : "#888888"
        horizontalAlignment:    Text.AlignHCenter
        verticalAlignment:      Text.AlignVCenter
        elide:                  Text.ElideRight
    }
}
