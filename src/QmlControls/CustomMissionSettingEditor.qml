import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.Palette

Rectangle {
    id:          valuesRect
    width:       Math.max(availableWidth, _minContentWidth)
    height:      Math.max(valuesColumn.height + (_margin * 2), _minContentHeight)
    color:       "#151515"
    // visible:     missionItem.isCurrentItem
    radius:      _radius
    border.width: 1
    border.color: "#333333"

    property real _margin:           ScreenTools.defaultFontPixelWidth / 2
    property real _fieldWidth:       ScreenTools.defaultFontPixelWidth * 16
    property real _radius:           ScreenTools.defaultFontPixelWidth / 2

    readonly property real _minContentHeight: ScreenTools.defaultFontPixelHeight * 10
    readonly property real _minContentWidth:  ScreenTools.defaultFontPixelWidth * 20
    QGCPalette { id: qgcPal }

    ColumnLayout {
        id:                 valuesColumn
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        parent.top
        spacing:            _margin

        QGCLabel {
            text:           "미션 시작"
            font.pointSize:  ScreenTools.smallFontPointSize
            font.bold:       true
        }

        RowLayout {
            Layout.fillWidth:   true
            spacing:            _margin

            QGCLabel {
                text:                   "초기 고도"
                font.pointSize:         ScreenTools.smallFontPointSize
                Layout.preferredWidth: _fieldWidth * 0.6
                Layout.minimumWidth:   ScreenTools.defaultFontPixelWidth * 6
            }

            FactTextField {
                fact:                   QGroundControl.settingsManager.appSettings.defaultMissionItemAltitude
                Layout.fillWidth:       true
                Layout.minimumWidth:    ScreenTools.defaultFontPixelWidth * 8
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2
            }
        }
        RowLayout{

            Layout.fillWidth:   true
            spacing:            _margin

            QGCCheckBox{
                id: flightSpeedCheckBox
                text: qsTr("비행 속도")
                visible: true
                checked:    missionItem.speedSection.specifyFlightSpeed
                onClicked:   missionItem.speedSection.specifyFlightSpeed = checked
            }

            FactTextField {
                Layout.fillWidth:   true
                fact:               missionItem.speedSection.flightSpeed
                visible:            true
                enabled:            flightSpeedCheckBox.checked
            }

        }

        Item { Layout.preferredHeight: _margin }
    }
}
