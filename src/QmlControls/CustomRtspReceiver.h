/****************************************************************************
 *
 * DroneVideo 전용 독립 GStreamer RTSP 수신기.
 * VideoManager를 사용하지 않고 자체 파이프라인으로 RTSP 재생.
 * crypto on: EncryptedRtspClient (인프로세스 복호, localhost listen 없음)
 * crypto off: 기존 VideoReceiver + rtspsrc
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QObject>
#include <QtQuick/QQuickItem>

class VideoReceiver;

class CustomRtspReceiver : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString channelUrl READ channelUrl WRITE setChannelUrl NOTIFY channelUrlChanged)
    Q_PROPERTY(QQuickItem* videoOutput READ videoOutput WRITE setVideoOutput NOTIFY videoOutputChanged)
    Q_PROPERTY(bool streamEnabled READ streamEnabled WRITE setStreamEnabled NOTIFY streamEnabledChanged)
    Q_PROPERTY(bool cryptoEnabled READ cryptoEnabled WRITE setCryptoEnabled NOTIFY cryptoEnabledChanged)
    Q_PROPERTY(QString cryptoMode READ cryptoMode WRITE setCryptoMode NOTIFY cryptoModeChanged)
    Q_PROPERTY(int statusCode READ statusCode NOTIFY statusChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusChanged)

public:
    explicit CustomRtspReceiver(QObject *parent = nullptr);
    ~CustomRtspReceiver();

    QString channelUrl() const { return _channelUrl; }
    void setChannelUrl(const QString &url);

    QQuickItem* videoOutput() const { return _videoOutput; }
    void setVideoOutput(QQuickItem *item);

    bool streamEnabled() const { return _streamEnabled; }
    void setStreamEnabled(bool enabled);

    bool cryptoEnabled() const { return _cryptoEnabled; }
    void setCryptoEnabled(bool enabled);

    QString cryptoMode() const { return _cryptoMode; }
    void setCryptoMode(const QString &mode);

    /// EncryptedRtspClient::Diagnosis 값. 0이면 정상.
    int statusCode() const { return _statusCode; }
    QString statusMessage() const { return _statusMessage; }

signals:
    void channelUrlChanged();
    void videoOutputChanged();
    void streamEnabledChanged();
    void cryptoEnabledChanged();
    void cryptoModeChanged();
    void statusChanged();

private:
    void _applySourceAndPlay();
    void _setStatus(int code, const QString &message);
    void _stop();
    void _stopPlayback();
    void _scheduleReconnect();
    bool _isApplyCurrent(quint64 token) const;

    QString _channelUrl;
    QQuickItem *_videoOutput = nullptr;
    bool _streamEnabled = true;
    bool _cryptoEnabled = false;
    QString _cryptoMode = QStringLiteral("normal");
    QString _activeSourceKey;
    quint64 _applyToken = 0;
    int _statusCode = 0;
    QString _statusMessage;
    /// 연속 실패 횟수. 세션이 kSessionStableMs 이상 살아 있었으면 0으로 되돌린다.
    int _reconnectAttempts = 0;
    qint64 _sessionStartMs = 0;

#ifdef QGC_GST_STREAMING
    VideoReceiver *_receiver = nullptr;
    class EncryptedRtspClient *_cryptoClient = nullptr;
#endif
};
