/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include <QtQuick/QQuickWindow>
#include <QtWidgets/QApplication>

#ifdef Q_OS_MACOS
    #include <QtCore/QProcessEnvironment>
#endif

#include "QGCApplication.h"
#include "QGCLogging.h"
#include "CmdLineOptParser.h"
#include "SettingsManager.h"
#include "MavlinkSettings.h"

#include <QtQml/qqmlcontext.h>
#include <QtQml/qqmlapplicationengine.h>
#include "DroneModel/DroneManager.h"
#include "DroneModel/DroneModel.h"

#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS)
    #include <QtWidgets/QMessageBox>
    #include "RunGuard.h"
#endif

#ifdef Q_OS_ANDROID
    #include "AndroidInterface.h"
#endif

#ifdef Q_OS_LINUX
#ifndef Q_OS_ANDROID
    #include "SignalHandler.h"
#endif
#endif

#ifdef QT_DEBUG
#ifdef QGC_UNITTEST_BUILD
    #include "UnitTestList.h"
#endif

#ifdef Q_OS_WIN

#include <crtdbg.h>
#include <windows.h>
#include <iostream>

/// @brief CRT Report Hook installed using _CrtSetReportHook. We install this hook when
/// we don't want asserts to pop a dialog on windows.
int WindowsCrtReportHook(int reportType, char* message, int* returnValue)
{
    Q_UNUSED(reportType);

    std::cerr << message << std::endl;  // Output message to stderr
    *returnValue = 0;                   // Don't break into debugger
    return true;                        // We handled this fully ourselves
}

#endif // Q_OS_WIN

#endif // QT_DEBUG

//-----------------------------------------------------------------------------
/**
 * @brief Starts the application
 *
 * @param argc Number of commandline arguments
 * @param argv Commandline arguments
 * @return exit code, 0 for normal exit and !=0 for error cases
 */

int main(int argc, char *argv[])
{
    bool runUnitTests = false;
    bool simpleBootTest = false;
    QString systemIdStr = QString();
    bool hasSystemId = false;
    bool bypassRunGuard = false;

    bool stressUnitTests = false;       // Stress test unit tests
    bool quietWindowsAsserts = false;   // Don't let asserts pop dialog boxes
    QString unitTestOptions;

    CmdLineOpt_t rgCmdLineOptions[] = {
#ifdef QT_DEBUG
        { "--unittest",             &runUnitTests,          &unitTestOptions },
        { "--unittest-stress",      &stressUnitTests,       &unitTestOptions },
        { "--no-windows-assert-ui", &quietWindowsAsserts,   nullptr },
        { "--allow-multiple",       &bypassRunGuard,        nullptr },
#endif
        { "--system-id",            &hasSystemId,           &systemIdStr },
        { "--simple-boot-test",     &simpleBootTest,        nullptr },
        // Add additional command line option flags here
    };

    ParseCmdLineOptions(argc, argv, rgCmdLineOptions, std::size(rgCmdLineOptions), false);

#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS)
    // We make the runguard key different for custom and non custom
    // builds, so they can be executed together in the same device.
    // Stable and Daily have same QGC_APP_NAME so they would
    // not be able to run at the same time
    const QString runguardString = QStringLiteral("%1 RunGuardKey").arg(QGC_APP_NAME);

    RunGuard guard(runguardString);
    if (!bypassRunGuard && !guard.tryToRun()) {
        QApplication errorApp(argc, argv);
        QMessageBox::critical(nullptr, QObject::tr("Error"),
            QObject::tr("A second instance of %1 is already running. Please close the other instance and try again.").arg(QGC_APP_NAME)
        );
        return -1;
    }
#endif

#ifdef Q_OS_LINUX
#ifndef Q_OS_ANDROID
    if (getuid() == 0) {
        QApplication errorApp(argc, argv);
        QMessageBox::critical(nullptr, QObject::tr("Error"),
            QObject::tr("You are running %1 as root. "
                "You should not do this since it will cause other issues with %1."
                "%1 will now exit.<br/><br/>").arg(QGC_APP_NAME)
        );
        return -1;
    }
#endif
#endif

    // QML console.log / qDebug를 콘솔(디버그 출력)로 보내기 (VS 디버깅 시 출력 창에서 확인)
    if (!qEnvironmentVariableIsSet("QT_LOGGING_TO_CONSOLE")) {
        qputenv("QT_LOGGING_TO_CONSOLE", "1");
    }

    QGCLogging::installHandler();

    // RTSP 재생: Windows에서 WMF 대신 FFmpeg 백엔드 사용 (WMF는 RTSP 지원 약함)
    qputenv("QT_MEDIA_BACKEND", "ffmpeg");
    // RTSP 및 네스트 프로토콜 허용 (Could not open file 방지). 라이브 스트리밍은 DroneVideo에서 rtsp_transport=udp 사용.
    qputenv("QT_FFMPEG_PROTOCOL_WHITELIST", "file,crypto,rtp,udp,tcp,rtsp");
    // RTSP 재생 시 HW 디코딩(format 171 등) 실패 방지 — 소프트웨어 디코딩 강제
    qputenv("QT_FFMPEG_DECODING_HW_DEVICE_TYPES", "");
    // RTSP 연결 실패/디멕스 오류 원인 확인: 실행 전에 환경변수 QT_FFMPEG_DEBUG=1 설정 시 FFmpeg 상세 로그 출력

#ifdef Q_OS_MACOS
    // Prevent Apple's app nap from screwing us over
    // tip: the domain can be cross-checked on the command line with <defaults domains>
    QProcess::execute("defaults", {"write org.qgroundcontrol.qgroundcontrol NSAppSleepDisabled -bool YES"});
#endif

    // 다중 최상위 창(예: MultiView 창)에서 qml6glsink(GstGLQt6VideoItem) OpenGL 렌더링을 위해 창 간 GL 컨텍스트 공유 활성화.
    // 미설정 시 별도 창의 GstGLQt6VideoItem은 GStreamer GL 텍스처를 공유받지 못해 화면이 렌더되지 않는다(파이프라인은 정상).
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);

