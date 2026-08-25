/****************************************************************************
 *
 * DroneVideo 전용 독립 GStreamer RTSP 수신기.
 * VideoManager를 사용하지 않고 자체 파이프라인으로 RTSP 재생.
 *
 ****************************************************************************/

#include "CustomRtspReceiver.h"
#include "EncryptedRtspClient.h"
#include "QGCCorePlugin.h"
#include "QGCLogging.h"
#include "QGCLoggingCategory.h"
#include "VideoReceiver.h"

#include <QtCore/QDateTime>
#include <QtCore/QTimer>
#include <QtCore/QUrl>
#include <QtQuick/QQuickItem>

QGC_LOGGING_CATEGORY(CustomRtspReceiverLog, "qgc.customrtspreceiver")

namespace {
constexpr int kReconnectBaseDelayMs = 2000;
constexpr int kReconnectMaxDelayMs = 30000;
constexpr int kReconnectMaxShift = 4; // 2s, 4, 8, 16, 30(상한)
/// 이만큼 재생이 유지됐다면 설정 문제가 아니라 일시 장애로 보고 지연을 초기화한다.
constexpr qint64 kSessionStableMs = 30000;
}

CustomRtspReceiver::CustomRtspReceiver(QObject *parent)
    : QObject(parent)
{
}

CustomRtspReceiver::~CustomRtspReceiver()
{
#ifdef QGC_GST_STREAMING
    // 파괴 중에는 onStopComplete 람다(컨텍스트 객체가 this)가 실행되지 않으므로
    // sink/receiver 해제를 여기서 직접 수행한다.
    ++_applyToken;
    _activeSourceKey.clear();

    if (_cryptoClient) {
        _cryptoClient->disconnect(this);
        _cryptoClient->stop();
        _cryptoClient = nullptr;
    }

    if (_receiver) {
        VideoReceiver *receiver = _receiver;
        _receiver = nullptr;
        receiver->disconnect(this);
        void *sink = receiver->sink();
        receiver->stop();
        QGCCorePlugin::instance()->releaseVideoSink(sink);
        receiver->deleteLater();
    }
#endif
}

void CustomRtspReceiver::_setStatus(int code, const QString &message)
{
    if (_statusCode == code && _statusMessage == message) {
        return;
    }
    // 같은 코드의 상세(초 카운트, 무효 NAL 수)가 바뀌어도 콘솔은 발생 시 한 줄만.
    const bool newlyOccurred = (code != 0 && code != _statusCode);
    if (code == 0) {
        // 진단 해제(세션 정상) 또는 사용자가 설정을 바꾼 경우다. 다음 실패는 즉시 재시도한다.
        _reconnectAttempts = 0;
    }
    _statusCode = code;
    _statusMessage = message;
    if (newlyOccurred) {
        // Application Settings → Console 은 isDebugEnabled() 인 줄만 모델에 넣는다.
        // qCWarning 은 GST Disabled / 카테고리 debug off 이면 그 목록에 안 보인다.
        QGCLogging::instance()->log(message);
    }
    emit statusChanged();
}

void CustomRtspReceiver::setChannelUrl(const QString &url)
{
    if (_channelUrl != url) {
        _channelUrl = url;
        _setStatus(0, QString());
        emit channelUrlChanged();
        QTimer::singleShot(0, this, [this]() { _applySourceAndPlay(); });
    }
}

void CustomRtspReceiver::setVideoOutput(QQuickItem *item)
{
    if (_videoOutput != item) {
        _stop();
        _videoOutput = item;
        _setStatus(0, QString());
        emit videoOutputChanged();
        QTimer::singleShot(0, this, [this]() { _applySourceAndPlay(); });
    }
}

void CustomRtspReceiver::setStreamEnabled(bool enabled)
{
    if (_streamEnabled != enabled) {
        _streamEnabled = enabled;
        _setStatus(0, QString());
        emit streamEnabledChanged();
        if (!enabled)
            _stop();
        else
            QTimer::singleShot(0, this, [this]() { _applySourceAndPlay(); });
    }
}

void CustomRtspReceiver::setCryptoEnabled(bool enabled)
{
    if (_cryptoEnabled == enabled) {
        return;
    }

    _cryptoEnabled = enabled;
    _setStatus(0, QString());
    emit cryptoEnabledChanged();
    _stop();
    QTimer::singleShot(0, this, [this]() { _applySourceAndPlay(); });
}

void CustomRtspReceiver::setCryptoMode(const QString &mode)
{
    const QString normalized = mode.trimmed().compare(QLatin1String("high"), Qt::CaseInsensitive) == 0
                                   ? QStringLiteral("high")
                                   : QStringLiteral("normal");
    if (_cryptoMode == normalized) {
        return;
    }

    _cryptoMode = normalized;
    _setStatus(0, QString());
    emit cryptoModeChanged();
    _stop();
    QTimer::singleShot(0, this, [this]() { _applySourceAndPlay(); });
}

