import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Controls

QGCFlickable {
    height:         outerEditorRect.height
    contentHeight:  outerEditorRect.height
    clip:           true

    property var controller ///< RallyPointController

    readonly property real  _margin: ScreenTools.defaultFontPixelWidth / 2
    readonly property real  _radius: ScreenTools.defaultFontPixelWidth / 2
    readonly property color _panelCardColor:   "#252525"
    readonly property color _panelItemColor:   "#151515"
    readonly property color _panelBorderColor: "#333333"
    readonly property color _panelTextColor:   "#e0e0e0"

    Rectangle {
        id:     outerEditorRect
        width:  parent.width
        height: innerEditorRect.y + innerEditorRect.height + (_margin * 2)
        radius: _radius
        color:  _panelCardColor
        border.color: _panelBorderColor
        border.width: 1

        QGCLabel {
            id:                 editorLabel
            anchors.margins:    _margin
            anchors.left:       parent.left
            anchors.top:        parent.top
            text:               qsTr("Rally Points")
            color:              _panelTextColor
            font.bold:          true
        }

        Rectangle {
            id:                 innerEditorRect
            anchors.margins:    _margin
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.top:        editorLabel.bottom
            height:             infoLabel.height + (_margin * 2)
            color:              _panelItemColor
            radius:             _radius
            border.color:       _panelBorderColor
            border.width:       1

            QGCLabel {
                id:                 infoLabel
                anchors.margins:    _margin
                anchors.top:        parent.top
                anchors.left:       parent.left
                anchors.right:      parent.right
                wrapMode:           Text.WordWrap
                font.pointSize:     ScreenTools.smallFontPointSize
                color:              _panelTextColor
                text:               qsTr("Rally Points provide alternate landing points when performing a Return to Launch (RTL).")
            }

            /*
            QGCLabel {
                id:                 helpLabel
                anchors.margins:    _margin
                anchors.left:       parent.left
                anchors.right:      parent.right
                anchors.top:        infoLabel.bottom
                wrapMode:           Text.WordWrap
                text:               controller.supported ?
                                        qsTr("Click in the map to add new rally points.") :
                                        qsTr("This vehicle does not support Rally Points.")
            }
            */
        }
    }
}
