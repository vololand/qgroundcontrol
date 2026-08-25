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

/// 커스텀 Plan 뷰 전용: QML에서 visualItems.move()를 호출할 수 있도록
/// MissionController의 visualItems()->move(from, to)를 C++에서 호출하는 헬퍼.
/// (QmlObjectListModel::move는 Q_INVOKABLE이 아니어서 QML에서 직접 호출 불가)
class CustomMissionReorderHelper : public QObject
{
    Q_OBJECT

public:
    explicit CustomMissionReorderHelper(QObject* parent = nullptr);

    /// missionController: MissionController 인스턴스 (QML의 _missionController)
    /// from: 이동할 항목 인덱스, to: 목표 인덱스
    Q_INVOKABLE void moveVisualItem(QObject* missionController, int from, int to);
};
