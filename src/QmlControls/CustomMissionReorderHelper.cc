/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "CustomMissionReorderHelper.h"
#include "MissionManager/MissionController.h"
#include "MissionManager/VisualMissionItem.h"
#include "QmlObjectListModel.h"

CustomMissionReorderHelper::CustomMissionReorderHelper(QObject* parent)
    : QObject(parent)
{
}

void CustomMissionReorderHelper::moveVisualItem(QObject* missionController, int from, int to)
{
    auto* mc = qobject_cast<MissionController*>(missionController);
    QmlObjectListModel* model = mc ? mc->visualItems() : nullptr;
    if (!mc || !model || from < 0 || from >= model->count() || to < 0 || to >= model->count() || from == to)
        return;
    // 스왑: from 위치 항목과 to 위치 항목을 맞바꿈 (예: 1-2-3-4에서 2↔4 드래그 → 1-4-3-2)
    const int lo = qMin(from, to);
    const int hi = qMax(from, to);
    QObject* itemLo = model->get(lo);
    QObject* itemHi = model->get(hi);
    if (!itemLo || !itemHi)
        return;
    model->removeAt(hi);
    model->removeAt(lo);
    model->insert(lo, itemHi);
    model->insert(hi, itemLo);
    mc->recalcSequenceNumbers();
    auto* moved = qobject_cast<VisualMissionItem*>(model->get(to));
    if (moved)
        mc->setCurrentPlanViewSeqNum(moved->sequenceNumber(), true);
}
