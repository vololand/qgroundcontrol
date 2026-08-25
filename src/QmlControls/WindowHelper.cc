/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "WindowHelper.h"
#include <QtQuick/QQuickWindow>
#include <QtQuick/QQuickItem>
#include <QtGui/QWindow>
#include <QtGui/QScreen>
#include <QtCore/QRect>
#include <QtCore/QString>
#include <QtCore/QDebug>
#include <QtCore/Qt>

#ifdef Q_OS_WIN
#include <windows.h>
#include <QtGui/QGuiApplication>
#endif

WindowHelper::WindowHelper(QObject* parent)
    : QObject(parent)
{
}

void WindowHelper::startSystemMove(QObject* window, int mouseX, int mouseY)
{
    QWindow* qWindow = nullptr;
    
    // QML ApplicationWindow는 QQuickWindow를 상속받으므로 직접 캐스팅
    if (auto* quickWindow = qobject_cast<QQuickWindow*>(window)) {
        qWindow = quickWindow;
    } 
    // QQuickItem에서 window()를 통해 QWindow 얻기
    else if (auto* item = qobject_cast<QQuickItem*>(window)) {
        if (item->window()) {
            qWindow = item->window();
        }
    }
    // 직접 QWindow인 경우
    else if (auto* windowObj = qobject_cast<QWindow*>(window)) {
        qWindow = windowObj;
    }
    
    if (qWindow) {
        #ifdef Q_OS_WIN
        // Windows 네이티브 드래그 시작
        #if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
        // Qt 6.5+에서는 startSystemMove() 사용
        qWindow->startSystemMove();
        #elif QT_VERSION >= QT_VERSION_CHECK(5, 15, 0)
        // Qt 5.15-6.4에서는 startSystemMove() 사용
        qWindow->startSystemMove();
        #else
        // 구버전 Qt에서는 Win32 API 사용
        // Qt6에서도 winId()는 여전히 작동합니다 (WId 타입)
        HWND hwnd = reinterpret_cast<HWND>(qWindow->winId());
        if (hwnd) {
            ReleaseCapture();
            SendMessage(hwnd, WM_SYSCOMMAND, SC_MOVE | HTCAPTION, 0);
        }
        Q_UNUSED(mouseX)
        Q_UNUSED(mouseY)
        #endif
        #else
        // Linux/macOS에서는 일반 드래그 사용
        Q_UNUSED(mouseX)
        Q_UNUSED(mouseY)
        #endif
    }
}