bool CustomRtspReceiver::_isApplyCurrent(quint64 token) const
{
    return token == _applyToken;
}

void CustomRtspReceiver::_scheduleReconnect()
{
    if (!_streamEnabled || _channelUrl.trimmed().isEmpty() || !_videoOutput) {
        return;
    }
    // 오래 재생되다 끊긴 것과 열자마자 계속 실패하는 것은 다르다. 후자만 지연을 늘려
    // Console 이 같은 줄로 도배되는 것을 막는다.
    if (_sessionStartMs > 0
        && (QDateTime::currentMSecsSinceEpoch() - _sessionStartMs) > kSessionStableMs) {
        _reconnectAttempts = 0;
    }
    _sessionStartMs = 0;

    const int delayMs = qMin(kReconnectMaxDelayMs,
                             kReconnectBaseDelayMs << qMin(_reconnectAttempts, kReconnectMaxShift));
    ++_reconnectAttempts;

    const quint64 token = _applyToken;
    // 재시도 사실이 Console 에 남지 않으면 앞뒤 메시지가 별개 장애처럼 보인다.
    QGCLogging::instance()->log(tr("영상 재연결 %1회째 시도 (%2초 후)")
                                   .arg(_reconnectAttempts)
                                   .arg(delayMs / 1000));
    QTimer::singleShot(delayMs, this, [this, token]() {
        if (!_isApplyCurrent(token)) {
            return;
        }
        _applySourceAndPlay();
    });
}

