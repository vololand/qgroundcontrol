#pragma once

#ifndef QGC_NO_SERIAL_LINK

#include <QtCore/QMap>
#include <QtCore/QObject>
#include <QtCore/QVariantList>

#include "QGCLoggingCategory.h"

Q_DECLARE_LOGGING_CATEGORY(PortScannerLog)

class LinkConfiguration;
class QTimer;

/// Pixhawk 포트만 주기적으로 스캔하여 QML에 노출하는 싱글턴.
/// AutoConnect 기능을 끈 상태에서 DroneList가 수동으로 연결/해제할 수 있도록 지원한다.
class PortScanner : public QObject
{
    Q_OBJECT

    // QML: QGroundControl.portScanner.availablePorts
    Q_PROPERTY(QVariantList availablePorts READ availablePorts NOTIFY availablePortsChanged)

public:
    explicit PortScanner(QObject *parent = nullptr);
    ~PortScanner() override;

    static PortScanner *instance();
    static void         registerQmlTypes();

    QVariantList availablePorts() const { return _availablePorts; }

    /// 해당 포트에 SerialConfiguration 을 생성하고 LinkManager 를 통해 연결한다.
    Q_INVOKABLE void connectPort(const QString &portName, int baud = 115200);

    /// 해당 포트의 링크 설정을 제거하고 연결을 해제한다.
    Q_INVOKABLE void disconnectPort(const QString &portName);

    /// portName 이 현재 연결 중인지 반환한다.
    Q_INVOKABLE bool isConnected(const QString &portName) const;

signals:
    void availablePortsChanged();

private slots:
    void _scan();

private:
    QTimer      *_scanTimer     = nullptr;
    QVariantList _availablePorts;                         ///< QML 에 노출되는 포트 목록
    QMap<QString, LinkConfiguration *> _portConfigs;     ///< portName → 생성한 LinkConfiguration*
};

#endif // QGC_NO_SERIAL_LINK