void WindowHelper::showSystemMenu(QObject* window, int x, int y)
{
    QWindow* qWindow = nullptr;
    
    // QML ApplicationWindow는 QQuickWindow를 상속받으므로 직접 캐스팅
    if (auto* quickWindow = qobject_cast<QQuickWindow*>(window)) {
        qWindow = quickWindow;
    } 
    // QQuickItem에서 window()를 통해 QWindow 얻기
    else if (auto* item = qobject_cast<QQuickItem*>(window)) {
        if (item->window()) {
            qWindow = item->window();
        }
    }
    // 직접 QWindow인 경우
    else if (auto* windowObj = qobject_cast<QWindow*>(window)) {
        qWindow = windowObj;
    }
    
    if (qWindow) {
        #ifdef Q_OS_WIN
        // Windows 네이티브 시스템 메뉴 표시 (Win32 API 사용)
        // Qt6에서도 winId()는 여전히 작동합니다 (WId 타입)
        HWND hwnd = reinterpret_cast<HWND>(qWindow->winId());
        if (hwnd) {
            HMENU hMenu = GetSystemMenu(hwnd, FALSE);
            
            // 프레임리스 윈도우에서는 시스템 메뉴가 없을 수 있으므로 수동 생성
            bool menuCreated = false;
            if (!hMenu) {
                hMenu = CreatePopupMenu();
                menuCreated = true;
                
                // 메뉴 항목 추가 (Windows 표준 시스템 메뉴 항목)
                AppendMenu(hMenu, MF_STRING, SC_RESTORE, L"Restore");
                AppendMenu(hMenu, MF_SEPARATOR, 0, nullptr);
                AppendMenu(hMenu, MF_STRING, SC_MOVE, L"Move");
                AppendMenu(hMenu, MF_STRING, SC_SIZE, L"Size");
                AppendMenu(hMenu, MF_STRING, SC_MINIMIZE, L"Minimize");
                AppendMenu(hMenu, MF_STRING, SC_MAXIMIZE, L"Maximize");
                AppendMenu(hMenu, MF_SEPARATOR, 0, nullptr);
                AppendMenu(hMenu, MF_STRING, SC_CLOSE, L"Close");
            }
            
            if (hMenu) {
                // 시스템 메뉴 항목 활성화/비활성화 설정
                bool isMaximized = (qWindow->windowState() == Qt::WindowMaximized);
                
                if (isMaximized) {
                    EnableMenuItem(hMenu, SC_RESTORE, MF_ENABLED);
                    EnableMenuItem(hMenu, SC_MOVE, MF_GRAYED);
                    EnableMenuItem(hMenu, SC_SIZE, MF_GRAYED);
                    EnableMenuItem(hMenu, SC_MINIMIZE, MF_ENABLED);
                    EnableMenuItem(hMenu, SC_MAXIMIZE, MF_GRAYED);
                } else {
                    EnableMenuItem(hMenu, SC_RESTORE, MF_GRAYED);
                    EnableMenuItem(hMenu, SC_MOVE, MF_ENABLED);
                    EnableMenuItem(hMenu, SC_SIZE, MF_ENABLED);
                    EnableMenuItem(hMenu, SC_MINIMIZE, MF_ENABLED);
                    EnableMenuItem(hMenu, SC_MAXIMIZE, MF_ENABLED);
                }
                EnableMenuItem(hMenu, SC_CLOSE, MF_ENABLED);
                
                // 메뉴 표시
                qDebug() << "WindowHelper::showSystemMenu - Showing menu at" << x << y;
                int cmd = TrackPopupMenu(hMenu, TPM_RETURNCMD | TPM_NONOTIFY, x, y, 0, hwnd, nullptr);
                if (cmd) {
                    qDebug() << "WindowHelper::showSystemMenu - Command selected:" << cmd;
                    PostMessage(hwnd, WM_SYSCOMMAND, cmd, 0);
                }
                
                // 수동으로 생성한 메뉴는 삭제
                if (menuCreated) {
                    DestroyMenu(hMenu);
                }
            } else {
                qWarning() << "WindowHelper::showSystemMenu - Failed to create system menu";
            }
        } else {
            qWarning() << "WindowHelper::showSystemMenu - Failed to get HWND from window";
        }
        #else
        // Linux/macOS에서는 시스템 메뉴 미지원
        Q_UNUSED(x)
        Q_UNUSED(y)
        #endif
    } else {
        qWarning() << "WindowHelper::showSystemMenu - Failed to get QWindow from object";
    }
}

void WindowHelper::toggleMaximizeRestore(QObject* window)
{
    qDebug() << "WindowHelper::toggleMaximizeRestore - Called";
    QWindow* qWindow = nullptr;
    
    // QML ApplicationWindow는 QQuickWindow를 상속받으므로 직접 캐스팅
    if (auto* quickWindow = qobject_cast<QQuickWindow*>(window)) {
        qWindow = quickWindow;
        qDebug() << "WindowHelper::toggleMaximizeRestore - Got QQuickWindow";
    } 
    // QQuickItem에서 window()를 통해 QWindow 얻기
    else if (auto* item = qobject_cast<QQuickItem*>(window)) {
        if (item->window()) {
            qWindow = item->window();
            qDebug() << "WindowHelper::toggleMaximizeRestore - Got QWindow from QQuickItem";
        }
    }
    // 직접 QWindow인 경우
    else if (auto* windowObj = qobject_cast<QWindow*>(window)) {
        qWindow = windowObj;
        qDebug() << "WindowHelper::toggleMaximizeRestore - Got QWindow directly";
    }
    
    if (qWindow) {
        qDebug() << "WindowHelper::toggleMaximizeRestore - Current windowState:" << qWindow->windowState();
        // 프레임리스 윈도우에서는 WM_SYSCOMMAND가 제대로 작동하지 않을 수 있으므로
        // Qt 함수를 직접 사용하는 것이 더 확실함
        // Windows의 기본 동작과 동일하게 최대화/복원 토글
        if (qWindow->windowState() == Qt::WindowMaximized) {
            qDebug() << "WindowHelper::toggleMaximizeRestore - Calling showNormal()";
            qWindow->showNormal();
        } else {
            qDebug() << "WindowHelper::toggleMaximizeRestore - Calling showMaximized()";
            qWindow->showMaximized();
        }
    } else {
        qWarning() << "WindowHelper::toggleMaximizeRestore - Failed to get QWindow from object";
    }
}

