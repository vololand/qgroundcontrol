import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Palette

Rectangle {
    id: root
    implicitHeight: mainLayout.implicitHeight + (mainLayout.anchors.margins * 2)
    color: qgcPal.window // QGC 기본 배경색 적용
    radius: ScreenTools.defaultFontPointSize * 0.5

    border.width: 1
    border.color: "#333"

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPointSize
        spacing: ScreenTools.defaultFontPointSize * 0.5

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: ScreenTools.defaultFontPixelHeight * 0.35
            columnSpacing: ScreenTools.defaultFontPixelWidth * 1.8

            // 데이터 값 공통 스타일 (글자 크기 통일)
            component DataLabel : QGCLabel {
                Layout.fillWidth: true
                font.family: ScreenTools.fixedFontFamily
                font.pointSize: ScreenTools.defaultFontPointSize
                color: qgcPal.text
            }

            // --- 1행 ---
            QGCLabel { text: qsTr("위도:") }
            DataLabel { text: "36.261515" }

            QGCLabel { text: qsTr("경도:") }
            DataLabel { text: "123.123123" }

            // --- 2행 ---
            QGCLabel { text: qsTr("고도:") }
            DataLabel { text: "120.5 m" }

            QGCLabel { text: qsTr("강우량:") }
            DataLabel { text: "0.0 mm" }

            // --- 3행 ---
            QGCLabel { text: qsTr("내부 온도:") }
            DataLabel { text: "32.5 ℃" }

            QGCLabel { text: qsTr("외부 온도:") }
            DataLabel { text: "12.4 ℃" }

            // --- 4행 ---
            QGCLabel { text: qsTr("내부 습도:") }
            DataLabel { text: "36 %" }

            QGCLabel { text: qsTr("외부 습도:") }
            DataLabel { text: "65 %" }

            // --- 5행 ---
            QGCLabel { text: qsTr("풍향:") }
            DataLabel { text: "216 °" }

            QGCLabel { text: qsTr("풍속:") }
            DataLabel { text: "13 m/s" }

            // --- 6행 ---
            QGCLabel { text: qsTr("도어:") }
            DataLabel { text: "열림" }

            QGCLabel { text: qsTr("리프트:") }
            DataLabel { text: "하강" }

            // --- 7행 ---
            QGCLabel { text: qsTr("센터링:") }
            DataLabel { text: "잠김" }

            QGCLabel { text: qsTr("충전:") }
            DataLabel { text: "ON" }

            // --- 8행 ---
            QGCLabel { text: qsTr("기체감지:") }
            DataLabel { text: "IN" }

            QGCLabel { text: qsTr("LED:") }
            DataLabel { text: "ON" }

            // --- 9행 ---
            QGCLabel { text: qsTr("난방기:") }
            DataLabel { text: "OFF" }

            QGCLabel { text: qsTr("냉방기:") }
            DataLabel { text: "ON" }

        }
    }
}