void CustomRtspReceiver::_applySourceAndPlay()
{
#ifdef QGC_GST_STREAMING
    const QString url = _channelUrl.trimmed();
    if (!_streamEnabled || url.isEmpty() || !_videoOutput) {
        _stop();
        return;
    }

    const QString sourceKey = QStringLiteral("%1|crypto=%2|mode=%3").arg(url).arg(_cryptoEnabled).arg(_cryptoMode);
    if (_cryptoEnabled) {
        if (_cryptoClient && _activeSourceKey == sourceKey) {
            return;
        }
    } else if (_receiver && _activeSourceKey == sourceKey) {
        return;
    }

    // 실제로 재시작할 때만 토큰을 올린다. 중복 호출(같은 소스)에서 올리면
    // 진행 중인 세션의 onStartComplete 가 무효 처리되어 디코딩이 시작되지 않는다.
    const quint64 token = ++_applyToken;
    _stopPlayback();

    if (_cryptoEnabled) {
        // 전송(udp/tcp)과 프레이밍(payload/rtsp) 판단은 EncryptedRtspClient 가 한다.
        // 전송은 SETUP 응답이, 프레이밍은 video_endpoints.ini [crypto] framing 이 결정한다.
        const QUrl remoteUrl(url);

        _cryptoClient = new EncryptedRtspClient(this);
        connect(_cryptoClient, &EncryptedRtspClient::sessionEnded, this, [this](const QString &message) {
            // CryptoLinkMonitor 는 MAVLink 암호 링크(EncryptedTcpPipe)의 연결 상태 이력이다.
            // 영상 이벤트를 넣으면 연결 상태 팝업이 링크 장애로 오인시킨다.
            // Console 기록은 _setStatus 가 담당한다.
            _setStatus(static_cast<int>(EncryptedRtspClient::Diagnosis::SessionEnded),
                       tr("영상 세션 종료\n%1").arg(message));
            _stop();
            // 평문 경로(onStopComplete)와 동일하게 재연결한다. _stop() 이 토큰을 올린 뒤라
            // 이전 세션의 예약은 무효화되고 새 토큰으로만 재시도된다.
            _scheduleReconnect();
        });
        connect(_cryptoClient, &EncryptedRtspClient::fatalError, this, [this](const QString &message) {
            _setStatus(static_cast<int>(EncryptedRtspClient::Diagnosis::StartFailed),
                       tr("암호 영상 시작 실패\n%1").arg(message));
            _stop();
            _scheduleReconnect();
        });
        // 진단 메시지는 재연결을 넘어 유지하고, 다음 세션이 정상을 확인하면 0으로 해제된다.
        connect(_cryptoClient, &EncryptedRtspClient::diagnosisChanged, this,
                [this](int code, const QString &message) { _setStatus(code, message); });
        // 원인 로그는 오버레이 등급/중복 규칙을 타지 않고 Console 에 그대로 쌓인다.
        connect(_cryptoClient, &EncryptedRtspClient::causeLogged, this, [](const QString &line) {
            QGCLogging::instance()->log(line);
        });

        const auto speedMode = _cryptoMode == QLatin1String("high")
                                   ? TngVideoCryptoService::SpeedMode::High
                                   : TngVideoCryptoService::SpeedMode::Normal;
        QString error;
        if (!_cryptoClient->start(remoteUrl, speedMode, _videoOutput, &error)) {
            // 클라이언트가 파괴되면 diagnosisChanged 로는 아무것도 오지 않으므로 여기서 직접 표시한다.
            _setStatus(static_cast<int>(EncryptedRtspClient::Diagnosis::StartFailed),
                       tr("암호 영상 시작 실패\n%1").arg(error));
            _cryptoClient->deleteLater();
            _cryptoClient = nullptr;
            _scheduleReconnect();
            return;
        }

        _activeSourceKey = sourceKey;
        _sessionStartMs = QDateTime::currentMSecsSinceEpoch();
        qCDebug(CustomRtspReceiverLog) << "Started encrypted in-process client" << url;
        return;
    }

    VideoReceiver *receiver = qobject_cast<VideoReceiver*>(QGCCorePlugin::instance()->createVideoReceiver(nullptr));
    if (!receiver) {
        qCWarning(CustomRtspReceiverLog) << "createVideoReceiver failed";
        return;
    }

    void *sink = QGCCorePlugin::instance()->createVideoSink(_videoOutput, receiver);
    if (!sink) {
        qCWarning(CustomRtspReceiverLog) << "createVideoSink failed";
        receiver->deleteLater();
        return;
    }

    receiver->setWidget(_videoOutput);
    receiver->setSink(sink);
    receiver->setUri(url);
    receiver->setLowLatency(true);

    // VideoManager와 동일: start OK → setStarted + startDecoding, 실패 시 재시도.
    connect(receiver, &VideoReceiver::onStartComplete, this, [this, receiver, token](VideoReceiver::STATUS status) {
        if (!_isApplyCurrent(token) || receiver != _receiver) {
            return;
        }
        switch (status) {
        case VideoReceiver::STATUS_OK:
            receiver->setStarted(true);
            if (receiver->sink()) {
                receiver->startDecoding(receiver->sink());
                qCDebug(CustomRtspReceiverLog) << "Decoding started" << receiver->uri();
            }
            break;
        case VideoReceiver::STATUS_INVALID_URL:
        case VideoReceiver::STATUS_INVALID_STATE:
            qCWarning(CustomRtspReceiverLog) << "plaintext RTSP start rejected:" << status << receiver->uri();
            break;
        default:
            // 정리·재연결은 onStopComplete 핸들러가 한 번만 수행한다.
            qCWarning(CustomRtspReceiverLog) << "plaintext RTSP start failed:" << status << receiver->uri();
            receiver->stop();
            break;
        }
    }, Qt::SingleShotConnection);

    connect(receiver, &VideoReceiver::onStopComplete, this, [this, receiver, token]() {
        receiver->setStarted(false);
        QGCCorePlugin::instance()->releaseVideoSink(receiver->sink());
        receiver->disconnect();
        receiver->deleteLater();
        const bool wasActive = (_receiver == receiver);
        if (_receiver == receiver) {
            _receiver = nullptr;
        }
        if (wasActive) {
            _activeSourceKey.clear();
        }
        qCDebug(CustomRtspReceiverLog) << "Receiver stopped and released";
        // 의도적 stop(_stopPlayback이 _receiver를 먼저 비움)이면 재연결하지 않음.
        if (wasActive && _isApplyCurrent(token)) {
            _scheduleReconnect();
        }
    }, Qt::SingleShotConnection);

    _receiver = receiver;
    _activeSourceKey = sourceKey;
    _sessionStartMs = QDateTime::currentMSecsSinceEpoch();
    receiver->start(5);
    qCDebug(CustomRtspReceiverLog) << "Started plaintext rtspsrc" << url;
#else
    Q_UNUSED(_streamEnabled);
    Q_UNUSED(_videoOutput);
    Q_UNUSED(_channelUrl);
    Q_UNUSED(_cryptoEnabled);
    Q_UNUSED(_cryptoMode);
#endif
}

void CustomRtspReceiver::_stop()
{
#ifdef QGC_GST_STREAMING
    ++_applyToken; // invalidate pending reconnect / delayed apply
    _stopPlayback();
#endif
}

void CustomRtspReceiver::_stopPlayback()
{
#ifdef QGC_GST_STREAMING
    _activeSourceKey.clear();

    if (_cryptoClient) {
        _cryptoClient->disconnect(this);
        _cryptoClient->stop();
        _cryptoClient->deleteLater();
        _cryptoClient = nullptr;
    }

    if (!_receiver) {
        return;
    }

    VideoReceiver *receiver = _receiver;
    _receiver = nullptr;

    // start 완료 전이어도 stop()을 거쳐야 파이프라인이 sink 해제보다 먼저 정리된다.
    // 생성 시 등록한 onStopComplete 핸들러가 sink/receiver를 한 번만 해제한다.
    receiver->stop();
    qCDebug(CustomRtspReceiverLog) << "Stop requested";
#endif
}