void WindowHelper::handleAeroSnap(QObject* window, int mouseX, int mouseY)
{
    qDebug() << "WindowHelper::handleAeroSnap - Called with mouseX:" << mouseX << "mouseY:" << mouseY;
    QWindow* qWindow = nullptr;
    
    // QML ApplicationWindow는 QQuickWindow를 상속받으므로 직접 캐스팅
    if (auto* quickWindow = qobject_cast<QQuickWindow*>(window)) {
        qWindow = quickWindow;
    } 
    // QQuickItem에서 window()를 통해 QWindow 얻기
    else if (auto* item = qobject_cast<QQuickItem*>(window)) {
        if (item->window()) {
            qWindow = item->window();
        }
    }
    // 직접 QWindow인 경우
    else if (auto* windowObj = qobject_cast<QWindow*>(window)) {
        qWindow = windowObj;
    }
    
    if (!qWindow) {
        qWarning() << "WindowHelper::handleAeroSnap - Failed to get QWindow from object";
        return;
    }
    
    #ifdef Q_OS_WIN
    // Windows에서만 Aero Snap 지원
    // 화면 가장자리 감지 임계값 (픽셀)
    const int snapThreshold = 10;
    
    // 마우스 위치가 속한 화면 찾기 (다중 모니터 지원)
    QScreen* targetScreen = nullptr;
    QList<QScreen*> screens = QGuiApplication::screens();
    
    for (QScreen* screen : screens) {
        QRect screenGeometry = screen->geometry();
        if (screenGeometry.contains(mouseX, mouseY)) {
            targetScreen = screen;
            break;
        }
    }
    
    // 마우스 위치가 어떤 화면에도 속하지 않으면 현재 창의 화면 사용
    if (!targetScreen) {
        targetScreen = qWindow->screen();
        if (!targetScreen) {
            targetScreen = QGuiApplication::primaryScreen();
        }
    }
    
    if (!targetScreen) {
        qWarning() << "WindowHelper::handleAeroSnap - Failed to get screen";
        return;
    }
    
    QRect screenGeometry = targetScreen->geometry();
    int screenWidth = screenGeometry.width();
    int screenX = screenGeometry.x();
    int screenY = screenGeometry.y();

    // 가장자리 감지는 모니터 전체(geometry) 기준으로 하되, 스냅 후 창 크기는 작업표시줄을
    // 제외한 작업영역(availableGeometry) 기준으로 잡는다. geometry(모니터 전체 높이)로 크기를
    // 잡으면 하단이 작업표시줄 아래로 내려가 가려진다. (작업표시줄이 어느 변에 있든 대응)
    const QRect workArea = targetScreen->availableGeometry();
    
    qDebug() << "WindowHelper::handleAeroSnap - Screen geometry:" << screenGeometry;
    qDebug() << "WindowHelper::handleAeroSnap - Mouse position:" << mouseX << mouseY;
    
    // 화면 좌표로 변환 (다중 모니터 고려)
    int relativeX = mouseX - screenX;
    int relativeY = mouseY - screenY;
    
    // 상단 가장자리 감지 (최대화)
    if (relativeY <= snapThreshold && relativeY >= 0) {
        qDebug() << "WindowHelper::handleAeroSnap - Top edge detected, maximizing";
        qWindow->showMaximized();
        return;
    }
    
    // 좌측 가장자리 감지 (좌반 화면)
    if (relativeX <= snapThreshold && relativeX >= 0) {
        qDebug() << "WindowHelper::handleAeroSnap - Left edge detected, snapping to left half";
        qWindow->showNormal();
        qWindow->setGeometry(workArea.x(), workArea.y(), workArea.width() / 2, workArea.height());
        return;
    }
    
    // 우측 가장자리 감지 (우반 화면)
    if (relativeX >= screenWidth - snapThreshold && relativeX <= screenWidth) {
        qDebug() << "WindowHelper::handleAeroSnap - Right edge detected, snapping to right half";
        qWindow->showNormal();
        qWindow->setGeometry(workArea.x() + workArea.width() / 2, workArea.y(), workArea.width() / 2, workArea.height());
        return;
    }
    
    qDebug() << "WindowHelper::handleAeroSnap - No snap area detected";
    #else
    // Linux/macOS에서는 Aero Snap 미지원
    Q_UNUSED(mouseX)
    Q_UNUSED(mouseY)
    #endif
}

