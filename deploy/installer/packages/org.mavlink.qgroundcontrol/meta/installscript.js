function Component()
{

}

Component.prototype.createOperations = function()
{
    try {
        component.createOperations();
    } catch (e) {
    }

    if (systemInfo.productType === "windows") {
        component.addElevatedOperation("Execute", "msiexec", ["/i", "@TargetDir@/driver.msi", "/qn"]);

        // exe 이름은 CMake의 QGC_APP_NAME(=VololandVGcs) -> OUTPUT_NAME 으로 결정되어 VololandVGcs.exe 로 생성됨
        // 이전(QGC 기본값): component.addOperation("CreateShortcut", "@TargetDir@/bin/qgroundcontrol.exe", "@StartMenuDir@/QGroundControl.lnk");
        component.addOperation("CreateShortcut", "@TargetDir@/bin/VololandVGcs.exe", "@StartMenuDir@/VololandVGcs.lnk");
        // 이전(QGC 기본값): component.addOperation("CreateShortcut", "@TargetDir@/bin/qgroundcontrol.exe", "@DesktopDir@/QGroundControl.lnk");
        component.addOperation("CreateShortcut", "@TargetDir@/bin/VololandVGcs.exe", "@DesktopDir@/VololandVGcs.lnk");
    }
}