#ifdef Q_OS_WIN
    // Set our own OpenGL buglist
    // qputenv("QT_OPENGL_BUGLIST", ":/opengl/resources/opengl/buglist.json");

    // Allow for command line override of renderer
    for (int i = 0; i < argc; i++) {
        const QString arg(argv[i]);
        if (arg == QStringLiteral("-desktop")) {
            QCoreApplication::setAttribute(Qt::AA_UseDesktopOpenGL);
            break;
        } else if (arg == QStringLiteral("-swrast")) {
            QCoreApplication::setAttribute(Qt::AA_UseSoftwareOpenGL);
            break;
        }
    }
#endif

#ifdef QT_DEBUG
    if (stressUnitTests) {
        runUnitTests = true;
    }

#ifdef Q_OS_WIN
    if (!qEnvironmentVariableIsSet("QT_WIN_DEBUG_CONSOLE")) {
        qputenv("QT_WIN_DEBUG_CONSOLE", "attach"); // new
    }

    if (quietWindowsAsserts) {
        _CrtSetReportHook(WindowsCrtReportHook);
    }

    if (runUnitTests) {
        // Don't pop up Windows Error Reporting dialog when app crashes. This prevents TeamCity from
        // hanging.
        const DWORD dwMode = SetErrorMode(SEM_NOGPFAULTERRORBOX);
        SetErrorMode(dwMode | SEM_NOGPFAULTERRORBOX);
    }
#endif // Q_OS_WIN
#endif // QT_DEBUG

    QGCApplication app(argc, argv, runUnitTests, simpleBootTest);

#ifdef Q_OS_LINUX
#ifndef Q_OS_ANDROID
    SignalHandler::instance();
    (void) SignalHandler::setupSignalHandlers();
#endif
#endif

    app.init();

    //Custom input
    static DroneModel   droneModel;
    static DroneManager droneManager(&droneModel);

    auto* qmlEngine = app.qmlAppEngine();
    QQmlContext* ctx = qmlEngine->rootContext();

    ctx->setContextProperty("deviceListModel", &droneModel);
    ctx->setContextProperty("droneManager",    &droneManager);

    // Set system ID if specified via command line, for example --system-id:255
    if (hasSystemId) {
        bool ok;
        int systemId = systemIdStr.toInt(&ok);
        if (ok && systemId >= 1 && systemId <= 255) {  // MAVLink system IDs are 8-bit
            qDebug() << "Setting MAVLink System ID to:" << systemId;
            SettingsManager::instance()->mavlinkSettings()->gcsMavlinkSystemID()->setRawValue(systemId);
        } else {
            qDebug() << "Not setting MAVLink System ID. It must be between 0 and 255. Invalid system ID value:" << systemIdStr;
        }
    }

    int exitCode = 0;

#ifdef QGC_UNITTEST_BUILD
    if (runUnitTests) {
        exitCode = runTests(stressUnitTests, unitTestOptions);
    } else
#endif
    {
        #ifdef Q_OS_ANDROID
            AndroidInterface::checkStoragePermissions();
        #endif

        if (!simpleBootTest) {
            exitCode = app.exec();
        }
    }

    app.shutdown();

    qDebug() << "Exiting main";

    return exitCode;
}
