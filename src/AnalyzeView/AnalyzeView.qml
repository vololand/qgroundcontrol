/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Window
import QtQuick.Controls

import QGroundControl
import QGroundControl.Palette
import QGroundControl.Controls
import QGroundControl.Controllers
import QGroundControl.ScreenTools

Rectangle {
    id:     _root
    color:  qgcPal.window
    z:      QGroundControl.zOrderTopMost

    signal popout()

    readonly property real  _defaultTextHeight:     ScreenTools.defaultFontPixelHeight
    readonly property real  _defaultTextWidth:      ScreenTools.defaultFontPixelWidth
    readonly property real  _horizontalMargin:      _defaultTextWidth / 2
    readonly property real  _verticalMargin:        _defaultTextHeight / 2
    readonly property real  _buttonWidth:           _defaultTextWidth * 18
    readonly property real  _sidebarTargetWidth:    mainWindow.sidebarTargetWidth
    readonly property real  _buttonColumnWidth:     _sidebarTargetWidth - _horizontalMargin - 1

    // This need to block click event leakage to underlying map.
    DeadMouseArea {
        anchors.fill: parent
    }

    GeoTagController {
        id: geoController
    }

    Item {
        id:             buttonArea
        anchors.left:   parent.left
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        width:          _sidebarTargetWidth

        QGCFlickable {
            id:                 buttonScroll
            width:              buttonColumn.width
            anchors.topMargin:  _defaultTextHeight / 2
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            anchors.leftMargin: _horizontalMargin
            anchors.left:       parent.left
            contentHeight:      buttonColumn.height
            flickableDirection: Flickable.VerticalFlick
            clip:               true

            Column {
                id:         buttonColumn
                width:      Math.max(_maxButtonWidth, _root._buttonColumnWidth)
                spacing:    _defaultTextHeight / 2

                property real _maxButtonWidth: 0

                Component.onCompleted: reflowWidths()

                onWidthChanged: reflowWidths()

                Connections {
                    target:         QGroundControl.settingsManager.appSettings.appFontPointSize
                    onValueChanged: buttonColumn.reflowWidths()
                }

                function reflowWidths() {
                    buttonColumn._maxButtonWidth = _root._buttonColumnWidth
                    for (var i = 0; i < children.length; i++) {
                        buttonColumn._maxButtonWidth = Math.max(buttonColumn._maxButtonWidth, children[i].implicitWidth)
                    }
                    for (var j = 0; j < children.length; j++) {
                        children[j].width = buttonColumn._maxButtonWidth
                    }
                }

                Repeater {
                    id:     buttonRepeater
                    model:  QGroundControl.corePlugin ? QGroundControl.corePlugin.analyzePages : []

                    Component.onCompleted:  itemAt(0).checked = true

                    SubMenuButton {
                        id:                 subMenu
                        imageResource:      modelData.icon
                        autoExclusive:      true
                        text:               modelData.title

                        onClicked: {
                            panelLoader.source  = modelData.url
                            panelLoader.title   = modelData.title
                            checked             = true
                        }
                    }
                }
            }
        }

        Rectangle {
            id:                     divider
            anchors.topMargin:      _verticalMargin
            anchors.bottomMargin:   _verticalMargin
            anchors.right:          parent.right
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            width:                  1
            color:                  qgcPal.windowShade
        }
    }

    Loader {
        id:                     panelLoader
        anchors.topMargin:      _verticalMargin
        anchors.bottomMargin:   _verticalMargin
        anchors.leftMargin:     _horizontalMargin
        anchors.rightMargin:    _horizontalMargin
        anchors.left:           buttonArea.right
        anchors.right:          parent.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        source:                 "LogDownloadPage.qml"

        property string title

        Connections {
            target:     panelLoader.item
            onPopout:   mainWindow.createrWindowedAnalyzePage(panelLoader.title, panelLoader.source)
        }
    }
}
