#ifndef QGC_NO_SERIAL_LINK

#include "PortScanner.h"

#include "LinkConfiguration.h"
#include "LinkManager.h"
#include "QGCLoggingCategory.h"
#include "QGCSerialPortInfo.h"
#include "SerialLink.h"

#include <QtCore/qapplicationstatic.h>
#include <QtCore/QTimer>
#include <QtCore/QVariantMap>
#include <QtQml/qqml.h>

QGC_LOGGING_CATEGORY(PortScannerLog, "qgc.comms.portscanner")

Q_APPLICATION_STATIC(PortScanner, _portScannerInstance)

PortScanner::PortScanner(QObject *parent)
    : QObject(parent)
    , _scanTimer(new QTimer(this))
{
    _scanTimer->setInterval(1000);
    (void) connect(_scanTimer, &QTimer::timeout, this, &PortScanner::_scan);
    _scanTimer->start();
}

PortScanner::~PortScanner()
{
    _scanTimer->stop();
}

PortScanner *PortScanner::instance()
{
    return _portScannerInstance();
}

void PortScanner::registerQmlTypes()
{
    (void) qmlRegisterUncreatableType<PortScanner>(
        "QGroundControl", 1, 0, "PortScanner", "Reference only");
}

void PortScanner::_scan()
{
    const QList<QGCSerialPortInfo> portList = QGCSerialPortInfo::availablePorts();

    QVariantList newPorts;
    for (const QGCSerialPortInfo &info : portList) {
        QGCSerialPortInfo::BoardType_t boardType;
        QString boardName;
        if (!info.getBoardInfo(boardType, boardName)) {
            continue;
        }
        if (boardType != QGCSerialPortInfo::BoardTypePixhawk) {
            continue;
        }
        if (info.isBootloader()) {
            continue;
        }

        // SLCAN(CAN 버스) 포트는 MAVLink 통신에 불필요 → 제외
        if (info.description().contains(QLatin1String("SLCAN"), Qt::CaseInsensitive)) {
            continue;
        }

        QVariantMap entry;
        entry[QStringLiteral("portName")]    = info.systemLocation();   // 내부 식별자
        entry[QStringLiteral("displayName")] = info.portName()          // e.g. COM3 / ttyACM0
                                               + QStringLiteral(" (") + boardName + QStringLiteral(")");
        entry[QStringLiteral("boardName")]   = boardName;
        entry[QStringLiteral("connected")]   = _portConfigs.contains(info.systemLocation());
        newPorts.append(entry);
    }

    if (newPorts != _availablePorts) {
        _availablePorts = newPorts;
        emit availablePortsChanged();
    }
}

void PortScanner::connectPort(const QString &portName, int baud)
{
    if (_portConfigs.contains(portName)) {
        qCDebug(PortScannerLog) << "Already connected:" << portName;
        return;
    }

    SerialConfiguration *config = new SerialConfiguration(
        QStringLiteral("Pixhawk-%1").arg(portName));
    config->setPortName(portName);
    config->setBaud(baud);
    config->setDynamic(true);       // UI 링크 목록(MainStatusIndicator)에서 숨겨짐
    config->setAutoConnect(false);
    config->setUsbDirect(true);

    // addConfiguration 이 소유권을 가져가므로 이후 config 원시 포인터 사용 주의
    SharedLinkConfigurationPtr sharedConfig = LinkManager::instance()->addConfiguration(config);
    if (!LinkManager::instance()->createConnectedLink(sharedConfig)) {
        qCWarning(PortScannerLog) << "createConnectedLink failed for" << portName;
        // removeConfiguration 내부에서 sharedConfig 를 _rgLinkConfigs 에서 제거 → 소멸
        LinkManager::instance()->removeConfiguration(sharedConfig.get());
        return;
    }

    // sharedConfig.get() == config 이므로 원시 포인터를 키로 저장
    _portConfigs[portName] = sharedConfig.get();

    // connected 플래그 갱신을 위해 즉시 재스캔
    _scan();
}

void PortScanner::disconnectPort(const QString &portName)
{
    auto it = _portConfigs.find(portName);
    if (it == _portConfigs.end()) {
        qCDebug(PortScannerLog) << "Not connected:" << portName;
        return;
    }

    LinkManager::instance()->removeConfiguration(it.value());
    _portConfigs.erase(it);

    // connected 플래그 갱신
    _scan();
}

bool PortScanner::isConnected(const QString &portName) const
{
    return _portConfigs.contains(portName);
}

#endif // QGC_NO_SERIAL_LINK
