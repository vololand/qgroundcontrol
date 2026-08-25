import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl.ScreenTools
import QGroundControl.Vehicle
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.Palette

Rectangle {
    id:     root
    height: _currentItem ? valuesRect.y + valuesRect.height + (_margin * 2) : titleBar.y - titleBar.height + _margin
    color:  _currentItem ? _selectedCardColor : _cardColor
    radius: _radius
    opacity: _currentItem ? 1.0 : 0.88
    border.color: _currentItem ? _selectedBorderColor : _cardBorderColor
    border.width: 1

    signal clicked()

    property var rallyPoint ///< RallyPoint object associated with editor
    property var controller ///< RallyPointController

    property bool   _currentItem:       rallyPoint ? rallyPoint === controller.currentRallyPoint : false
    property color  _outerTextColor:    _currentItem ? "#ffffff" : "#e0e0e0"

    readonly property real  _margin:            ScreenTools.defaultFontPixelWidth / 2
    readonly property real  _radius:            ScreenTools.defaultFontPixelWidth / 2
    readonly property real  _titleHeight:       ScreenTools.defaultFontPixelHeight * 2
    readonly property color _cardColor:          "#151515"
    readonly property color _selectedCardColor:  "#252525"
    readonly property color _cardBorderColor:    "#333333"
    readonly property color _selectedBorderColor:"#00BFFF"
    readonly property color _panelItemColor:     "#151515"
    readonly property color _mutedIconColor:     "#AAAAAA"

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    Item {
        id:                 titleBar
        anchors.margins:    _margin
        anchors.top:        parent.top
        anchors.left:       parent.left
        anchors.right:      parent.right
        height:             _titleHeight

        MissionItemIndexLabel {
            id:                     indicator
            anchors.verticalCenter: parent.verticalCenter
            anchors.left:           parent.left
            label:                  "R"
            checked:                true
        }

        QGCLabel {
            anchors.leftMargin:     _margin
            anchors.left:           indicator.right
            anchors.verticalCenter: parent.verticalCenter
            text:                   qsTr("Rally Point")
            color:                  _outerTextColor
        }

        QGCColoredImage {
            id:                     hamburger
            anchors.rightMargin:    _margin
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter
            width:                  ScreenTools.defaultFontPixelWidth * 2
            height:                 width
            sourceSize.height:      height
            source:                 "qrc:/qmlimages/Hamburger.svg"
            color:                  _currentItem ? "#ffffff" : _mutedIconColor

            MouseArea {
                anchors.fill:   parent
                onClicked:      hamburgerMenu.popup()

                QGCMenu {
                    id: hamburgerMenu

                    QGCMenuItem {
                        text:           qsTr("Delete")
                        onTriggered:    controller.removePoint(rallyPoint)
                    }
                }
            }
        }
    } // Item - titleBar

    Rectangle {
        id:                 valuesRect
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        titleBar.bottom
        height:             valuesGrid.height + (_margin * 2)
        color:              _panelItemColor
        visible:            _currentItem
        radius:             _radius
        border.color:       _cardBorderColor
        border.width:       1

        GridLayout {
            id:                 valuesGrid
            anchors.margins:    _margin
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.top:        parent.top
            rowSpacing:         _margin
            columnSpacing:      _margin
            rows:               rallyPoint ? rallyPoint.textFieldFacts.length : 0
            flow:               GridLayout.TopToBottom

            Repeater {
                model: rallyPoint ? rallyPoint.textFieldFacts : 0
                QGCLabel {
                    text: modelData.name + ":"
                }
            }

            Repeater {
                model: rallyPoint ? rallyPoint.textFieldFacts : 0
                FactTextField {
                    Layout.fillWidth:   true
                    showUnits:          true
                    fact:               modelData
                }
            }
        } // GridLayout
    } // Rectangle
} // Rectangle
