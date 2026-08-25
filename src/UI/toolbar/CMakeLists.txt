qt_add_library(ToolbarModule STATIC)

set_source_files_properties(CustomToolbarMetrics.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(ToolbarModule
    URI QGroundControl.Toolbar
    VERSION 1.0
    RESOURCE_PREFIX /qml
    QML_FILES
        CustomToolbarMetrics.qml
        APMBatteryIndicator.qml
        APMFlightModeIndicator.qml
        APMMainStatusIndicatorContentItem.qml
        APMSupportForwardingIndicator.qml
        ArmedIndicator.qml
        CustomToolbar.qml
        CryptoAlertIndicator.qml
        CryptoAlertPopup.qml
        LoginPopup.qml
        UserInfoPopup.qml
        GCSControlIndicator.qml
        GimbalIndicator.qml
        JoystickIndicator.qml
        LinkIndicator.qml
        ModeIndicator.qml
        MultiVehicleSelector.qml
        RCRSSIIndicator.qml
        RemoteIDIndicator.qml
        RTKGPSIndicator.qml
        TelemetryRSSIIndicator.qml
        VehicleGPSIndicator.qml
        DroneControlPanel.qml
        DroneStatusMessage.qml
        FramelessWindowTitleBar.qml
        PanelButton.qml
        VideoTile.qml
        MultiViewGrid.qml
        MultiViewWindow.qml
        WindowResizeLayer.qml
        DroneVideo.qml
        StationControlPanel.qml
        StationStatusMessage.qml
        StationVideo.qml
    NO_PLUGIN # Required by Qt 6.6.3. TODO: Remove when no longer supported.
)
