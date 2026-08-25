/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QObject>
#include <QtQuick/QQuickWindow>

/// 프레임리스 윈도우 드래그를 위한 헬퍼 클래스
/// QML에서 Windows 네이티브 드래그 기능을 사용할 수 있도록 함
class WindowHelper : public QObject
{
    Q_OBJECT

public:
    explicit WindowHelper(QObject* parent = nullptr);

    /// window: ApplicationWindow 인스턴스 (QML의 mainWindow)
    /// mouseX, mouseY: 마우스 위치 (사용하지 않지만 호환성을 위해 유지)
    Q_INVOKABLE void startSystemMove(QObject* window, int mouseX = 0, int mouseY = 0);

    /// Windows 시스템 메뉴 표시 (복원/최소화/최대화/닫기)
    /// window: ApplicationWindow 인스턴스 (QML의 mainWindow)
    /// x, y: 메뉴를 표시할 위치 (글로벌 좌표)
    Q_INVOKABLE void showSystemMenu(QObject* window, int x, int y);
    
    /// Windows 타이틀바 더블클릭 처리 (최대화/복원 토글)
    /// Windows의 기본 동작을 시뮬레이션: WM_NCLBUTTONDBLCLK + WM_SYSCOMMAND
    /// window: ApplicationWindow 인스턴스 (QML의 mainWindow)
    Q_INVOKABLE void toggleMaximizeRestore(QObject* window);
    
    /// Aero Snap 기능: 드래그 종료 시 마우스 위치에 따라 창을 스냅
    /// window: ApplicationWindow 인스턴스 (QML의 mainWindow)
    /// mouseX, mouseY: 마우스의 글로벌 화면 좌표
    Q_INVOKABLE void handleAeroSnap(QObject* window, int mouseX, int mouseY);
    
    /// Aero Snap 단축키 처리: Windows 키 + 방향키
    /// window: ApplicationWindow 인스턴스 (QML의 mainWindow)
    /// direction: "up"(최대화), "down"(복원/최소화), "left"(좌반), "right"(우반)
    Q_INVOKABLE void handleAeroSnapShortcut(QObject* window, const QString& direction);

    /// 창 테두리 드래그 리사이즈 시작 (상·하·좌·우)
    /// window: ApplicationWindow 인스턴스 (QML의 mainWindow)
    /// edge: Qt.LeftEdge(1), Qt.RightEdge(2), Qt.TopEdge(4), Qt.BottomEdge(8)
    Q_INVOKABLE void startSystemResize(QObject* window, int edge);
};
