import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Palette

GridLayout {
    columns:        2
    rowSpacing:     _rowSpacing
    columnSpacing:  _colSpacing

    function saveSettings() {
        subEditConfig.host = hostField.text
        subEditConfig.port = parseInt(portField.text)
        subEditConfig.mode = modeCombo.currentIndex
    }

    QGCLabel { text: qsTr("Mode") }
    QGCComboBox {
        id:                     modeCombo
        Layout.preferredWidth:  _secondColumnWidth
        model:                  [ qsTr("Client"), qsTr("Server") ]
        currentIndex:           subEditConfig.mode
    }

    QGCLabel { text: qsTr("Host Address") }
    QGCTextField {
        id:                     hostField
        Layout.preferredWidth:  _secondColumnWidth
        text:                   subEditConfig.host
    }

    QGCLabel { text: qsTr("Port") }
    QGCTextField {
        id:                     portField
        Layout.preferredWidth:  _secondColumnWidth
        text:                   subEditConfig.port.toString()
        inputMethodHints:       Qt.ImhFormattedNumbersOnly
    }
}