void WindowHelper::handleAeroSnapShortcut(QObject* window, const QString& direction)
{
    qDebug() << "WindowHelper::handleAeroSnapShortcut - Called with direction:" << direction;
    QWindow* qWindow = nullptr;
    
    // QML ApplicationWindow는 QQuickWindow를 상속받으므로 직접 캐스팅
    if (auto* quickWindow = qobject_cast<QQuickWindow*>(window)) {
        qWindow = quickWindow;
    } 
    // QQuickItem에서 window()를 통해 QWindow 얻기
    else if (auto* item = qobject_cast<QQuickItem*>(window)) {
        if (item->window()) {
            qWindow = item->window();
        }
    }
    // 직접 QWindow인 경우
    else if (auto* windowObj = qobject_cast<QWindow*>(window)) {
        qWindow = windowObj;
    }
    
    if (!qWindow) {
        qWarning() << "WindowHelper::handleAeroSnapShortcut - Failed to get QWindow from object";
        return;
    }
    
    #ifdef Q_OS_WIN
    // Windows에서만 Aero Snap 단축키 지원
    QScreen* screen = qWindow->screen();
    if (!screen) {
        screen = QGuiApplication::primaryScreen();
    }
    
    if (!screen) {
        qWarning() << "WindowHelper::handleAeroSnapShortcut - Failed to get screen";
        return;
    }
    
    // 스냅 크기는 작업표시줄을 제외한 작업영역(availableGeometry) 기준. geometry(모니터 전체)로
    // 잡으면 하단이 작업표시줄 아래로 가려진다.
    const QRect workArea = screen->availableGeometry();
    
    if (direction == "up") {
        // Win + ↑ : 최대화
        qDebug() << "WindowHelper::handleAeroSnapShortcut - Maximizing window";
        qWindow->showMaximized();
    } else if (direction == "down") {
        // Win + ↓ : 복원 (최대화 상태에서) 또는 최소화 (일반 상태에서)
        if (qWindow->windowState() == Qt::WindowMaximized) {
            qDebug() << "WindowHelper::handleAeroSnapShortcut - Restoring window";
            qWindow->showNormal();
        } else {
            qDebug() << "WindowHelper::handleAeroSnapShortcut - Minimizing window";
            qWindow->showMinimized();
        }
    } else if (direction == "left") {
        // Win + ← : 좌반 화면으로 스냅
        qDebug() << "WindowHelper::handleAeroSnapShortcut - Snapping to left half";
        qWindow->showNormal();
        qWindow->setGeometry(workArea.x(), workArea.y(), workArea.width() / 2, workArea.height());
    } else if (direction == "right") {
        // Win + → : 우반 화면으로 스냅
        qDebug() << "WindowHelper::handleAeroSnapShortcut - Snapping to right half";
        qWindow->showNormal();
        qWindow->setGeometry(workArea.x() + workArea.width() / 2, workArea.y(), workArea.width() / 2, workArea.height());
    }
    #else
    // Linux/macOS에서는 Aero Snap 단축키 미지원
    Q_UNUSED(direction)
    #endif
}

void WindowHelper::startSystemResize(QObject* window, int edge)
{
    QWindow* qWindow = nullptr;

    if (auto* quickWindow = qobject_cast<QQuickWindow*>(window)) {
        qWindow = quickWindow;
    } else if (auto* item = qobject_cast<QQuickItem*>(window)) {
        if (item->window()) {
            qWindow = item->window();
        }
    } else if (auto* windowObj = qobject_cast<QWindow*>(window)) {
        qWindow = windowObj;
    }

    if (!qWindow) {
        return;
    }

    // 최대화 상태에서는 리사이즈 불가
    if (qWindow->windowState() == Qt::WindowMaximized) {
        return;
    }

#if QT_VERSION >= QT_VERSION_CHECK(5, 15, 0)
    Qt::Edges edges = static_cast<Qt::Edges>(edge & (Qt::LeftEdge | Qt::RightEdge | Qt::TopEdge | Qt::BottomEdge));
    if (edges != Qt::Edges()) {
        qWindow->startSystemResize(edges);
    }
#else
    Q_UNUSED(edge)
#endif
}
