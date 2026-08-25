import QtQuick 6.8
import QtQuick.Controls 6.8
import QtQuick.Layouts 6.8

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Palette

Rectangle {
    id: droneStatusMessageRoot
    implicitWidth:  parent ? parent.width : 300
    implicitHeight: 100
    color: "#252525"
    border.color: "#333"
    radius: 4

    // CustomFlyView에서 선택된 로컬기기(QGC Vehicle) 주입. 미선택 시 null.
    property var vehicle: null  // QGC Vehicle object

    QGCPalette {
        id: qgcPal
        colorGroupEnabled: true
    }

    function formatMessage(message) {
        message = String(message || "")
        message = message.replace(new RegExp("<#E>", "g"), "color: " + qgcPal.warningText + "; font: " + (ScreenTools.defaultFontPointSize.toFixed(0) - 1) + "pt monospace;")
        message = message.replace(new RegExp("<#I>", "g"), "color: " + qgcPal.warningText + "; font: " + (ScreenTools.defaultFontPointSize.toFixed(0) - 1) + "pt monospace;")
        message = message.replace(new RegExp("<#N>", "g"), "color: " + qgcPal.text + "; font: " + (ScreenTools.defaultFontPointSize.toFixed(0) - 1) + "pt monospace;")
        return message
    }

    function _reloadVehicleMessages() {
        // 선택 시점 이전 누적 메시지는 표시하지 않고 초기화만 수행
        messageText.text = ""
    }

    onVehicleChanged: {
        _reloadVehicleMessages()
    }

    Connections {
        target: droneStatusMessageRoot.vehicle
        function onNewFormattedMessage(formattedMessage) {
            messageText.insert(messageText.length, formatMessage(formattedMessage))
            messageText.cursorPosition = messageText.length
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: droneStatusMessageRoot.vehicle ? qsTr("기체 메시지") : qsTr("Messages")
                color: "#AAAAAA"
                font.pointSize: ScreenTools.smallFontPointSize
                font.bold: true
                Layout.fillWidth: true
            }

            // 메시지 초기화 버튼
            Rectangle {
                width: 16
                height: 16
                radius: 8
                color: clearArea.containsMouse ? "#555" : "transparent"
                visible: messageText.length > 0

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: "#AAAAAA"
                    font.pointSize: ScreenTools.smallFontPointSize
                }
                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        messageText.text = ""
                        if (droneStatusMessageRoot.vehicle)
                            droneStatusMessageRoot.vehicle.clearMessages()
                    }
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AlwaysOn

            TextArea {
                id: messageText
                readOnly: true
                textFormat: TextEdit.RichText
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                color: qgcPal.text
                placeholderText: qsTr("No Messages")
                placeholderTextColor: "#AAAAAA"
                padding: 0
                background: null
            }
        }
    }

    // MAVLink severity → 색상 (0=EMERGENCY ~ 7=DEBUG)
    function getSeverityColor(severity) {
        switch(severity) {
            case 0: case 1: case 2: return "#FF4444"  // 위험 (EMERGENCY/ALERT/CRITICAL)
            case 3: case 4:         return "#FFBB33"  // 경고 (ERROR/WARNING)
            default:                return "#FFFFFF"  // 일반 (NOTICE/INFO/DEBUG)
        }
    }

    // 외부에서 직접 메시지 추가 (Connections.onNewFormattedMessage에서 자동 호출)
    function addMessage(newText, severityValue) {
        var color = getSeverityColor(severityValue)
        var fontSize = ScreenTools.defaultFontPointSize.toFixed(0) - 1
        var escapedText = String(newText || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\n/g, "<br/>")
        var html = "<pre style=\"margin:0; white-space:pre-wrap; color:" + color + "; font:" + fontSize + "pt monospace;\">" + escapedText + "</pre>"
        messageText.insert(messageText.length, html)
        messageText.cursorPosition = messageText.length
    }
}
