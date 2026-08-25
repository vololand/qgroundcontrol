#ifndef DRONEMANAGER_H
#define DRONEMANAGER_H

#include <QObject>
#include <QByteArray>
#include <QHash>
#include <QTimer>

class DroneModel;

class DroneManager : public QObject
{
    Q_OBJECT

public:
    explicit DroneManager(DroneModel* model, QObject* parent = nullptr);

    // 목록 재요청 (프로토콜 확정 후 패킷 구성)
    Q_INVOKABLE void requestListRefresh();

    // 디버그용 날 데이터 주입
    Q_INVOKABLE void injectRawText(const QString& text);

public slots:
    // TcpClient::dataReceived 와 연결
    void processIncomingData(const QByteArray& data);

signals:
    // TcpClient::sendData 로 연결할 송신 요청
    void sendRequest(const QByteArray& data);

private:
    void markOfflineIfTimeout();

private:
    DroneModel* m_droneModel = nullptr;

    bool m_listLoaded = false;
    QHash<QString, qint64> m_lastHbMs;
    QTimer m_offlineTimer;
    const qint64 m_offlineTimeoutMs = 5000;
};

#endif
