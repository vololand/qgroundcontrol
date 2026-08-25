/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Palette
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.AppSettings

Rectangle {
    id:     settingsView
    color:  qgcPal.window
    z:      QGroundControl.zOrderTopMost

    readonly property real _defaultTextHeight:  ScreenTools.defaultFontPixelHeight
    readonly property real _defaultTextWidth:   ScreenTools.defaultFontPixelWidth
    readonly property real _horizontalMargin:   _defaultTextWidth / 2
    readonly property real _verticalMargin:     _defaultTextHeight / 2
    readonly property real _buttonHeight:       ScreenTools.isTinyScreen ? ScreenTools.defaultFontPixelHeight * 3 : ScreenTools.defaultFontPixelHeight * 2
    readonly property real _sidebarTargetWidth: mainWindow.sidebarTargetWidth
    readonly property real _buttonColumnWidth:  _sidebarTargetWidth - _horizontalMargin - 1

    property bool _first: true

    property bool _commingFromRIDSettings:  false

    function showSettingsPage(settingsPage) {
        for (var i=0; i<buttonRepeater.count; i++) {
            var button = buttonRepeater.itemAt(i)
            if (button.text === settingsPage) {
                button.clicked()
                break
            }
        }
    }

    // This need to block click event leakage to underlying map.
    DeadMouseArea {
        anchors.fill: parent
    }

    QGCPalette { id: qgcPal }

    Component.onCompleted: {
        //-- Default Settings
        if (globals.commingFromRIDIndicator) {
            rightPanel.source = "qrc:/qml/QGroundControl/AppSettings/RemoteIDSettings.qml"
            globals.commingFromRIDIndicator = false
        } else {
            rightPanel.source =  "qrc:/qml/QGroundControl/AppSettings/GeneralSettings.qml"
        }
    }


    SettingsPagesModel { id: settingsPagesModel }

    Item {
        id:             buttonArea
        anchors.left:   parent.left
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        width:          _sidebarTargetWidth

        QGCFlickable {
            id:                 buttonList
            width:              buttonColumn.width
            anchors.topMargin:  _verticalMargin
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            anchors.leftMargin: _horizontalMargin
            anchors.left:       parent.left
            contentHeight:      buttonColumn.height + _verticalMargin
            flickableDirection: Flickable.VerticalFlick
            clip:               true

            Column {
                id:         buttonColumn
                width:      Math.max(_maxButtonWidth, settingsView._buttonColumnWidth)
                spacing:    ScreenTools.defaultFontPixelHeight / 4

                property real _maxButtonWidth: 0

                Component.onCompleted: reflowWidths()
                onWidthChanged: reflowWidths()

                Connections {
                    target:         QGroundControl.settingsManager.appSettings.appFontPointSize
                    onValueChanged: buttonColumn.reflowWidths()
                }

                function reflowWidths() {
                    buttonColumn._maxButtonWidth = settingsView._buttonColumnWidth
                    for (var i = 0; i < children.length; i++) {
                        buttonColumn._maxButtonWidth = Math.max(buttonColumn._maxButtonWidth, children[i].implicitWidth)
                    }
                    for (var j = 0; j < children.length; j++) {
                        children[j].width = buttonColumn._maxButtonWidth
                    }
                }

                Repeater {
                    id:     buttonRepeater
                    model:  settingsPagesModel

                    SubMenuButton {
                        autoExclusive:  true
                        text:           name
                        imageResource:  iconUrl
                        visible:        pageVisible()

                        onClicked: {
                            if (mainWindow.allowViewSwitch()) {
                                if (rightPanel.source !== url) {
                                    rightPanel.source = url
                                }
                                checked = true
                            }
                        }

                        Component.onCompleted: {
                            if (globals.commingFromRIDIndicator) {
                                _commingFromRIDSettings = true
                            }
                            if(_first) {
                                _first = false
                                checked = true
                            }
                            if (_commingFromRIDSettings) {
                                checked = false
                                _commingFromRIDSettings = false
                                if (modelData.url == "qrc:/qml/QGroundControl/AppSettings/RemoteIDSettings.qml") {
                                    checked = true
                                }
                            }
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

    //-- Panel Contents
    Loader {
        id:                     rightPanel
        anchors.leftMargin:     _horizontalMargin
        anchors.rightMargin:    _horizontalMargin
        anchors.topMargin:      _verticalMargin
        anchors.bottomMargin:   _verticalMargin
        anchors.left:           buttonArea.right
        anchors.right:          parent.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
    }
}

