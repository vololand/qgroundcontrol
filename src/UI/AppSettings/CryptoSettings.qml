import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Palette

SettingsPage {
    id: root

    property var _crypto: QGroundControl.tngCryptoSettings

    readonly property var _providerList:  [ "tngcore", "mcml" ]
    readonly property bool _isMcm:        _crypto.provider === "mcml"
    readonly property var _algList:       _isMcm ? [ "LEA128", "LEA192", "LEA256" ] : [ "ARIA128", "ARIA256" ]
    readonly property var _modeList:      [ "ECB", "CBC", "CTR" ]
    readonly property var _keySourceList: [ "keystore_latest", "keystore_index", "hex" ]

    readonly property real _fieldWidth: ScreenTools.defaultFontPixelWidth * 28

    function _idx(list, value) {
        var i = list.indexOf(value)
        return i < 0 ? 0 : i
    }

    function saveSettings() {
        var providerVal = _providerList[providerCombo.currentIndex]
        var algVal      = _algList[algCombo.currentIndex]
        _crypto.enabled         = enabledSlider.checked
        _crypto.provider        = providerVal
        _crypto.alg             = algVal
        if (providerVal === "mcml") {
            _crypto.mode        = "CTR"
            _crypto.padding     = false
            _crypto.keySource   = "hex"
        } else {
            _crypto.mode        = _modeList[modeCombo.currentIndex]
            _crypto.padding     = paddingSlider.checked
            _crypto.keySource   = _keySourceList[keySourceCombo.currentIndex]
            _crypto.sysUnique   = sysUniqueField.text
            _crypto.packageId   = packageIdField.text
        }
        // UI 비노출 (기존 ini 값 보존). 필요 시 아래 두 줄과 해당 RowLayout 주석 해제.
        // _crypto.keystorePath    = keystorePathField.text
        // _crypto.libDir          = libDirField.text
        _crypto.failOnError     = failOnErrorSlider.checked
        _crypto.maxPayloadBytes = parseInt(maxPayloadField.text) || 2048
        savedLabel.visible = _crypto.save()
    }

    Component.onCompleted: {
        _crypto.reload()
        _crypto.refreshKeystore()
    }

    SettingsGroupLayout {
        /*
        Layout.fillWidth:   true
        heading:            qsTr("Encryption")
        headingDescription: qsTr("끄면 평문 TCP 통과 (테스트용). 변경은 Server 링크 재연결 후 적용됩니다.")
        */
        QGCCheckBoxSlider {
            id:                 enabledSlider
            Layout.fillWidth:   true
            text:               qsTr("Enable encryption")
            checked:            _crypto.enabled
            onToggled:          _crypto.enabled = checked
        }
    }

    SettingsGroupLayout {
        Layout.fillWidth:   true
        heading:            qsTr("Cipher")
        enabled:            enabledSlider.checked

        LabelledComboBox {
            id:                     providerCombo
            Layout.fillWidth:       true
            label:                  qsTr("Module")
            comboBoxPreferredWidth: _fieldWidth
            model:                  [ "tngCore", "MCM-L" ]
            currentIndex:           root._idx(root._providerList, _crypto.provider)
            onActivated:            (index) => {
                                        _crypto.provider = root._providerList[index]
                                        algCombo.currentIndex = root._idx(root._algList, _crypto.alg)
                                        _crypto.refreshKeystore()
                                    }
        }

        LabelledComboBox {
            id:                     algCombo
            Layout.fillWidth:       true
            label:                  qsTr("Algorithm")
            comboBoxPreferredWidth: _fieldWidth
            model:                  _algList
            currentIndex:           root._idx(root._algList, _crypto.alg)
            onActivated:            (index) => { _crypto.alg = root._algList[index] }
        }

        LabelledComboBox {
            id:                     modeCombo
            Layout.fillWidth:       true
            visible:                !root._isMcm
            label:                  qsTr("Mode")
            comboBoxPreferredWidth: _fieldWidth
            model:                  _modeList
            currentIndex:           root._idx(root._modeList, _crypto.mode)
            onActivated:            (index) => { _crypto.mode = root._modeList[index] }
        }

        QGCCheckBoxSlider {
            id:                 paddingSlider
            Layout.fillWidth:   true
            visible:            !root._isMcm
            text:               qsTr("Padding")
            checked:            _crypto.padding
            onToggled:          _crypto.padding = checked
        }
    }

    SettingsGroupLayout {
        Layout.fillWidth:   true
        heading:            qsTr("Key")
        enabled:            enabledSlider.checked

        LabelledComboBox {
            id:                     keySourceCombo
            Layout.fillWidth:       true
            visible:                !root._isMcm
            label:                  qsTr("Key source")
            comboBoxPreferredWidth: _fieldWidth
            model:                  _keySourceList
            currentIndex:           root._idx(root._keySourceList, _crypto.keySource)
            onActivated:            (index) => {
                                        _crypto.keySource = root._keySourceList[index]
                                        _crypto.refreshKeystore()
                                    }
        }

        // keystore_index: store/에 저장된 인덱스 목록에서 선택. 없으면 "존재하지 않음".
        RowLayout {
            Layout.fillWidth:   true
            visible:            !root._isMcm && keySourceCombo.currentIndex === 1 // keystore_index
            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("Key index")
            }
            QGCComboBox {
                id:                     keyIndexCombo
                Layout.preferredWidth:  _fieldWidth
                visible:                _crypto.savedKeys.length > 0
                model:                  _crypto.savedKeys
                textRole:               "label"
                valueRole:              "index"
                onActivated:            (index) => { _crypto.keyIndex = currentValue }
                Component.onCompleted:  currentIndex = indexOfValue(_crypto.keyIndex)
                Connections {
                    target: _crypto
                    function onKeystoreChanged() {
                        keyIndexCombo.currentIndex = keyIndexCombo.indexOfValue(_crypto.keyIndex)
                    }
                }
            }
            QGCLabel {
                Layout.preferredWidth:  _fieldWidth
                visible:                _crypto.savedKeys.length === 0
                text:                   qsTr("존재하지 않음")
                color:                  QGroundControl.globalPalette.warningText
            }
        }

        // keystore_latest: 가장 최근 저장된 키의 인덱스 표시.
        RowLayout {
            Layout.fillWidth:   true
            visible:            !root._isMcm && keySourceCombo.currentIndex === 0 // keystore_latest
            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("Latest key")
            }
            QGCLabel {
                Layout.preferredWidth:  _fieldWidth
                text:                   _crypto.latestIndex >= 1 ? qsTr("index %1").arg(_crypto.latestIndex)
                                                                 : qsTr("존재하지 않음")
                color:                  _crypto.latestIndex >= 1 ? QGroundControl.globalPalette.text
                                                                 : QGroundControl.globalPalette.warningText
            }
        }

        QGCLabel {
            Layout.fillWidth:   true
            visible:            root._isMcm
            wrapMode:           Text.WordWrap
            text:               qsTr("crypto.ini 경로에 key_hex, key_iv 값이 저장됩니다.")
        }

        // 삭제는 반드시 tngDestroyKey/tngDestroyAllKey로 해야 tngCore 내부 목록에서 빠진다.
        // (탐색기 폴더 삭제/복사는 내부 카운터를 갱신하지 않아 목록에 반영되지 않는다.)
        RowLayout {
            Layout.fillWidth:   true
            visible:            !root._isMcm
            spacing:            ScreenTools.defaultFontPixelWidth * 2

            /* 키 생성은 tngSaveKey 경로 확정 후 재사용 예정 — 임시 비활성화.
            QGCButton {
                text:       qsTr("키 생성 및 저장")
                onClicked:  _crypto.generateKey()
            }
            */

            QGCButton {
                text:       qsTr("목록 새로고침")
                onClicked:  _crypto.refreshKeystore()
            }

            QGCButton {
                text:       qsTr("선택 키 삭제")
                enabled:    _crypto.savedKeys.length > 0
                onClicked:  _crypto.deleteKey(keyIndexCombo.currentValue)
            }

            QGCButton {
                text:       qsTr("전체 삭제")
                enabled:    _crypto.savedKeys.length > 0
                onClicked:  deleteAllPrompt.visible = true
            }
        }

        RowLayout {
            id:                 deleteAllPrompt
            Layout.fillWidth:   true
            visible:            false
            enabled:            !root._isMcm
            spacing:            ScreenTools.defaultFontPixelWidth * 2

            QGCLabel {
                Layout.fillWidth:   true
                wrapMode:           Text.WordWrap
                color:              QGroundControl.globalPalette.warningText
                text:               qsTr("저장된 모든 키를 삭제합니다. 계속할까요?")
            }
            QGCButton {
                text:       qsTr("삭제")
                onClicked:  { deleteAllPrompt.visible = false; _crypto.deleteAllKeys() }
            }
            QGCButton {
                text:       qsTr("취소")
                onClicked:  deleteAllPrompt.visible = false
            }
        }

        QGCLabel {
            id:                 deleteResultLabel
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
            visible:            text.length > 0
            Connections {
                target: _crypto
                function onKeyDeleteResult(ok, message) {
                    deleteResultLabel.text  = message
                    deleteResultLabel.color = ok ? QGroundControl.globalPalette.colorGreen
                                                 : QGroundControl.globalPalette.warningText
                }
            }
        }
    }

    SettingsGroupLayout {
        Layout.fillWidth:   true
        visible:            !root._isMcm
        heading:            qsTr("tngCore")
        enabled:            enabledSlider.checked

        RowLayout {
            Layout.fillWidth:   true
            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("sys_unique")
            }
            QGCTextField {
                id:                     sysUniqueField
                Layout.preferredWidth:  _fieldWidth
                text:                   _crypto.sysUnique
            }
        }

        RowLayout {
            Layout.fillWidth:   true
            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("package_id")
            }
            QGCTextField {
                id:                     packageIdField
                Layout.preferredWidth:  _fieldWidth
                text:                   _crypto.packageId
            }
        }

        // UI 비노출 (기존 ini 값 보존). 필요 시 주석 해제하고 saveSettings()의 대응 줄도 함께 해제.
        /*
        RowLayout {
            Layout.fillWidth:   true
            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("keystore_path (비우면 tngCore 기본)")
            }
            QGCTextField {
                id:                     keystorePathField
                Layout.preferredWidth:  _fieldWidth
                text:                   _crypto.keystorePath
            }
        }

        RowLayout {
            Layout.fillWidth:   true
            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("lib_dir (. = 실행 폴더)")
            }
            QGCTextField {
                id:                     libDirField
                Layout.preferredWidth:  _fieldWidth
                text:                   _crypto.libDir
            }
        }
        */
    }

    SettingsGroupLayout {
        Layout.fillWidth:   true
        heading:            qsTr("Options")
        enabled:            enabledSlider.checked

        QGCCheckBoxSlider {
            id:                 failOnErrorSlider
            Layout.fillWidth:   true
            text:               qsTr("Disconnect on crypto error (fail_on_error)")
            checked:            _crypto.failOnError
            onToggled:          _crypto.failOnError = checked
        }

        RowLayout {
            Layout.fillWidth:   true
            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("max_payload_bytes")
            }
            QGCTextField {
                id:                     maxPayloadField
                Layout.preferredWidth:  _fieldWidth
                text:                   _crypto.maxPayloadBytes.toString()
                inputMethodHints:       Qt.ImhDigitsOnly
            }
        }
    }

    SettingsGroupLayout {
        Layout.fillWidth:   true
        showBorder:         false
/*
        QGCLabel {
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
            font.pointSize:     ScreenTools.smallFontPointSize
            text:               qsTr("파일: %1").arg(_crypto.iniFilePath)
        }
*/
        QGCLabel {
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
            color:              QGroundControl.globalPalette.warningText
            text:               qsTr("변경 사항은 저장 후 Server 링크를 재연결해야 적용됩니다.")
        }
        RowLayout {
            Layout.fillWidth:   true
            spacing:            ScreenTools.defaultFontPixelWidth * 2

            QGCButton {
                text:       qsTr("Save")
                onClicked:  root.saveSettings()
            }

            QGCLabel {
                id:         savedLabel
                visible:    false
                text:       qsTr("저장됨")
                color:      QGroundControl.globalPalette.colorGreen
            }
        }
    }
}
