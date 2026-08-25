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
import QtCore

import QGroundControl
import QGroundControl.ScreenTools

Item {
    property Window window

    property bool _enabled: !ScreenTools.isMobile && !ScreenTools.fakeMobile && QGroundControl.corePlugin.options.enableSaveMainWindowPosition

    Settings {
        id:         s
        category:   "MainWindowState"

        property int x
        property int y
        property int width
        property int height
        property int visibility
    }

    function _setDefaultDesktopWindowSize() {
        window.width = Math.min(250 * Screen.pixelDensity, Screen.width);
        window.height = Math.min(150 * Screen.pixelDensity, Screen.height);
    }

    function _desktopSafeMargin() {
        return ScreenTools.defaultFontPixelHeight * 4
    }

    function _maxSafeDesktopWidth() {
        return Math.max(window.minimumWidth, Screen.width - (_desktopSafeMargin() * 2))
    }

    function _maxSafeDesktopHeight() {
        return Math.max(window.minimumHeight, Screen.height - (_desktopSafeMargin() * 2))
    }

    function _clampDesktopWindowToScreen() {
        var maxWidth = _maxSafeDesktopWidth()
        var maxHeight = _maxSafeDesktopHeight()
        window.width = Math.min(window.width, maxWidth)
        window.height = Math.min(window.height, maxHeight)
        window.x = Math.max(0, Math.min(window.x, Screen.width - window.width))
        window.y = Math.max(0, Math.min(window.y, Screen.height - window.height))
    }

    function _setSafeDesktopWindowSize() {
        window.width = _maxSafeDesktopWidth()
        window.height = _maxSafeDesktopHeight()
        window.x = Math.max(0, Math.round((Screen.width - window.width) / 2))
        window.y = Math.max(0, Math.round((Screen.height - window.height) / 2))
        window.visibility = Window.Windowed
    }

    Component.onCompleted: {
        if (ScreenTools.fakeMobile) {
            window.width = ScreenTools.screenWidth
            window.height = ScreenTools.screenHeight
        } else if (ScreenTools.isMobile) {
            window.showFullScreen();
        } else if (QGroundControl.corePlugin.options.enableSaveMainWindowPosition) {
            window.minimumWidth = Math.min(ScreenTools.defaultFontPixelWidth * 100, Screen.width)
            window.minimumHeight = Math.min(ScreenTools.defaultFontPixelWidth * 50,
                                            Screen.height - (ScreenTools.defaultFontPixelHeight * 8))
            _setSafeDesktopWindowSize()
        } else {
            _setDefaultDesktopWindowSize()
        }
    }

    Connections {
        target:                         window
        function onXChanged()           { if(_enabled) saveSettingsTimer.restart() }
        function onYChanged()           { if(_enabled) saveSettingsTimer.restart() }
        function onWidthChanged()       { if(_enabled) saveSettingsTimer.restart() }
        function onHeightChanged()      { if(_enabled) saveSettingsTimer.restart() }
        function onVisibilityChanged()  { if(_enabled) saveSettingsTimer.restart() }
    }

    Timer {
        id:             saveSettingsTimer
        interval:       500
        repeat:         false
        onTriggered:    saveSettings()
    }

    function saveSettings() {
        if (_enabled) {
            switch(window.visibility) {
            case ApplicationWindow.Windowed:
                s.x = window.x;
                s.y = window.y;
                s.width = window.width;
                s.height = window.height;
                s.visibility = window.visibility;
                break;
            case ApplicationWindow.FullScreen:
                s.visibility = window.visibility;
                break;
            case ApplicationWindow.Maximized:
                s.visibility = window.visibility;
                break;
            }
        }
    }
}
