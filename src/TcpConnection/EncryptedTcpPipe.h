#pragma once

#include "TngCryptoConfig.h"
#include "TngCryptoEngine.h"
#include "McmLCryptoEngine.h"
#include "ServerTcpClient.h"

#include <QtCore/QByteArray>
#include <QtCore/QObject>
#include <QtCore/QTimer>

class EncryptedTcpPipe : public QObject
{
    Q_OBJECT

public:
    explicit EncryptedTcpPipe(QObject *parent = nullptr);

    bool start(const TngCryptoConfig &config, QString *error = nullptr);
    void stop();

    bool isConnected() const;

public slots:
    void sendPlain(const QByteArray &plain);

signals:
    void plainReceived(const QByteArray &plain);
    void connected();
    void disconnected();
    void errorOccurred(const QString &message);
    /// 연속 실패가 임계에 도달해 자동 재연결을 멈췄다. 사용자 확인 후 재개해야 한다.
    void suspended(const QString &reason);

private slots:
    void onSocketConnected();
    void onSocketDisconnected();
    void onRawReceived(const QByteArray &chunk);
    void onResumeRequested();
    void onWatchdogTick();

private:
    void processRxBuffer();

    QString sourceLabel() const;
    void report(int level, const QString &message);
    /// 실패 경로 단일 진입점. 기록 → 임계 미만이면 백오프 후 재시도, 이상이면 중지.
    void handleFailure(const QString &message);
    void clearFailureState();

    /// 복호 결과에 실제 MAVLink 프레임이 있는지 확인하고 무수신 감시 상태를 갱신한다.
    /// CTR 모드는 어떤 입력이든 복호에 "성공"하므로 잘못된 프로토콜은 여기서만 드러난다.
    void inspectPlain(const QByteArray &plain);
    void startWatchdog();
    void stopWatchdog();

    bool initCrypto(QString *error);
    void closeCrypto();
    bool cryptoReady() const;
    bool openCryptoSessions(QString *error);
    void closeCryptoSessions();
    QByteArray encryptFixedIv(const QByteArray &plain, QString *error);
    QByteArray decryptFixedIv(const QByteArray &cipher, QString *error);

    TcpClient _tcp;
    QTimer _watchdog;
    TngCryptoEngine _crypto;
    McmLCryptoEngine _mcm;
    TngCryptoConfig _config;
    QByteArray _rxBuffer;
    bool _started = false;
    bool _connected = false;
    int _failureStreak = 0;
    bool _suspended = false;

    qint64 _connectedAtMs = 0;
    qint64 _lastValidAtMs = 0;
    int _invalidStreak = 0;
    bool _sawValidData = false;
    bool _timeoutReported = false;
};
