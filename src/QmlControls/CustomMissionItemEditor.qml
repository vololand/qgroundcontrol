import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQml
import QtQuick.Layouts

import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Vehicle
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.Palette


/// Mission item edit control
Rectangle {
    id:             _root
    readonly property real _minRowHeight: ScreenTools.defaultFontPixelHeight * 2.5   // 터치/클릭 인식용 최소 행 높이
    readonly property real _maxExpandedHeight: ScreenTools.defaultFontPixelHeight * 18  // 확대 시 상한 → 일정 크기 유지
    // 기존(선택 시에만 펼침):
    // height:         Math.max(_currentItem ? (editorLoader.y + editorLoader.height + _innerMargin) : (topRowLayout.y + topRowLayout.height + _margin), _minRowHeight)
    //
    // 모든 아이템 항상 펼침
    height:         Math.max(editorLoader.y + editorLoader.height + _innerMargin, _minRowHeight)
    color:          _currentItem ? _selectedCardColor : _cardColor
    radius:         _radius
    opacity:        _currentItem ? 1.0 : 0.88
    border.width:   _readyForSave ? 1 : 2
    border.color:   _readyForSave ? (_currentItem ? _selectedBorderColor : _cardBorderColor) : qgcPal.warningText

    property var    map                 ///< Map control
    property var    masterController
    property var    missionItem         ///< MissionItem associated with this editor
    property bool   readOnly            ///< true: read only view, false: full editing view
    property var    listView            ///< ListView (for forceLayout after drop)

    signal clicked
    signal remove
    signal selectNextNotReadyItem

    property var    _masterController:          masterController
    property var    _missionController:         _masterController.missionController
    property bool   _currentItem:               missionItem.isCurrentItem
    property color  _outerTextColor:            _currentItem ? "#ffffff" : "#e0e0e0"
    property bool   _noMissionItemsAdded:       ListView.view.model.count === 1
    property real   _sectionSpacer:             ScreenTools.defaultFontPixelWidth / 2  // spacing between section headings
    property bool   _singleComplexItem:         _missionController.complexMissionItemNames.length === 1
    property bool   _readyForSave:              missionItem.readyForSaveState === VisualMissionItem.ReadyForSave

    readonly property color _cardColor:          "#151515"
    readonly property color _selectedCardColor:  "#252525"
    readonly property color _cardBorderColor:    "#333333"
    readonly property color _selectedBorderColor:"#00BFFF"
    readonly property color _mutedIconColor:     "#AAAAAA"

    readonly property real  _editFieldWidth:    Math.min(width - _innerMargin * 2, ScreenTools.defaultFontPixelWidth * 12)
    readonly property real  _margin:            ScreenTools.defaultFontPixelWidth / 2
    readonly property real  _innerMargin:       2
    readonly property real  _radius:            ScreenTools.defaultFontPixelWidth / 2
    readonly property real  _hamburgerSize:     commandPicker.height * 0.75
    readonly property real  _trashSize:         commandPicker.height * 0.75
    readonly property bool  _waypointsOnlyMode: QGroundControl.corePlugin.options.missionWaypointsOnly
    readonly property bool  _canReorder:        missionItem.sequenceNumber >= 2

    readonly property string _defaultMissionSettingsEditor: "qrc:/qml/QGroundControl/Controls/MissionSettingsEditor.qml"
    readonly property string _customMissionSettingsEditor: "qrc:/qml/QGroundControl/Controls/CustomMissionSettingEditor.qml"
    readonly property string _dragKey: "mission-item-reorder"
    /// 드래그 시작 시점의 모델 인덱스 (레퍼런스 비교 실패 대비)
    property int _dragStartIndex: -1
    /// 드래그가 한 번이라도 활성화됐는지 (onReleased 시점에 drag.active가 이미 false일 수 있어서 사용)
    property bool _dragWasActive: false

    Drag.active:    dragArea.drag.active
    Drag.source:    _root
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2
    Drag.keys:      [_dragKey]
    Drag.mimeData:  ({ "mission-item-reorder": "" })

    QGCPalette {
        id: qgcPal
        colorGroupEnabled: enabled
    }

    Rectangle {
        id:                     dragProxy
        width:                  _root.width
        height:                 topRowLayout.height + _margin * 2
        x:                      0
        y:                      0
        color:                  _selectedCardColor
        radius:                 _radius
        border.color:           _selectedBorderColor
        border.width:           1
        visible:                dragArea.drag.active
        enabled:                false   // 이벤트 투과 → 아래 DropArea가 히트되도록
        z:                      1000
        onVisibleChanged:       if (!visible) { x = 0; y = 0 }

        Row {
            anchors.fill:       parent
            anchors.margins:    _margin
            spacing:            _margin
            layoutDirection:    Qt.LeftToRight
            QGCLabel {
                text:                   missionItem.sequenceNumber
                color:                  _outerTextColor
                font.bold:              true
                anchors.verticalCenter: parent.verticalCenter
            }
            QGCLabel {
                text:                   missionItem.sequenceNumber === 0 ? "미션 시작" : missionItem.commandName
                color:                  _outerTextColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    DropArea {
        z:                      1500
        anchors.fill:           parent
        keys:                   [_dragKey]
        onEntered: (drag) => {
            if (drag.source === _root) return
            var toIdx = (typeof index !== "undefined") ? index : -1
            var isOurReorder = (drag.source._dragStartIndex !== undefined && drag.source._dragStartIndex >= 0) || (drag.source.missionItem !== undefined && drag.source.missionItem !== null)
            drag.accepted = toIdx >= 2 && isOurReorder
        }
        onExited: (drag) => {
            var toIdx = (typeof index !== "undefined") ? index : -1
        }
        onDropped: (drag) => {
            var toIdx = (typeof index !== "undefined") ? index : -1
            if (drag.source === _root) return
            var model = _missionController.visualItems
            if (!model) {
                return
            }
            var fromIdx = (drag.source._dragStartIndex !== undefined && drag.source._dragStartIndex >= 0)
                ? drag.source._dragStartIndex
                : -1
            var fromIdxSource = (fromIdx >= 0) ? "_dragStartIndex" : "loop"
            if (fromIdx < 0) {
                for (var i = 0; i < model.count; i++) {
                    if (model.get(i) === drag.source.missionItem) {
                        fromIdx = i
                        break
                    }
                }
            }
            var toIdx = (typeof index !== "undefined") ? index : -1
            if (fromIdx < 2 || toIdx < 2 || fromIdx === toIdx) {
                return
            }
            CustomMissionReorderHelper.moveVisualItem(_missionController, fromIdx, toIdx)
            if (listView && listView.forceLayout) {
                Qt.callLater(listView.forceLayout)
                var lv = listView
                Qt.callLater(function() { if (lv && lv.forceLayout) lv.forceLayout() })
            }
        }
    }

    Component {
        id: editPositionDialog

        EditPositionDialog {
            coordinate:             missionItem.isSurveyItem ?  missionItem.centerCoordinate : missionItem.coordinate
            onCoordinateChanged:    missionItem.isSurveyItem ?  missionItem.centerCoordinate = coordinate : missionItem.coordinate = coordinate
        }
    }

    RowLayout {
        id:                 topRowLayout
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        parent.top
        spacing:            _margin

        QGCLabel {
            Layout.alignment:       Qt.AlignVCenter
            text:                   missionItem.sequenceNumber
            color:                  _outerTextColor
            font.bold:              true
        }

        Rectangle {
            id:                     notReadyForSaveIndicator
            Layout.alignment:       Qt.AlignVCenter
            width:                  _hamburgerSize
            height:                 width
            border.width:           1
            border.color:           qgcPal.warningText
            color:                  "white"
            radius:                 width / 2
            visible:                !_readyForSave

            QGCLabel {
                id:                 readyForSaveLabel
                anchors.centerIn:   parent
                //: Indicator in Plan view to show mission item is not ready for save/send
                text:               qsTr("?")
                color:              qgcPal.warningText
                font.pointSize:     ScreenTools.smallFontPointSize
            }
        }

        Item {
            id:                     commandPicker
            Layout.alignment:       Qt.AlignVCenter
            Layout.preferredHeight: ScreenTools.implicitComboBoxHeight
            Layout.preferredWidth:  innerLayout.width
            height:                 ScreenTools.implicitComboBoxHeight
            width:                  innerLayout.width
            visible:                !commandLabel.visible

            RowLayout {
                id:                     innerLayout
                anchors.verticalCenter: parent.verticalCenter
                spacing:                _padding

                property real _padding: ScreenTools.comboBoxPadding

                QGCLabel { text: missionItem.sequenceNumber === 0 ? "미션 시작" : missionItem.commandName }

                QGCColoredImage {
                    height:             ScreenTools.defaultFontPixelWidth
                    width:              height
                    fillMode:           Image.PreserveAspectFit
                    smooth:             true
                    antialiasing:       true
                    color:              _outerTextColor
                    source:             "/qmlimages/arrow-down.png"
                }
            }

            QGCMouseArea {
                fillItem:   parent
                onClicked:  commandDialog.createObject(mainWindow).open()
            }

            Component {
                id: commandDialog

                MissionCommandDialog {
                    vehicle:                    masterController.controllerVehicle
                    missionItem:                _root.missionItem
                    map:                        _root.map
                    // FIXME: Disabling fly through commands doesn't work since you may need to change from an RTL to something else
                    flyThroughCommandsAllowed:  true //_missionController.flyThroughCommandsAllowed
                }
            }
        }

        QGCLabel {
            id:                     commandLabel
            Layout.alignment:       Qt.AlignVCenter
            width:                  commandPicker.width
            height:                 commandPicker.height
            visible:                !missionItem.isCurrentItem || !missionItem.isSimpleItem || _waypointsOnlyMode || missionItem.isTakeoffItem
            verticalAlignment:      Text.AlignVCenter
            text:                   missionItem.sequenceNumber === 0 ? "미션 시작" : missionItem.commandName
            color:                  _outerTextColor
        }

        Item { Layout.fillWidth: true }

        QGCColoredImage {
            id:                     deleteButton
            Layout.alignment:       Qt.AlignVCenter
            height:                 _hamburgerSize
            width:                  height
            sourceSize.height:      height
            fillMode:               Image.PreserveAspectFit
            mipmap:                 true
            smooth:                 true
            color:                  _currentItem ? "#ffffff" : _mutedIconColor
            visible:                _currentItem && missionItem.sequenceNumber !== 0
            source:                 "/res/TrashDelete.svg"

            QGCMouseArea {
                fillItem:   parent
                onClicked:  remove()
            }
        }
    }

    FocusScope {
        id:             currentItemScope
        anchors.top:    parent.top
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.margins: _margin
        height:         topRowLayout.height + _margin   // 상단 행만 덮어 고도/대기/비행속도 등 하단 편집 영역은 클릭·수정 가능
        z:              10

        MouseArea {
            id:                 dragArea
            anchors.fill:       parent
            anchors.rightMargin: _hamburgerSize + _margin * 2  // 삭제 버튼 영역은 제외해 클릭이 버튼에 전달되도록
            drag.target:       _canReorder ? (listView && listView.reorderDragTarget ? listView.reorderDragTarget : dragProxy) : null
            drag.axis:         Drag.YAxis
            drag.threshold:    Math.max(ScreenTools.defaultFontPixelWidth, 8)
            onPressed: {
                if (_canReorder) {
                    _root._dragStartIndex = (typeof index !== "undefined") ? index : -1
                    _root._dragWasActive = true  // onReleased/오버레이 onDropped에서 사용; MouseArea에는 onDragActiveChanged 없음
                }
            }
            onReleased: (mouse) => {
                if (!_canReorder || _root._dragStartIndex < 0 || !_root._dragWasActive) {
                    _root._dragStartIndex = -1
                    _root._dragWasActive = false
                    return
                }
                var fromIdx = _root._dragStartIndex
                var toIdx = -1
                var lv = _root.listView
                var p = Qt.point(0, 0)
                if (lv && lv.contentItem) {
                    p = dragArea.mapToItem(lv.contentItem, mouse.x, mouse.y)
                    toIdx = lv.indexAt(p.x, p.y)
                }
                if (toIdx < 2 || fromIdx === toIdx) {
                    _root._dragStartIndex = -1
                    _root._dragWasActive = false
                    return
                }
                if (_missionController && typeof CustomMissionReorderHelper !== "undefined" && CustomMissionReorderHelper.moveVisualItem) {
                    CustomMissionReorderHelper.moveVisualItem(_missionController, fromIdx, toIdx)
                    if (lv && lv.forceLayout) {
                        Qt.callLater(lv.forceLayout)
                        Qt.callLater(function() { if (lv && lv.forceLayout) lv.forceLayout() })
                    }
                }
                _root._dragStartIndex = -1
                _root._dragWasActive = false
            }
            onClicked: {
                if (!dragArea.drag.active && mainWindow.allowViewSwitch()) {
                    currentItemScope.focus = true
                    _root.clicked()
                }
            }
        }
    }

/*
    Component {
        id: hamburgerMenuDropPanelComponent

        DropPanel {
            id: hamburgerMenuDropPanel

            sourceComponent: Component {
                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 2

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Move to vehicle position")
                        enabled:            _activeVehicle && missionItem.specifiesCoordinate

                        onClicked: {
                            missionItem.coordinate = _activeVehicle.coordinate
                            hamburgerMenuDropPanel.close()
                        }

                        property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Move to previous item position")
                        enabled:            _missionController.previousCoordinate.isValid
                        onClicked: {
                            missionItem.coordinate = _missionController.previousCoordinate
                            hamburgerMenuDropPanel.close()
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Edit position...")
                        enabled:            missionItem.specifiesCoordinate
                        onClicked: {
                            editPositionDialog.createObject(mainWindow).open()
                            hamburgerMenuDropPanel.close()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: 1
                        color:                  qgcPal.groupBorder
                    }

                    QGCCheckBoxSlider {
                        Layout.fillWidth:   true
                        text:               qsTr("Show all values")
                        visible:            QGroundControl.corePlugin.showAdvancedUI
                        checked:            missionItem.isSimpleItem ? missionItem.rawEdit : false
                        enabled:            missionItem.isSimpleItem && !_waypointsOnlyMode

                        onClicked: {
                            missionItem.rawEdit = checked
                            if (missionItem.rawEdit && !missionItem.friendlyEditAllowed) {
                                missionItem.rawEdit = false
                                checked = false
                                mainWindow.showMessageDialog(qsTr("Mission Edit"), qsTr("You have made changes to the mission item which cannot be shown in Simple Mode"))
                            }
                            hamburgerMenuDropPanel.close()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: 1
                        color:                  qgcPal.groupBorder
                    }

                    QGCLabel {
                        text:       qsTr("Item #%1").arg(missionItem.sequenceNumber)
                        enabled:    false
                    }
                }
            }
        }
    }


    QGCColoredImage {
        id:                     hamburger
        anchors.margins:        _margin
        anchors.right:          parent.right
        anchors.verticalCenter: topRowLayout.verticalCenter
        width:                  _hamburgerSize
        height:                 _hamburgerSize
        sourceSize.height:      _hamburgerSize
        source:                 "qrc:/qmlimages/Hamburger.svg"
        visible:                missionItem.isCurrentItem && missionItem.sequenceNumber !== 0
        color:                  qgcPal.text

        QGCMouseArea {
            fillItem:   hamburger
            onClicked: (position) => {
                currentItemScope.focus = true
                position = Qt.point(position.x, position.y)
                // For some strange reason using mainWindow in mapToItem doesn't work, so we use globals.parent instead which also gets us mainWindow
                position = mapToItem(globals.parent, position)
                var dropPanel = hamburgerMenuDropPanelComponent.createObject(mainWindow, { clickRect: Qt.rect(position.x, position.y, 0, 0) })
                dropPanel.open()
            }
        }
    }
*/
    /*
    QGCLabel {
        id:                     notReadyForSaveLabel
        anchors.margins:        _margin
        anchors.left:           notReadyForSaveIndicator.right
        anchors.right:          parent.right
        anchors.top:            commandPicker.bottom
        visible:                _currentItem && !_readyForSave
        text:                   missionItem.readyForSaveState === VisualMissionItem.NotReadyForSaveTerrain ?
                                    qsTr("Incomplete: Waiting on terrain data.") :
                                    qsTr("Incomplete: Item not fully specified.")
        wrapMode:               Text.WordWrap
        horizontalAlignment:    Text.AlignHCenter
        color:                  qgcPal.warningText
    }

*/

    Loader {
        id:                 editorLoader
        anchors.margins:    _innerMargin
        anchors.left:       parent.left
        anchors.top:        topRowLayout.bottom
        // 기존(선택 시에만 로드):
        // source:             _currentItem ? (missionItem.editorQml === _defaultMissionSettingsEditor ? _customMissionSettingsEditor : missionItem.editorQml) : ""
        //
        // 모든 아이템 항상 상세 로드
        source:             missionItem.editorQml === _defaultMissionSettingsEditor ? _customMissionSettingsEditor : missionItem.editorQml
        asynchronous:       true

        property var    masterController:   _masterController
        property real   availableWidth:     _root.width - (anchors.margins * 2) ///< How wide the editor should be
        property var    editorRoot:         _root
    }
} // Rectangle
