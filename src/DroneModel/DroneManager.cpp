#include "DroneManager.h"
#include "DroneModel.h"

#include <QDateTime>

DroneManager::DroneManager(DroneModel* model, QObject* parent)
    : QObject(parent)
    , m_droneModel(model)
{
    connect(&m_offlineTimer, &QTimer::timeout, this, &DroneManager::markOfflineIfTimeout);
    m_offlineTimer.start(3000);
}

void DroneManager::processIncomingData(const QByteArray& data)
{
    if (data.isEmpty())
        return;

    // 프로토콜 파서 자리. 당분간 디버그 표시만 수행.
    if (m_droneModel) {
        m_droneModel->setRecentData(QString::fromUtf8(data.toHex(' ')));
    }
}

void DroneManager::requestListRefresh()
{
    // TODO: 날 데이터/바이너리 프로토콜에 맞는 목록 요청 패킷 구성 후 emit
    // emit sendRequest(...);
}

void DroneManager::injectRawText(const QString& text)
{
    const QByteArray data = text.toUtf8().trimmed();
    if (data.isEmpty())
        return;

    if (m_droneModel) {
        m_droneModel->setRecentData(QString("[INJECT]\n") + QString::fromUtf8(data));
    }

    processIncomingData(data);
}

void DroneManager::markOfflineIfTimeout()
{
    if (!m_listLoaded || !m_droneModel)
        return;

    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();

    for (auto it = m_lastHbMs.begin(); it != m_lastHbMs.end(); ++it) {
        const QString& name = it.key();
        const qint64 lastMs = it.value();

        if (nowMs - lastMs > m_offlineTimeoutMs) {
            m_droneModel->setDeviceStatus(name, "OFFLINE");
        }
    }
}
