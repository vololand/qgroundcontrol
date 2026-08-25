qt_add_library(ManagementViewModule STATIC)

qt_add_qml_module(ManagementViewModule
    URI QGroundControl.ManagementView
    VERSION 1.0
    RESOURCE_PREFIX /qml
    QML_FILES
        ManagementView.qml
        ManagementLeftPanel.qml
        ManagementListPage.qml
        GroupAddPage.qml
        GroupEditPage.qml
        GroupDetailPage.qml
        UserAddPage.qml
        UserEditPage.qml
        UserDetailPage.qml
        AssetAddPage.qml
        AssetEditPage.qml
        AssetDetailPage.qml
    NO_PLUGIN
)
