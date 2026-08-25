import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.Palette

Rectangle {
    id:                 root
    width:              availableWidth
    height:             editorColumn.height + (_margin * 2)
    color:              qgcPal.windowShadeDark
    radius:             _radius

    // --- 커스텀용 속성 정의 ---
    property real _margin:          ScreenTools.defaultFontPixelHeight / 2
    property real _radius:          ScreenTools.defaultFontPixelWidth / 2
    property var  _missionItem:     missionItem // 명시적으로 참조 지정

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    Column {
        id:                 editorColumn
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        parent.top
        spacing:            _margin

        // [기능 1] 명령 설명 라벨
        QGCLabel {
            width:          parent.width
            wrapMode:       Text.WordWrap
            font.pointSize: ScreenTools.smallFontPointSize
            text:           _missionItem.commandDescription
        }

        // [기능 2] 고도 설정 섹션 (가장 많이 커스텀하는 부분)
        ColumnLayout {
            width:          parent.width
            spacing:        0
            visible:        _missionItem.specifiesAltitude

            RowLayout {
                QGCLabel { text: qsTr("Altitude"); font.pointSize: ScreenTools.smallFontPointSize }
                // 고도 모드 표시 (Relative, Absolute 등)
                QGCLabel {
                    id: altModeLabel
                    text: QGroundControl.altitudeModeShortDescription(_missionItem.altitudeMode)
                }
            }

            FactTextField {
                Layout.fillWidth:   true
                fact:               _missionItem.altitude
            }
        }

        // [기능 3] 동적 입력 필드 섹션 (아이템별 파라미터)
        GridLayout {
            width:              parent.width
            columns:            2
            rowSpacing:         _margin
            columnSpacing:      _margin

            // 텍스트 입력형 파라미터 (지연시간, 반경 등)
            Repeater {
                model: _missionItem.textFieldFacts
                QGCLabel { text: object.name }
            }
            Repeater {
                model: _missionItem.textFieldFacts
                FactTextField {
                    Layout.fillWidth: true
                    fact:             object
                }
            }
        }

        // [기능 4] 속도 제어 섹션
        RowLayout {
            width:      parent.width
            visible:    _missionItem.speedSection.available

            QGCCheckBox {
                id:      speedCheck
                text:    qsTr("Flight Speed")
                checked: _missionItem.speedSection.specifyFlightSpeed
                onClicked: _missionItem.speedSection.specifyFlightSpeed = checked
            }

            FactTextField {
                Layout.fillWidth: true
                fact:             _missionItem.speedSection.flightSpeed
                enabled:          speedCheck.checked
            }
        }

        // [기능 5] 카메라 설정 섹션 (사진 촬영, 녹화 등)
        CameraSection {
            width:      parent.width
            checked:    _missionItem.cameraSection.settingsSpecified
            visible:    _missionItem.cameraSection.available
        }
    }
}
