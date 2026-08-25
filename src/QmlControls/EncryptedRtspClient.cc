#include "EncryptedRtspClient.h"

#include "QGCCorePlugin.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QDateTime>
#include <QtCore/QRegularExpression>
#include <QtCore/QtEndian>
#include <QtCore/QTimer>
#include <QtCore/QUrlQuery>
#include <QtNetwork/QAbstractSocket>
#include <QtNetwork/QHostAddress>
#include <QtNetwork/QNetworkDatagram>
#include <QtNetwork/QTcpSocket>
#include <QtNetwork/QUdpSocket>
#include <QtQuick/QQuickItem>

#include <cstring>

#ifdef QGC_GST_STREAMING
#include <gst/gst.h>
#endif

QGC_LOGGING_CATEGORY(EncryptedRtspClientLog, "qgc.encryptedrtsp.client")

using Framing = TngVideoCryptoService::Framing;

namespace {
constexpr quint16 kDefaultRtspPort = 554;
constexpr qsizetype kMaxPlainBufferBytes = 8 * 1024 * 1024;
constexpr qsizetype kMaxInterleavedPayload = 2 * 1024 * 1024;
constexpr qsizetype kMinRtpHeaderBytes = 12;

// 제어 채널 프레이밍: [u32 BE 암호문 길이][암호문]. CTR 이므로 길이는 평문 길이와 같다.
constexpr qsizetype kCryptoFrameHeaderBytes = 4;
constexpr quint32 kMaxCryptoFrameBytes = 256 * 1024;
constexpr qsizetype kMaxCipherBufferBytes = 8 * 1024 * 1024;

constexpr int kDiagSampleSize = 40;
constexpr int kDiagInvalidLimit = kDiagSampleSize / 2;
constexpr int kCorruptInvalidLimit = 3;
// TCP 인터리브는 유실이 없으므로 불연속 몇 건이면 곧 프레이밍 오류다.
constexpr int kSeqAnomalyLimit = 3;
// UDP 는 유실·재정렬이 정상이다. 창 단위 비율로만 판단하고 창마다 초기화해 회복시킨다.
constexpr int kSeqWindowPackets = 500;
constexpr int kSeqWindowAnomalyLimit = 25;
constexpr qint64 kNoRtspTimeoutMs = 5000;
constexpr qint64 kNoRtpTimeoutMs = 3000;
// UDP 는 미디어가 별도 소켓이라 서버가 송신을 멈춰도 제어 TCP 는 살아 있다.
// 이 시간을 넘기면 세션을 닫아 재연결 경로를 태운다.
constexpr qint64 kMediaDeadTimeoutMs = 10000;
// RTP 가 이 시간 이상 흐르고도 디코더가 영상 패드를 못 만들면 caps 불일치로 본다.
constexpr qint64 kNoDecodeTimeoutMs = 4000;
constexpr int kWatchIntervalMs = 500;

constexpr int kMediaBindAttempts = 20;
constexpr int kUdpReceiveBufferBytes = 1024 * 1024;
// 한 번의 readyRead 에서 처리할 데이터그램 상한. 없으면 도착 속도가 처리 속도보다 빠를 때
// while 루프를 벗어나지 못해 GUI 이벤트 루프(페인트·입력·타이머)가 완전히 멈춘다.
constexpr int kMaxDatagramsPerBatch = 64;
constexpr int kMinKeepaliveIntervalMs = 5000;
constexpr int kDefaultSessionTimeoutSec = 60;

int diagnosisRank(EncryptedRtspClient::Diagnosis diagnosis)
{
    return static_cast<int>(diagnosis);
}
}

EncryptedRtspClient::EncryptedRtspClient(QObject *parent)
    : QObject(parent)
{
}

EncryptedRtspClient::~EncryptedRtspClient()
{
    stop();
}

bool EncryptedRtspClient::start(const QUrl &remoteUrl,
                                TngVideoCryptoService::SpeedMode mode,
                                QQuickItem *videoOutput,
                                QString *error)
{
#ifdef QGC_GST_STREAMING
    stop();
    _stopping = false;

    if (!videoOutput) {
        if (error) {
            *error = QStringLiteral("encrypted RTSP requires a video output item");
        }
        return false;
    }

    if (!remoteUrl.isValid()
        || remoteUrl.scheme().compare(QLatin1String("rtsp"), Qt::CaseInsensitive) != 0
        || remoteUrl.host().isEmpty()) {
        if (error) {
            *error = QStringLiteral("encrypted video requires a valid rtsp:// URL");
        }
        return false;
    }

    const QString rtpTransport =
        QUrlQuery(remoteUrl).queryItemValue(QStringLiteral("rtsp_transport")).trimmed().toLower();
    // 미지정과 auto 는 RTSP 표준 기본값인 UDP 로 본다. 최종 값은 SETUP 응답이 결정한다.
    _rtpTransport = (rtpTransport == QLatin1String("tcp")) ? RtpTransport::TcpInterleaved
                                                          : RtpTransport::Udp;

    _remoteUrl = remoteUrl;
    _videoOutput = videoOutput;
    _mode = mode;
    _cseq = 0;
    _phase = RtspPhase::Connecting;
    _session.clear();
    _trackUri.clear();
    _encodingName.clear();
    _cipherBuffer.clear();
    _plainBuffer.clear();
    _videoRtpChannel = 0;
    _videoRtcpChannel = 1;
    _payloadType = 96;
    _clockRate = 90000;
    _clientRtpPort = 0;
    _clientRtcpPort = 0;
    _serverRtpPort = 0;
    _serverRtcpPort = 0;
    _sessionTimeoutSec = kDefaultSessionTimeoutSec;

    const QUrl locationUrl = remoteUrl.adjusted(QUrl::RemoveQuery | QUrl::RemoveFragment);
    _requestUri = locationUrl.toString(QUrl::FullyEncoded).toUtf8();
    _baseUri = _requestUri;
    if (!_baseUri.endsWith('/')) {
        _baseUri.append('/');
    }

    _resetDiagnosisState();

    if (!TngVideoCryptoService::instance().acquire(mode, error)) {
        _phase = RtspPhase::Idle;
        return false;
    }
    _cryptoAcquired = true;

    // acquire() 가 ensureCryptoSection() 으로 기본 키를 채운 뒤에 읽어야 한다.
    // 송신측이 무엇을 암호화하는지는 ini 가 결정한다. 네 전송/프레이밍 조합을 모두 지원한다.
    _framing = TngVideoCryptoService::framing();

    // SETUP 에 client_port 를 적어 보내야 하므로 핸드셰이크보다 먼저 포트를 확보한다.
    if (_rtpTransport == RtpTransport::Udp && !_bindMediaSockets(error)) {
        TngVideoCryptoService::instance().release();
        _cryptoAcquired = false;
        _phase = RtspPhase::Idle;
        return false;
    }

    _socket = new QTcpSocket(this);
    connect(_socket, &QTcpSocket::connected, this, &EncryptedRtspClient::_onConnected);
    connect(_socket, &QTcpSocket::readyRead, this, &EncryptedRtspClient::_onReadyRead);
    connect(_socket, &QTcpSocket::disconnected, this, [this]() {
        if (!_stopping) {
            emit sessionEnded(tr("서버 연결이 끊어져 세션을 종료했습니다"));
            stop();
        }
    });
    connect(_socket, &QTcpSocket::errorOccurred, this, [this](QAbstractSocket::SocketError error) {
        if (_stopping || !_socket) {
            return;
        }
        if (error == QAbstractSocket::RemoteHostClosedError) {
            emit sessionEnded(tr("서버 연결이 끊어져 세션을 종료했습니다"));
            stop();
            return;
        }
        _fail(QStringLiteral("encrypted RTSP upstream error: %1").arg(_socket->errorString()));
    });

    if (!_watchTimer) {
        _watchTimer = new QTimer(this);
        connect(_watchTimer, &QTimer::timeout, this, &EncryptedRtspClient::_checkDataFlow);
    }
    _watchTimer->start(kWatchIntervalMs);

    const quint16 port = static_cast<quint16>(remoteUrl.port(kDefaultRtspPort));
    qCDebug(EncryptedRtspClientLog) << "Connecting encrypted RTSP" << remoteUrl.host() << port
                                    << "framing"
                                    << (_framing == Framing::RtspFrame ? "rtsp" : "payload")
                                    << "transport"
                                    << (_rtpTransport == RtpTransport::Udp ? "udp" : "tcp");
    _socket->connectToHost(remoteUrl.host(), port);
    return true;
#else
    Q_UNUSED(remoteUrl);
    Q_UNUSED(mode);
    Q_UNUSED(videoOutput);
    if (error) {
        *error = QStringLiteral("GStreamer streaming is not enabled");
    }
    return false;
#endif
}

void EncryptedRtspClient::stop()
{
    _stopping = true;
    _phase = RtspPhase::Idle;

    if (_busTimer) {
        _busTimer->stop();
        _busTimer->deleteLater();
        _busTimer = nullptr;
    }

    // 진단 메시지는 지우지 않는다. 재연결 루프에서 오버레이가 깜빡이지 않도록
    // 다음 세션이 정상 데이터를 확인했을 때만 _clearDiagnosis()로 해제된다.
    if (_watchTimer) {
        _watchTimer->stop();
        _watchTimer->deleteLater();
        _watchTimer = nullptr;
    }

    if (_keepaliveTimer) {
        _keepaliveTimer->stop();
        _keepaliveTimer->deleteLater();
        _keepaliveTimer = nullptr;
    }

    // TEARDOWN 이 나가기 전에 미디어 소켓을 닫아 늦게 도착한 데이터그램이 처리되지 않게 한다.
    for (QUdpSocket **socket : {&_rtpSocket, &_rtcpSocket}) {
        if (*socket) {
            (*socket)->disconnect(this);
            (*socket)->close();
            (*socket)->deleteLater();
            *socket = nullptr;
        }
    }

    if (_socket) {
        _socket->disconnect(this);
        if (!_session.isEmpty() && _socket->state() == QAbstractSocket::ConnectedState) {
            // best-effort; ignore write failures during teardown
            ++_cseq;
            const QByteArray teardown =
                "TEARDOWN " + _requestUri + " RTSP/1.0\r\n"
                "CSeq: " + QByteArray::number(_cseq) + "\r\n"
                "Session: " + _session + "\r\n"
                "\r\n";
            _sendRtsp(teardown);
            // abort() 는 쓰기 버퍼를 버린다. TEARDOWN 이 실제로 나가도록 먼저 밀어낸다.
            _socket->flush();
        }
        _socket->abort();
        _socket->deleteLater();
        _socket = nullptr;
    }

    _teardownPipeline();

    _cipherBuffer.clear();
    _plainBuffer.clear();
    _session.clear();
    _trackUri.clear();
    _encodingName.clear();
    _videoOutput = nullptr;

    if (_cryptoAcquired) {
        TngVideoCryptoService::instance().release();
        _cryptoAcquired = false;
    }

    _stopping = false;
}

void EncryptedRtspClient::_fail(const QString &message)
{
    if (_stopping) {
        return;
    }
    qCWarning(EncryptedRtspClientLog) << message;
    emit fatalError(message);
}

void EncryptedRtspClient::_resetDiagnosisState()
{
    _lastRtspMs = QDateTime::currentMSecsSinceEpoch();
    _lastRtpMs = 0;
    _lastDatagramMs = 0;
    _rtpAccepted = 0;
    _firstRtpMs = 0;
    _streamingSinceMs = 0;
    _lastSeq = 0;
    _haveLastSeq = false;
    _seqAnomalies = 0;
    _seqChecked = 0;
    _mediaDrops = 0;
    _loggedCauses.clear();
    _decodePadLinked = false;
    _sampleChecked = 0;
    _sampleInvalid = 0;
    _invalidAfterSample = 0;
}

void EncryptedRtspClient::_setDiagnosis(Diagnosis diagnosis, const QString &message)
{
    // 더 근본적인 원인이 표시 중이면 덮지 않는다(손상 < 패킷이상 < 복호실패 < 데이터없음).
    if (diagnosisRank(diagnosis) < diagnosisRank(_diagnosis)) {
        return;
    }
    if (_diagnosis == diagnosis && _diagnosisMessage == message) {
        return;
    }

    _diagnosis = diagnosis;
    _diagnosisMessage = message;
    // 콘솔 출력은 CustomRtspReceiver::_setStatus 가 코드 변경 시에만 한 번 한다.
    // 여기서 찍으면 NoServerData 초 카운트·GStreamer WARNING 이 무한 반복된다.
    emit diagnosisChanged(static_cast<int>(diagnosis), message);
}

void EncryptedRtspClient::_logCause(const QString &key, const QString &line)
{
    if (_loggedCauses.contains(key)) {
        return;
    }
    _loggedCauses.insert(key);
    qCWarning(EncryptedRtspClientLog) << line;
    emit causeLogged(line);
}

void EncryptedRtspClient::_traceCause(const QString &key, const QString &line)
{
    if (_loggedCauses.contains(key)) {
        return;
    }
    _loggedCauses.insert(key);
    // Console 목록에는 진단 문구만 둔다. 원인 상세는 카테고리 로그에만 남긴다.
    qCWarning(EncryptedRtspClientLog) << line;
}

void EncryptedRtspClient::_clearDiagnosis()
{
    if (_diagnosis == Diagnosis::None) {
        return;
    }
    _diagnosis = Diagnosis::None;
    _diagnosisMessage.clear();
    emit diagnosisChanged(static_cast<int>(Diagnosis::None), QString());
}

void EncryptedRtspClient::_checkDataFlow()
{
    if (_stopping || _phase == RtspPhase::Idle) {
        return;
    }

    const qint64 now = QDateTime::currentMSecsSinceEpoch();

    if (_phase == RtspPhase::Streaming) {
        const qint64 baseline = (_streamingSinceMs > 0) ? _streamingSinceMs : _lastRtspMs;
        // 유효 RTP 가 멈춘 시간과 패킷 자체가 멈춘 시간을 따로 본다. 둘을 합치면
        // 해석 불가능한 패킷이 계속 오는 동안 아무 진단도 뜨지 않는다.
        const qint64 rtpQuiet = now - ((_lastRtpMs > 0) ? _lastRtpMs : baseline);
        const qint64 wireQuiet = now - ((_lastDatagramMs > 0) ? _lastDatagramMs : baseline);

        // 패킷은 계속 오는데 쓸 수 있는 RTP 가 하나도 없으면 프레이밍·키 설정 불일치다.
        // 같은 설정으로 다시 열어도 결과가 같으므로 세션을 닫지 않는다(재연결 무의미).
        if (rtpQuiet > kNoRtpTimeoutMs && _rtpAccepted == 0 && _mediaDrops > 0
            && wireQuiet < kNoRtpTimeoutMs) {
            _setDiagnosis(Diagnosis::NoServerData,
                          tr("영상 데이터 형식 불일치\n데이터그램 %1개를 해석하지 못했습니다\n"
                             "(video_endpoints.ini [crypto] framing 확인)")
                              .arg(_mediaDrops));
            _traceCause(QStringLiteral("media-unusable"),
                        QStringLiteral("packets arrive but no usable RTP "
                                       "(drops %1, framing=%2, transport=%3)")
                            .arg(_mediaDrops)
                            .arg(_framing == Framing::RtspFrame ? QStringLiteral("rtsp")
                                                                : QStringLiteral("payload"))
                            .arg(_rtpTransport == RtpTransport::Udp ? QStringLiteral("udp")
                                                                   : QStringLiteral("tcp")));
            return;
        }

        if (rtpQuiet > kNoRtpTimeoutMs) {
            // NoServerData 가 뜬 뒤에는 더 낮은 등급(DecryptFailed 이하)이 _setDiagnosis 에서
            // 걸러져 표시되지 않는다. 원인 상세는 _traceCause 로 따로 남긴다.
            _setDiagnosis(Diagnosis::NoServerData,
                          tr("서버에서 영상 데이터를 보내지 않습니다\n(%1초간 RTP 없음)")
                              .arg(rtpQuiet / 1000));
            if (_rtpTransport == RtpTransport::Udp && _lastDatagramMs == 0) {
                _traceCause(QStringLiteral("udp-no-data"),
                            QStringLiteral("no datagram on UDP port %1 (server %2), "
                                           "check inbound firewall or server client_port")
                                .arg(_clientRtpPort)
                                .arg(_serverRtpPort));
            }

            if (rtpQuiet > kMediaDeadTimeoutMs) {
                emit sessionEnded(tr("영상 데이터가 %1초간 오지 않아 세션을 닫았습니다")
                                      .arg(rtpQuiet / 1000));
                stop();
            }
            return;
        }

        // RTP 는 흐르는데 디코더가 비디오 패드를 못 만든 경우다. 지금까지 아무 신호도 없었다.
        if (_lastRtpMs > 0 && !_decodePadLinked
            && (now - _lastRtpMs) < kNoRtpTimeoutMs
            && (_lastRtpMs - _firstRtpMs) > kNoDecodeTimeoutMs) {
            _traceCause(QStringLiteral("no-decode-pad"),
                        QStringLiteral("RTP flows but decoder made no video pad, "
                                       "codec %1 pt %2 rate %3 may not match the stream")
                            .arg(_encodingName)
                            .arg(_payloadType)
                            .arg(_clockRate));
        }
    } else if (now - _lastRtspMs > kNoRtspTimeoutMs) {
        // start() 는 connectToHost 직후 true 를 돌려준다. 여기까지 온 것은 요청을 보냈는데
        // 응답이 없는 경우이므로, 어느 단계에서 멈췄는지 함께 알린다.
        QString step;
        switch (_phase) {
        case RtspPhase::Connecting:
            step = QStringLiteral("CONNECT");
            break;
        case RtspPhase::Options:
            step = QStringLiteral("OPTIONS");
            break;
        case RtspPhase::Describe:
            step = QStringLiteral("DESCRIBE");
            break;
        case RtspPhase::Setup:
            step = QStringLiteral("SETUP");
            break;
        case RtspPhase::Play:
            step = QStringLiteral("PLAY");
            break;
        default:
            step = QStringLiteral("RTSP");
            break;
        }
        // 진단만 걸면 오버레이에 같은 문구가 영구히 남고 아무 조치도 일어나지 않는다.
        // 세션을 실패로 끝내야 재연결 경로를 탄다. 표시 문구는 수신측에서
        // "암호 영상 시작 실패\n%1" 로 감싸므로 사유만 넘긴다.
        _fail(_phase == RtspPhase::Connecting
                  ? tr("서버에 연결되지 않습니다")
                  : tr("서버가 %1 요청에 응답하지 않습니다").arg(step));
    }
}

void EncryptedRtspClient::_checkRtpSequence(quint16 seq)
{
    if (_haveLastSeq) {
        const auto expected = static_cast<quint16>(_lastSeq + 1);
        if (seq != expected) {
            ++_seqAnomalies;
        }
    }
    _lastSeq = seq;
    _haveLastSeq = true;
    ++_seqChecked;

    if (_rtpTransport == RtpTransport::TcpInterleaved) {
        if (_seqAnomalies >= kSeqAnomalyLimit) {
            _setDiagnosis(Diagnosis::PacketAnomaly,
                          tr("패킷 이상\n시퀀스 불연속 %1건").arg(_seqAnomalies));
        }
        return;
    }

    // UDP 에서 누적 카운트를 쓰면 정상 유실만으로도 진단이 영구히 남는다. 창 단위로 본다.
    if (_seqChecked < kSeqWindowPackets) {
        return;
    }
    if (_seqAnomalies > kSeqWindowAnomalyLimit) {
        _setDiagnosis(Diagnosis::PacketAnomaly,
                      tr("패킷 이상\n시퀀스 불연속 %1/%2").arg(_seqAnomalies).arg(_seqChecked));
    } else if (_diagnosis == Diagnosis::PacketAnomaly) {
        // 회복했으면 해제한다. 더 근본적인 진단이 떠 있으면 건드리지 않는다.
        _clearDiagnosis();
    }
    _seqChecked = 0;
    _seqAnomalies = 0;
}

void EncryptedRtspClient::_noteRtpAccepted()
{
    _lastRtpMs = QDateTime::currentMSecsSinceEpoch();
    if (_firstRtpMs == 0) {
        _firstRtpMs = _lastRtpMs;
    }
    ++_rtpAccepted;
}

void EncryptedRtspClient::_noteMediaDrop()
{
    ++_mediaDrops;
    // 사용자 관점에서 해석 실패는 시퀀스 불연속과 같은 증상이다. 같은 창에서 함께 센다.
    // 일부만 버려지는 경우는 _checkRtpSequence 의 창 평가에서 드러난다.
    ++_seqAnomalies;
    ++_seqChecked;
}

void EncryptedRtspClient::_inspectDecryptedPayload(const QByteArray &plain)
{
    // H.264 외 코덱은 페이로드 헤더 구조가 달라 이 판정을 적용하면 오탐이 난다.
    if (plain.isEmpty() || _encodingName != QLatin1String("H264")) {
        return;
    }

    const auto nal = static_cast<quint8>(plain.at(0));
    const int type = nal & 0x1f;
    const bool valid = ((nal & 0x80) == 0) && (type >= 1) && (type <= 29);

    if (_sampleChecked < kDiagSampleSize) {
        ++_sampleChecked;
        if (!valid) {
            ++_sampleInvalid;
        }
        if (_sampleChecked < kDiagSampleSize) {
            return;
        }

        if (_sampleInvalid > kDiagInvalidLimit) {
            // 이 판정은 등급이 낮아 NoServerData 가 먼저 뜨면 오버레이에 못 오른다.
            // 그때 남는 유일한 흔적이므로 카테고리 로그에는 반드시 남긴다.
            _traceCause(QStringLiteral("nal-invalid"),
                        QStringLiteral("decrypted payload is not H.264 NAL (%1/%2 invalid), "
                                       "key/IV/alg or framing mismatch")
                            .arg(_sampleInvalid)
                            .arg(_sampleChecked));
            _setDiagnosis(Diagnosis::DecryptFailed,
                          tr("복호화 실패\n알고리즘 및 설정 값 확인 (%1/%2 무효)")
                              .arg(_sampleInvalid)
                              .arg(_sampleChecked));
        } else if (_sampleInvalid > 0) {
            _traceCause(QStringLiteral("nal-partial"),
                        QStringLiteral("decrypted but some NAL broken (%1/%2), "
                                       "transport loss or sender encoding")
                            .arg(_sampleInvalid)
                            .arg(_sampleChecked));
            _setDiagnosis(Diagnosis::CorruptAfterDecrypt,
                          tr("복호화 이후 데이터 손상\n(%1/%2 무효 NAL)")
                              .arg(_sampleInvalid)
                              .arg(_sampleChecked));
        } else {
            _clearDiagnosis();
        }
        return;
    }

    if (!valid) {
        ++_invalidAfterSample;
        if (_invalidAfterSample >= kCorruptInvalidLimit) {
            _setDiagnosis(Diagnosis::CorruptAfterDecrypt,
                          tr("복호화 이후 데이터 손상\n(무효 NAL %1건)").arg(_invalidAfterSample));
        }
    }
}

void EncryptedRtspClient::_onConnected()
{
    if (_stopping) {
        return;
    }
    qCDebug(EncryptedRtspClientLog) << "TCP connected, starting RTSP handshake";
    _phase = RtspPhase::Options;
    _sendNextRequest();
}

void EncryptedRtspClient::_onReadyRead()
{
    if (!_socket || _stopping) {
        return;
    }

    if (_framing == Framing::RtpPayload) {
        // 제어 채널과 RTP 헤더는 평문이다. 암호문은 RTP 페이로드에만 있다.
        _plainBuffer.append(_socket->readAll());
        if (_plainBuffer.size() > kMaxPlainBufferBytes) {
            _fail(QStringLiteral("RTSP receive buffer exceeded limit"));
            return;
        }
        _consumePlain();
        return;
    }

    // 핸드셰이크부터 인터리브까지 제어 채널의 모든 PDU 가 암호 프레임으로 온다.
    _cipherBuffer.append(_socket->readAll());
    if (_cipherBuffer.size() > kMaxCipherBufferBytes) {
        _fail(QStringLiteral("RTSP cipher receive buffer exceeded limit"));
        return;
    }
    _consumeCipherFrames();
}

void EncryptedRtspClient::_consumeCipherFrames()
{
    while (_cipherBuffer.size() >= kCryptoFrameHeaderBytes) {
        const quint32 frameLen =
            qFromBigEndian<quint32>(reinterpret_cast<const uchar *>(_cipherBuffer.constData()));
        // 길이 필드는 평문이므로 프레이밍이 어긋나면 곧바로 비정상 값으로 나타난다.
        if (frameLen == 0 || frameLen > kMaxCryptoFrameBytes) {
            _setDiagnosis(Diagnosis::DecryptFailed,
                          tr("복호화 실패\n암호 프레임 길이 이상 (%1바이트)").arg(frameLen));
            _fail(QStringLiteral("invalid crypto frame length: %1").arg(frameLen));
            return;
        }

        const qsizetype frameSize = kCryptoFrameHeaderBytes + static_cast<qsizetype>(frameLen);
        if (_cipherBuffer.size() < frameSize) {
            return;
        }

        const QByteArray cipher =
            _cipherBuffer.sliced(kCryptoFrameHeaderBytes, static_cast<qsizetype>(frameLen));
        _cipherBuffer.remove(0, frameSize);

        QString error;
        const QByteArray plain =
            TngVideoCryptoService::instance().decryptChunk(cipher, _mode, &error);
        if (plain.size() != cipher.size()) {
            _setDiagnosis(Diagnosis::DecryptFailed,
                          tr("복호화 실패\n알고리즘 및 설정 값 확인 (%1 -> %2바이트)")
                              .arg(cipher.size())
                              .arg(plain.size()));
            _fail(QStringLiteral("RTSP frame decryption failed (%1 -> %2 bytes): %3")
                      .arg(cipher.size())
                      .arg(plain.size())
                      .arg(error));
            return;
        }

        // CTR 은 키가 틀려도 복호가 "성공"한다. 새 PDU 선두가 인터리브 '$' 나 RTSP 토큰인지가
        // 알고리즘·키·IV 불일치를 잡을 유일한 근거다.
        if (_plainBuffer.isEmpty()) {
            const int first = static_cast<quint8>(plain.at(0));
            if (first != '$' && (first < 'A' || first > 'Z')) {
                _setDiagnosis(Diagnosis::DecryptFailed,
                              tr("복호화 실패\n알고리즘 및 설정 값 확인 (선두 0x%1)")
                                  .arg(first, 2, 16, QLatin1Char('0')));
                _fail(QStringLiteral("decrypted frame is neither RTSP nor interleaved (first byte 0x%1)")
                          .arg(first, 2, 16, QLatin1Char('0')));
                return;
            }
        }

        _plainBuffer.append(plain);
        if (_plainBuffer.size() > kMaxPlainBufferBytes) {
            _fail(QStringLiteral("RTSP receive buffer exceeded limit"));
            return;
        }

        _consumePlain();
        if (_stopping || _phase == RtspPhase::Idle) {
            return;
        }
    }
}

void EncryptedRtspClient::_consumePlain()
{
    while (!_plainBuffer.isEmpty()) {
        if (_plainBuffer[0] == '$') {
            if (_plainBuffer.size() < 4) {
                return;
            }
            const auto channel = static_cast<quint8>(_plainBuffer[1]);
            const quint16 payloadLen =
                qFromBigEndian<quint16>(reinterpret_cast<const uchar *>(_plainBuffer.constData() + 2));
            if (payloadLen > kMaxInterleavedPayload) {
                _fail(QStringLiteral("invalid interleaved RTP length: %1").arg(payloadLen));
                return;
            }
            const qsizetype frameSize = 4 + payloadLen;
            if (_plainBuffer.size() < frameSize) {
                return;
            }
            const QByteArray payload = _plainBuffer.sliced(4, payloadLen);
            _plainBuffer.remove(0, frameSize);
            _handleInterleaved(channel, payload);
            if (_stopping || _phase == RtspPhase::Idle) {
                return;
            }
            continue;
        }

        const int headerEnd = _plainBuffer.indexOf("\r\n\r\n");
        if (headerEnd < 0) {
            return;
        }

        const QByteArray headers = _plainBuffer.left(headerEnd);
        const qsizetype headerBytes = headerEnd + 4;
        const QByteArray contentLengthValue = _headerValue(headers, "Content-Length");
        qsizetype bodyLen = 0;
        if (!contentLengthValue.isEmpty()) {
            bool ok = false;
            bodyLen = contentLengthValue.trimmed().toLongLong(&ok);
            if (!ok || bodyLen < 0 || bodyLen > kMaxPlainBufferBytes) {
                _fail(QStringLiteral("invalid RTSP Content-Length"));
                return;
            }
        }

        if (_plainBuffer.size() < headerBytes + bodyLen) {
            return;
        }

        const QByteArray body = _plainBuffer.mid(headerBytes, bodyLen);
        _plainBuffer.remove(0, headerBytes + bodyLen);

        if (!_handleRtspResponse(headers, body)) {
            return;
        }
    }
}

bool EncryptedRtspClient::_bindMediaSockets(QString *error)
{
    // RFC 3550: RTP 는 짝수 포트, RTCP 는 그 다음 홀수 포트여야 한다. 포트 0 으로 바인드해
    // 커널이 준 값이 짝수이고 다음 포트도 비어 있을 때만 채택한다.
    for (int attempt = 0; attempt < kMediaBindAttempts; ++attempt) {
        auto *rtp = new QUdpSocket(this);
        auto *rtcp = new QUdpSocket(this);
        const bool bound = rtp->bind(QHostAddress::AnyIPv4, 0)
                           && (rtp->localPort() % 2 == 0)
                           && rtcp->bind(QHostAddress::AnyIPv4,
                                         static_cast<quint16>(rtp->localPort() + 1));
        if (bound) {
            // 기본 수신 버퍼는 고비트레이트 영상에서 커널 드롭을 유발한다.
            rtp->setSocketOption(QAbstractSocket::ReceiveBufferSizeSocketOption,
                                 kUdpReceiveBufferBytes);
            _rtpSocket = rtp;
            _rtcpSocket = rtcp;
            _clientRtpPort = rtp->localPort();
            _clientRtcpPort = rtcp->localPort();
            connect(_rtpSocket, &QUdpSocket::readyRead, this,
                    &EncryptedRtspClient::_readMediaDatagrams);
            // RTCP 는 디코딩에 쓰지 않는다. 읽어서 버리지 않으면 커널 수신 큐가 찬다.
            connect(_rtcpSocket, &QUdpSocket::readyRead, this, [this]() {
                while (_rtcpSocket && _rtcpSocket->hasPendingDatagrams()) {
                    _rtcpSocket->receiveDatagram();
                }
            });
            qCDebug(EncryptedRtspClientLog) << "Bound media ports" << _clientRtpPort
                                            << _clientRtcpPort;
            return true;
        }
        delete rtp;
        delete rtcp;
    }

    if (error) {
        *error = QStringLiteral("failed to bind an even/odd UDP port pair for RTP/RTCP");
    }
    return false;
}

void EncryptedRtspClient::_readMediaDatagrams()
{
    if (!_rtpSocket || _stopping) {
        return;
    }

    int processed = 0;

    // _pushRtp 실패가 fatalError -> stop() 을 동기로 부르면 루프 도중 _rtpSocket 이 사라진다.
    // stop() 은 끝에서 _stopping 을 false 로 되돌리므로 소켓 자체를 매번 확인해야 한다.
    while (_rtpSocket && _rtpSocket->hasPendingDatagrams() && processed < kMaxDatagramsPerBatch) {
        ++processed;
        const QNetworkDatagram datagram = _rtpSocket->receiveDatagram();
        const QByteArray data = datagram.data();
        // 아래 어느 지점에서 버려지든 "패킷은 도착했다"는 사실은 남겨야 한다.
        // _checkDataFlow 가 이 값으로 "안 옴"과 "와도 못 씀"을 구분한다.
        // 빈 데이터그램(NAT 유도용)은 해석 실패가 아니므로 제외한다. 포함하면 미디어가
        // 전혀 없는데도 형식 불일치로 판정해 재연결을 막는다.
        if (!data.isEmpty()) {
            _lastDatagramMs = QDateTime::currentMSecsSinceEpoch();
        }

        QByteArray rtp;
        if (_framing == Framing::RtpPayload) {
            // 표준 RTP 패킷이 그대로 온다. 페이로드 복호는 _handleRtpPacket 이 한다.
            rtp = data;
        } else {
            if (data.size() <= kCryptoFrameHeaderBytes) {
                if (!data.isEmpty()) {
                    _noteMediaDrop();
                }
                continue;
            }
            const quint32 frameLen =
                qFromBigEndian<quint32>(reinterpret_cast<const uchar *>(data.constData()));
            // UDP 는 경계가 보존되므로 길이 접두가 중복이다. 그 중복을 무결성 검사로 쓴다.
            // 유실·재정렬은 UDP 에서 정상이므로 어긋난 데이터그램만 버리고 세션은 유지한다.
            if (kCryptoFrameHeaderBytes + static_cast<qsizetype>(frameLen) != data.size()) {
                _traceCause(QStringLiteral("udp-frame-length"),
                            QStringLiteral("UDP frame length mismatch: datagram %1 bytes, "
                                           "length field %2, framing may not be rtsp")
                                .arg(data.size())
                                .arg(frameLen));
                _noteMediaDrop();
                continue;
            }

            const QByteArray cipher =
                data.sliced(kCryptoFrameHeaderBytes, static_cast<qsizetype>(frameLen));
            QString error;
            rtp = TngVideoCryptoService::instance().decryptChunk(cipher, _mode, &error);
            if (rtp.size() != cipher.size()) {
                _setDiagnosis(Diagnosis::DecryptFailed,
                              tr("복호화 실패\n알고리즘 및 설정 값 확인 (%1 -> %2바이트)")
                                  .arg(cipher.size())
                                  .arg(rtp.size()));
                // 진단 문구는 코드가 같으면 한 번만 나오므로 엔진이 준 사유는 여기서 남긴다.
                _logCause(QStringLiteral("udp-decrypt-error"),
                          tr("UDP 복호 실패: %1바이트 -> %2바이트%3")
                              .arg(cipher.size())
                              .arg(rtp.size())
                              .arg(error.isEmpty() ? QString() : QStringLiteral("\n%1").arg(error)));
                _noteMediaDrop();
                continue;
            }

            // 송신측이 UDP 에도 TCP 인터리브 헤더($ + 채널 + u16 길이)를 붙인다면 여기서 벗긴다.
            // 아래 세 줄의 주석을 풀면 된다. 지금은 복호 결과가 곧바로 RTP 헤더라고 가정한다.
            // if (rtp.size() > 4 && rtp.at(0) == '$') {
            //     rtp = rtp.sliced(4);
            // }
        }

        if (rtp.size() < kMinRtpHeaderBytes) {
            // 방화벽 유도용 빈 데이터그램 등은 진단 대상이 아니다.
            if (!rtp.isEmpty()) {
                _setDiagnosis(Diagnosis::PacketAnomaly,
                              tr("패킷 이상\nRTP 헤더 길이 부족 (%1바이트)").arg(rtp.size()));
                _noteMediaDrop();
            }
            continue;
        }
        // UDP 는 이상 패킷을 버리기만 하므로 여기서 세지 않으면 아무 흔적도 남지 않는다.
        if (!_handleRtpPacket(rtp, false)) {
            _traceCause(QStringLiteral("udp-rtp-reject"),
                        QStringLiteral("unusable UDP RTP packet: %1 bytes, version=%2, framing=%3 "
                                       "(version != 2 means wrong framing or key)")
                            .arg(rtp.size())
                            .arg(static_cast<quint8>(rtp.at(0)) >> 6)
                            .arg(_framing == Framing::RtspFrame ? QStringLiteral("rtsp")
                                                                : QStringLiteral("payload")));
            _noteMediaDrop();
        }
        if (_phase == RtspPhase::Idle) {
            break;
        }
    }

    // 상한에 걸렸는데 아직 남아 있으면 이벤트 루프에 한 번 양보하고 이어서 처리한다.
    // 남은 것을 여기서 다 비우면 UI 가 멈추고, 버리면 영상이 깨진다.
    if (_rtpSocket && !_stopping && _rtpSocket->hasPendingDatagrams()) {
        QTimer::singleShot(0, this, &EncryptedRtspClient::_readMediaDatagrams);
    }
}

void EncryptedRtspClient::_startKeepalive()
{
    // UDP 로 빼면 제어 소켓이 조용해져 서버가 세션 타임아웃으로 끊는다. 절반 주기로 갱신한다.
    if (!_keepaliveTimer) {
        _keepaliveTimer = new QTimer(this);
        connect(_keepaliveTimer, &QTimer::timeout, this, &EncryptedRtspClient::_sendKeepalive);
    }
    _keepaliveTimer->start(qMax(kMinKeepaliveIntervalMs, _sessionTimeoutSec * 1000 / 2));
}

void EncryptedRtspClient::_sendKeepalive()
{
    if (_stopping || _phase != RtspPhase::Streaming || _session.isEmpty()) {
        return;
    }
    ++_cseq;
    const QByteArray req =
        "OPTIONS " + _requestUri + " RTSP/1.0\r\n"
        "CSeq: " + QByteArray::number(_cseq) + "\r\n"
        "Session: " + _session + "\r\n"
        "User-Agent: QGroundControl-EncryptedRtsp/1.0\r\n"
        "\r\n";
    _sendRtsp(req);
}

bool EncryptedRtspClient::_sendRtsp(const QByteArray &request)
{
    if (!_socket || _socket->state() != QAbstractSocket::ConnectedState) {
        return false;
    }

    const int eol = request.indexOf('\r');
    qCDebug(EncryptedRtspClientLog) << "RTSP TX" << (eol >= 0 ? request.left(eol) : request);

    QByteArray frame = request;
    if (_framing == Framing::RtspFrame) {
        QString error;
        const QByteArray cipher =
            TngVideoCryptoService::instance().encryptChunk(request, _mode, &error);
        if (cipher.size() != request.size()) {
            _fail(QStringLiteral("RTSP request encryption failed (%1 -> %2 bytes): %3")
                      .arg(request.size())
                      .arg(cipher.size())
                      .arg(error));
            return false;
        }

        frame.clear();
        frame.reserve(kCryptoFrameHeaderBytes + cipher.size());
        quint32 lengthBe = 0;
        qToBigEndian<quint32>(static_cast<quint32>(cipher.size()),
                              reinterpret_cast<uchar *>(&lengthBe));
        frame.append(reinterpret_cast<const char *>(&lengthBe), kCryptoFrameHeaderBytes);
        frame.append(cipher);
    }

    if (_socket->write(frame) != frame.size()) {
        _fail(QStringLiteral("RTSP write failed: %1").arg(_socket->errorString()));
        return false;
    }
    // 응답 타임아웃은 요청을 실제로 보낸 시점부터 센다.
    _lastRtspMs = QDateTime::currentMSecsSinceEpoch();
    return true;
}

void EncryptedRtspClient::_sendNextRequest()
{
    ++_cseq;
    QByteArray req;

    switch (_phase) {
    case RtspPhase::Options:
        req = "OPTIONS " + _requestUri + " RTSP/1.0\r\n"
              "CSeq: " + QByteArray::number(_cseq) + "\r\n"
              "User-Agent: QGroundControl-EncryptedRtsp/1.0\r\n"
              "\r\n";
        break;
    case RtspPhase::Describe:
        req = "DESCRIBE " + _requestUri + " RTSP/1.0\r\n"
              "CSeq: " + QByteArray::number(_cseq) + "\r\n"
              "Accept: application/sdp\r\n"
              "User-Agent: QGroundControl-EncryptedRtsp/1.0\r\n"
              "\r\n";
        break;
    case RtspPhase::Setup: {
        // [이전 방식] TCP 인터리브로 고정했다.
        // "Transport: RTP/AVP/TCP;unicast;interleaved=0-1\r\n"
        QByteArray transport("Transport: RTP/AVP/TCP;unicast;interleaved=0-1\r\n");
        if (_rtpTransport == RtpTransport::Udp) {
            transport = "Transport: RTP/AVP;unicast;client_port=";
            transport += QByteArray::number(_clientRtpPort);
            transport += '-';
            transport += QByteArray::number(_clientRtcpPort);
            transport += "\r\n";
        }
        req = "SETUP " + _trackUri + " RTSP/1.0\r\n"
              "CSeq: " + QByteArray::number(_cseq) + "\r\n";
        req += transport;
        req += "User-Agent: QGroundControl-EncryptedRtsp/1.0\r\n"
               "\r\n";
        break;
    }
    case RtspPhase::Play:
        req = "PLAY " + _requestUri + " RTSP/1.0\r\n"
              "CSeq: " + QByteArray::number(_cseq) + "\r\n"
              "Session: " + _session + "\r\n"
              "Range: npt=0.000-\r\n"
              "User-Agent: QGroundControl-EncryptedRtsp/1.0\r\n"
              "\r\n";
        break;
    default:
        return;
    }

    if (!_sendRtsp(req)) {
        return;
    }
}

bool EncryptedRtspClient::_handleRtspResponse(const QByteArray &headers, const QByteArray &body)
{
    const int firstLineEnd = headers.indexOf("\r\n");
    const QByteArray statusLine = firstLineEnd >= 0 ? headers.left(firstLineEnd) : headers;
    qCDebug(EncryptedRtspClientLog) << "RTSP RX" << statusLine;

    _lastRtspMs = QDateTime::currentMSecsSinceEpoch();

    if (!statusLine.startsWith("RTSP/1.0 ")) {
        _fail(QStringLiteral("invalid RTSP response"));
        return false;
    }

    const int code = statusLine.mid(9, 3).toInt();
    if (code == 401 || code == 407) {
        _fail(QStringLiteral("RTSP authentication is not supported"));
        return false;
    }
    if (code < 200 || code >= 300) {
        _fail(QStringLiteral("RTSP request failed: %1").arg(QString::fromLatin1(statusLine)));
        return false;
    }

    switch (_phase) {
    case RtspPhase::Options:
        _phase = RtspPhase::Describe;
        _sendNextRequest();
        return true;

    case RtspPhase::Describe: {
        const QByteArray contentBase = _headerValue(headers, "Content-Base");
        const QByteArray contentLocation = _headerValue(headers, "Content-Location");
        if (!contentBase.isEmpty()) {
            _baseUri = contentBase.trimmed();
        } else if (!contentLocation.isEmpty()) {
            _baseUri = contentLocation.trimmed();
        }
        if (!_baseUri.endsWith('/')) {
            _baseUri.append('/');
        }
        if (!_parseSdp(body)) {
            return false;
        }
        QString pipeError;
        if (!_buildPipeline(&pipeError)) {
            _fail(pipeError);
            return false;
        }
        _phase = RtspPhase::Setup;
        _sendNextRequest();
        return true;
    }

    case RtspPhase::Setup: {
        _session = _headerValue(headers, "Session");
        // timeout 은 세미콜론 뒤 파라미터로 온다. _session 을 자르기 전에 읽어야 한다.
        static const QRegularExpression timeoutRe(QStringLiteral("timeout=(\\d+)"));
        const QRegularExpressionMatch timeout = timeoutRe.match(QString::fromLatin1(_session));
        _sessionTimeoutSec = kDefaultSessionTimeoutSec;
        if (timeout.hasMatch()) {
            const int seconds = timeout.captured(1).toInt();
            if (seconds > 2) {
                _sessionTimeoutSec = seconds;
            }
        }
        const int semicolon = _session.indexOf(';');
        if (semicolon >= 0) {
            _session = _session.left(semicolon);
        }
        _session = _session.trimmed();
        if (_session.isEmpty()) {
            _fail(QStringLiteral("SETUP response missing Session"));
            return false;
        }
        if (!_parseSetupTransport(headers)) {
            return false;
        }
        _phase = RtspPhase::Play;
        _sendNextRequest();
        return true;
    }

    case RtspPhase::Play:
        _phase = RtspPhase::Streaming;
        _streamingSinceMs = _lastRtspMs;
        _startKeepalive();
        qCDebug(EncryptedRtspClientLog) << "PLAY ok, streaming"
                                        << (_rtpTransport == RtpTransport::Udp ? "UDP" : "interleaved")
                                        << "encoding" << _encodingName
                                        << "rtp-ch" << _videoRtpChannel
                                        << "keepalive-s" << _sessionTimeoutSec / 2;
        return true;

    default:
        return true;
    }
}

bool EncryptedRtspClient::_parseSdp(const QByteArray &sdp)
{
    const QList<QByteArray> lines = sdp.split('\n');
    bool inVideo = false;
    QByteArray control;
    QString encoding;
    int clockRate = 90000;
    int payloadType = -1;

    for (QByteArray line : lines) {
        if (line.endsWith('\r')) {
            line.chop(1);
        }
        if (line.startsWith("m=")) {
            inVideo = line.startsWith("m=video");
            if (inVideo) {
                const QList<QByteArray> parts = line.split(' ');
                if (parts.size() >= 4) {
                    bool ok = false;
                    const int pt = parts.last().toInt(&ok);
                    if (ok) {
                        payloadType = pt;
                    }
                }
                control.clear();
                encoding.clear();
            }
            continue;
        }
        if (!inVideo) {
            continue;
        }
        if (line.startsWith("a=control:")) {
            control = line.mid(10).trimmed();
        } else if (line.startsWith("a=rtpmap:")) {
            // a=rtpmap:<pt> <encoding>/<clock>[/channels]
            const QByteArray value = line.mid(9).trimmed();
            const int space = value.indexOf(' ');
            if (space <= 0) {
                continue;
            }
            bool ok = false;
            const int pt = value.left(space).toInt(&ok);
            if (!ok) {
                continue;
            }
            payloadType = pt;
            const QByteArray rest = value.mid(space + 1);
            const int slash = rest.indexOf('/');
            encoding = QString::fromLatin1(slash >= 0 ? rest.left(slash) : rest).trimmed().toUpper();
            if (slash >= 0) {
                const QByteArray ratePart = rest.mid(slash + 1);
                const int nextSlash = ratePart.indexOf('/');
                clockRate = (nextSlash >= 0 ? ratePart.left(nextSlash) : ratePart).toInt(&ok);
                if (!ok || clockRate <= 0) {
                    clockRate = 90000;
                }
            }
        }
    }

    if (encoding.isEmpty()) {
        _fail(QStringLiteral("SDP has no video rtpmap (H264/H265/etc)"));
        return false;
    }

    // QGC Video Source에 대응하는 RTSP/RTP 코덱. decodebin이 플러그 가능한 범위.
    static const QStringList kSupported = {
        QStringLiteral("H264"),
        QStringLiteral("H265"),
        QStringLiteral("HEVC"),
        QStringLiteral("MP4V-ES"),
        QStringLiteral("JPEG"),
        QStringLiteral("MP2T"),
    };
    if (!kSupported.contains(encoding)) {
        _fail(QStringLiteral("unsupported RTP encoding in SDP: %1").arg(encoding));
        return false;
    }
    if (encoding == QLatin1String("HEVC")) {
        encoding = QStringLiteral("H265");
    }

    if (control.isEmpty()) {
        _fail(QStringLiteral("SDP video track missing a=control"));
        return false;
    }

    if (control.size() >= 7
        && control.first(7).compare("rtsp://", Qt::CaseInsensitive) == 0) {
        _trackUri = control;
    } else if (control == "*") {
        _trackUri = _requestUri;
    } else {
        _trackUri = _baseUri + control;
    }

    _encodingName = encoding;
    _clockRate = clockRate;
    if (payloadType >= 0) {
        _payloadType = payloadType;
    }

    qCDebug(EncryptedRtspClientLog) << "SDP video" << _encodingName << "pt" << _payloadType
                                    << "rate" << _clockRate << "track" << _trackUri;
    return true;
}

bool EncryptedRtspClient::_parseSetupTransport(const QByteArray &headers)
{
    const QByteArray transport = _headerValue(headers, "Transport");
    if (transport.isEmpty()) {
        _fail(QStringLiteral("SETUP response missing Transport"));
        return false;
    }

    // [이전 방식] interleaved 가 없으면 실패로 처리했다.
    // static const QRegularExpression re(QStringLiteral("interleaved=(\\d+)-(\\d+)"));
    // const QRegularExpressionMatch match = re.match(QString::fromLatin1(transport));
    // if (!match.hasMatch()) {
    //     _fail(...);
    //     return false;
    // }
    // _videoRtpChannel = match.captured(1).toInt();
    // _videoRtcpChannel = match.captured(2).toInt();

    // 서버는 요청한 전송을 거부하고 다른 것을 줄 수 있다. 요청이 아니라 응답을 기준으로 삼는다.
    const QString value = QString::fromLatin1(transport);

    static const QRegularExpression interleavedRe(QStringLiteral("interleaved=(\\d+)-(\\d+)"));
    const QRegularExpressionMatch interleaved = interleavedRe.match(value);
    if (interleaved.hasMatch()) {
        _rtpTransport = RtpTransport::TcpInterleaved;
        _videoRtpChannel = interleaved.captured(1).toInt();
        _videoRtcpChannel = interleaved.captured(2).toInt();
        return true;
    }

    static const QRegularExpression serverPortRe(QStringLiteral("server_port=(\\d+)(?:-(\\d+))?"));
    const QRegularExpressionMatch serverPort = serverPortRe.match(value);
    if (serverPort.hasMatch()) {
        _serverRtpPort = serverPort.captured(1).toUShort();
        _serverRtcpPort = serverPort.captured(2).isEmpty()
                              ? static_cast<quint16>(_serverRtpPort + 1)
                              : serverPort.captured(2).toUShort();
    }

    if (_rtpTransport != RtpTransport::Udp) {
        _fail(QStringLiteral("SETUP Transport has neither interleaved nor server_port: %1").arg(value));
        return false;
    }

    if (_serverRtpPort == 0) {
        // 수신만 하면 되므로 계속 진행하되, 서버가 UDP 를 반쯤만 승인한 상태를 기록한다.
        // 이걸 남기지 않으면 뒤이어 뜨는 NoServerData 의 원인이 가려진다.
        _traceCause(QStringLiteral("no-server-port"),
                    QStringLiteral("SETUP response has no server_port: %1, "
                                   "server may not have accepted UDP transport").arg(value));
    }

    // 방화벽이 인바운드를 막아 데이터가 없으면, 여기서 _rtpSocket 으로 서버
    // (_socket->peerAddress(), _serverRtpPort) 에 빈 데이터그램을 보내 상태 추적 규칙을
    // 열어 주는 방법을 시험한다. 같은 서브넷 직결에서는 불필요하다.
    qCDebug(EncryptedRtspClientLog) << "UDP media transport" << value
                                    << "client" << _clientRtpPort << "server" << _serverRtpPort;
    return true;
}

bool EncryptedRtspClient::_buildPipeline(QString *error)
{
#ifdef QGC_GST_STREAMING
    _teardownPipeline();

    _videoSink = QGCCorePlugin::instance()->createVideoSink(_videoOutput, this);
    if (!_videoSink) {
        if (error) {
            *error = QStringLiteral("createVideoSink failed");
        }
        return false;
    }

    GstElement *pipeline = gst_pipeline_new("encrypted-rtsp");
    GstElement *appsrc = gst_element_factory_make("appsrc", "enc-rtsp-appsrc");
    GstElement *jitter = gst_element_factory_make("rtpjitterbuffer", "enc-rtsp-jitter");
    GstElement *decode = gst_element_factory_make("decodebin3", "enc-rtsp-decode");
    GstElement *queue = gst_element_factory_make("queue", "enc-rtsp-queue");
    auto *sink = static_cast<GstElement *>(_videoSink);

    if (!pipeline || !appsrc || !jitter || !decode || !queue || !sink) {
        if (error) {
            *error = QStringLiteral("failed to create GStreamer elements for encrypted RTSP");
        }
        if (pipeline) {
            gst_object_unref(pipeline);
        }
        if (appsrc) {
            gst_object_unref(appsrc);
        }
        if (jitter) {
            gst_object_unref(jitter);
        }
        if (decode) {
            gst_object_unref(decode);
        }
        if (queue) {
            gst_object_unref(queue);
        }
        _teardownPipeline();
        return false;
    }

    const QString capsStr = QStringLiteral(
                                "application/x-rtp, media=(string)video, clock-rate=(int)%1, "
                                "encoding-name=(string)%2, payload=(int)%3")
                                .arg(_clockRate)
                                .arg(_encodingName)
                                .arg(_payloadType);
    GstCaps *caps = gst_caps_from_string(capsStr.toUtf8().constData());
    if (!caps) {
        if (error) {
            *error = QStringLiteral("failed to build RTP caps");
        }
        gst_object_unref(pipeline);
        gst_object_unref(appsrc);
        gst_object_unref(jitter);
        gst_object_unref(decode);
        gst_object_unref(queue);
        _teardownPipeline();
        return false;
    }

    g_object_set(appsrc,
                 "is-live", TRUE,
                 "format", GST_FORMAT_TIME,
                 "block", FALSE,
                 "max-bytes", static_cast<guint64>(2 * 1024 * 1024),
                 "caps", caps,
                 nullptr);
    gst_caps_unref(caps);

    g_object_set(jitter, "latency", 50, nullptr);
    g_object_set(sink, "widget", _videoOutput, "sync", FALSE, nullptr);

    gst_bin_add_many(GST_BIN(pipeline), appsrc, jitter, decode, queue, sink, nullptr);
    if (!gst_element_link(appsrc, jitter) || !gst_element_link(jitter, decode)) {
        if (error) {
            *error = QStringLiteral("failed to link appsrc/jitter/decodebin");
        }
        // pipeline owns children after gst_bin_add_many
        gst_element_set_state(pipeline, GST_STATE_NULL);
        gst_object_unref(pipeline);
        _videoSink = nullptr;
        _pipeline = nullptr;
        _appsrc = nullptr;
        return false;
    }
    if (!gst_element_link(queue, sink)) {
        if (error) {
            *error = QStringLiteral("failed to link queue/sink");
        }
        gst_element_set_state(pipeline, GST_STATE_NULL);
        gst_object_unref(pipeline);
        _videoSink = nullptr;
        _pipeline = nullptr;
        _appsrc = nullptr;
        return false;
    }

    g_signal_connect(decode, "pad-added", G_CALLBACK(_onDecodePadAdded), this);

    const GstStateChangeReturn ret = gst_element_set_state(pipeline, GST_STATE_PLAYING);
    if (ret == GST_STATE_CHANGE_FAILURE) {
        if (error) {
            *error = QStringLiteral("failed to set encrypted RTSP pipeline to PLAYING");
        }
        gst_element_set_state(pipeline, GST_STATE_NULL);
        gst_object_unref(pipeline);
        _videoSink = nullptr;
        return false;
    }

    // sink ownership moved into pipeline
    _pipeline = pipeline;
    _appsrc = appsrc;
    _videoSink = nullptr;

    if (!_busTimer) {
        _busTimer = new QTimer(this);
        connect(_busTimer, &QTimer::timeout, this, &EncryptedRtspClient::_pollBus);
    }
    _busTimer->start(100);

    qCDebug(EncryptedRtspClientLog) << "Pipeline ready" << capsStr;
    return true;
#else
    if (error) {
        *error = QStringLiteral("GStreamer streaming is not enabled");
    }
    return false;
#endif
}

void EncryptedRtspClient::_teardownPipeline()
{
#ifdef QGC_GST_STREAMING
    if (_busTimer) {
        _busTimer->stop();
    }

    if (_pipeline) {
        auto *pipeline = static_cast<GstElement *>(_pipeline);
        gst_element_set_state(pipeline, GST_STATE_NULL);
        gst_object_unref(pipeline);
        _pipeline = nullptr;
        _appsrc = nullptr;
    }

    if (_videoSink) {
        QGCCorePlugin::instance()->releaseVideoSink(_videoSink);
        _videoSink = nullptr;
    }
#endif
}

void EncryptedRtspClient::_handleInterleaved(quint8 channel, const QByteArray &payload)
{
    if (_phase != RtspPhase::Streaming && _phase != RtspPhase::Play) {
        return;
    }
    if (channel != static_cast<quint8>(_videoRtpChannel)) {
        return; // RTCP / other
    }
    _lastDatagramMs = QDateTime::currentMSecsSinceEpoch();
    if (payload.size() < kMinRtpHeaderBytes) {
        _setDiagnosis(Diagnosis::PacketAnomaly,
                      tr("패킷 이상\nRTP 헤더 길이 부족 (%1바이트)").arg(payload.size()));
        return;
    }

    // TCP 는 스트림이 어긋나면 복구가 불가능하므로 이상을 치명적으로 다룬다.
    // 여기서 실패하면 _fail 이 Console 까지 이유를 올리므로 별도 집계가 필요 없다.
    (void) _handleRtpPacket(payload, true);
}

bool EncryptedRtspClient::_handleRtpPacket(const QByteArray &rtp, bool fatal)
{
    if (_framing == Framing::RtpPayload) {
        QByteArray plainRtp;
        if (!_decryptRtpPayload(rtp, fatal, &plainRtp)) {
            return false;
        }
        _noteRtpAccepted();
        _pushRtp(plainRtp);
        return true;
    }

    // RtspFrame 에서는 바깥 암호 프레임을 이미 복호했으므로 안쪽이 표준 RTP 패킷이다.
    if (!_inspectRtpPacket(rtp, fatal)) {
        return false;
    }
    _noteRtpAccepted();
    _pushRtp(rtp);
    return true;
}

bool EncryptedRtspClient::_inspectRtpPacket(const QByteArray &rtp, bool fatal)
{
    const auto *bytes = reinterpret_cast<const quint8 *>(rtp.constData());
    if ((bytes[0] >> 6) != 2) {
        _setDiagnosis(Diagnosis::PacketAnomaly,
                      tr("패킷 이상\nRTP 버전 불일치 (%1)").arg(bytes[0] >> 6));
        // TCP 는 스트림이 어긋나면 복구가 불가능해 치명적이다. UDP 는 남의 패킷이 섞여
        // 들어올 수 있으므로 해당 데이터그램만 버린다.
        if (fatal) {
            _fail(QStringLiteral("unexpected RTP version %1 (frame framing mismatch)")
                      .arg(bytes[0] >> 6));
        }
        return false;
    }

    _checkRtpSequence(qFromBigEndian<quint16>(bytes + 2));

    const bool hasPadding = (bytes[0] & 0x20) != 0;
    const bool hasExtension = (bytes[0] & 0x10) != 0;
    qsizetype headerLen = kMinRtpHeaderBytes + 4 * (bytes[0] & 0x0f);

    if (hasExtension) {
        if (rtp.size() < headerLen + 4) {
            qCDebug(EncryptedRtspClientLog) << "RTP extension header truncated, dropping" << rtp.size();
            return false;
        }
        const quint16 extWords = qFromBigEndian<quint16>(bytes + headerLen + 2);
        headerLen += 4 + 4 * static_cast<qsizetype>(extWords);
    }

    const qsizetype paddingLen = hasPadding ? static_cast<quint8>(rtp.at(rtp.size() - 1)) : 0;
    const qsizetype payloadLen = rtp.size() - headerLen - paddingLen;
    if (headerLen >= rtp.size() || payloadLen <= 0) {
        qCDebug(EncryptedRtspClientLog) << "RTP packet has no payload, dropping"
                                        << rtp.size() << headerLen << paddingLen;
        return false;
    }

    _inspectDecryptedPayload(rtp.sliced(headerLen, payloadLen));
    return true;
}

bool EncryptedRtspClient::_decryptRtpPayload(const QByteArray &rtp, bool fatal, QByteArray *plainRtp)
{
    const auto *bytes = reinterpret_cast<const quint8 *>(rtp.constData());
    if ((bytes[0] >> 6) != 2) {
        _setDiagnosis(Diagnosis::PacketAnomaly,
                      tr("패킷 이상\nRTP 버전 불일치 (%1)").arg(bytes[0] >> 6));
        if (fatal) {
            _fail(QStringLiteral("unexpected RTP version %1 (payload framing mismatch)")
                      .arg(bytes[0] >> 6));
        }
        return false;
    }

    _checkRtpSequence(qFromBigEndian<quint16>(bytes + 2));

    const bool hasPadding = (bytes[0] & 0x20) != 0;
    const bool hasExtension = (bytes[0] & 0x10) != 0;
    qsizetype headerLen = kMinRtpHeaderBytes + 4 * (bytes[0] & 0x0f);

    if (hasExtension) {
        if (rtp.size() < headerLen + 4) {
            qCDebug(EncryptedRtspClientLog) << "RTP extension header truncated, dropping" << rtp.size();
            return false;
        }
        const quint16 extWords = qFromBigEndian<quint16>(bytes + headerLen + 2);
        headerLen += 4 + 4 * static_cast<qsizetype>(extWords);
    }

    // 송신측은 RTP 헤더 뒤부터(FU-A/단일 NAL 헤더 포함) 패킷 단위로 암호화한다.
    qsizetype paddingLen = 0;
    if (hasPadding) {
        paddingLen = static_cast<quint8>(rtp.at(rtp.size() - 1));
    }

    const qsizetype cipherLen = rtp.size() - headerLen - paddingLen;
    if (headerLen >= rtp.size() || cipherLen <= 0) {
        qCDebug(EncryptedRtspClientLog) << "RTP packet has no payload, dropping"
                                        << rtp.size() << headerLen << paddingLen;
        return false;
    }

    QString error;
    const QByteArray plain =
        TngVideoCryptoService::instance().decryptChunk(rtp.sliced(headerLen, cipherLen), _mode, &error);
    if (plain.size() != cipherLen) {
        _setDiagnosis(Diagnosis::DecryptFailed,
                      tr("복호화 실패\n알고리즘 및 설정 값 확인 (%1 -> %2바이트)")
                          .arg(cipherLen)
                          .arg(plain.size()));
        if (fatal) {
            _fail(QStringLiteral("RTP payload decryption failed (%1 -> %2 bytes): %3")
                      .arg(cipherLen)
                      .arg(plain.size())
                      .arg(error));
        } else {
            // UDP 는 세션을 끊지 않으므로 사유가 남지 않으면 그대로 묻힌다.
            _logCause(QStringLiteral("payload-decrypt-error"),
                      tr("RTP 페이로드 복호 실패: %1바이트 -> %2바이트%3")
                          .arg(cipherLen)
                          .arg(plain.size())
                          .arg(error.isEmpty() ? QString() : QStringLiteral("\n%1").arg(error)));
        }
        return false;
    }

    _inspectDecryptedPayload(plain);

    plainRtp->clear();
    plainRtp->reserve(rtp.size());
    plainRtp->append(rtp.first(headerLen));
    plainRtp->append(plain);
    if (paddingLen > 0) {
        plainRtp->append(rtp.last(paddingLen));
    }
    return true;
}

void EncryptedRtspClient::_onDecodePadAdded(void *decode, void *pad, void *userData)
{
    Q_UNUSED(decode);
    auto *self = static_cast<EncryptedRtspClient *>(userData);
    if (self) {
        self->_linkDecodePad(pad);
    }
}

void EncryptedRtspClient::_linkDecodePad(void *padPtr)
{
#ifdef QGC_GST_STREAMING
    if (!_pipeline || _stopping || !padPtr) {
        return;
    }

    auto *pad = static_cast<GstPad *>(padPtr);
    auto *pipe = static_cast<GstElement *>(_pipeline);
    GstElement *queueEl = gst_bin_get_by_name(GST_BIN(pipe), "enc-rtsp-queue");
    if (!queueEl) {
        return;
    }

    GstPad *sinkPad = gst_element_get_static_pad(queueEl, "sink");
    if (sinkPad && !gst_pad_is_linked(sinkPad)) {
        GstCaps *padCaps = gst_pad_get_current_caps(pad);
        if (!padCaps) {
            padCaps = gst_pad_query_caps(pad, nullptr);
        }
        bool isVideo = false;
        if (padCaps && !gst_caps_is_empty(padCaps)) {
            const GstStructure *st = gst_caps_get_structure(padCaps, 0);
            const gchar *name = st ? gst_structure_get_name(st) : nullptr;
            isVideo = name && g_str_has_prefix(name, "video/");
        }
        if (padCaps) {
            gst_caps_unref(padCaps);
        }
        if (isVideo && gst_pad_link(pad, sinkPad) == GST_PAD_LINK_OK) {
            _decodePadLinked = true;
        }
    }
    gst_clear_object(&sinkPad);
    gst_object_unref(queueEl);
#else
    Q_UNUSED(padPtr);
#endif
}

void EncryptedRtspClient::_pushRtp(const QByteArray &rtp)
{
#ifdef QGC_GST_STREAMING
    if (!_appsrc || _stopping) {
        return;
    }

    GstBuffer *buffer = gst_buffer_new_allocate(nullptr, static_cast<gsize>(rtp.size()), nullptr);
    if (!buffer) {
        _fail(QStringLiteral("gst_buffer_new_allocate failed"));
        return;
    }

    GstMapInfo map;
    if (!gst_buffer_map(buffer, &map, GST_MAP_WRITE)) {
        gst_buffer_unref(buffer);
        _fail(QStringLiteral("gst_buffer_map failed"));
        return;
    }
    memcpy(map.data, rtp.constData(), static_cast<size_t>(rtp.size()));
    gst_buffer_unmap(buffer, &map);
    GST_BUFFER_DTS(buffer) = GST_CLOCK_TIME_NONE;
    GST_BUFFER_PTS(buffer) = GST_CLOCK_TIME_NONE;

    GstFlowReturn flow = GST_FLOW_ERROR;
    g_signal_emit_by_name(static_cast<GstElement *>(_appsrc), "push-buffer", buffer, &flow);
    gst_buffer_unref(buffer);

    if (flow != GST_FLOW_OK && flow != GST_FLOW_FLUSHING) {
        _fail(QStringLiteral("appsrc push-buffer failed: %1").arg(static_cast<int>(flow)));
    }
#else
    Q_UNUSED(rtp);
#endif
}

void EncryptedRtspClient::_pollBus()
{
#ifdef QGC_GST_STREAMING
    if (!_pipeline || _stopping) {
        return;
    }

    GstBus *bus = gst_element_get_bus(static_cast<GstElement *>(_pipeline));
    if (!bus) {
        return;
    }

    while (true) {
        GstMessage *msg = gst_bus_pop_filtered(
            bus, static_cast<GstMessageType>(GST_MESSAGE_ERROR | GST_MESSAGE_EOS | GST_MESSAGE_WARNING));
        if (!msg) {
            break;
        }
        // 파서·디코더 경고는 복호는 됐지만 비트스트림이 깨진 경우다. 세션을 끊지 않고 표시만 한다.
        if (GST_MESSAGE_TYPE(msg) == GST_MESSAGE_WARNING) {
            GError *warn = nullptr;
            gchar *dbg = nullptr;
            gst_message_parse_warning(msg, &warn, &dbg);
            const QString text = warn ? QString::fromUtf8(warn->message) : QStringLiteral("decode warning");
            g_clear_error(&warn);
            g_free(dbg);
            gst_message_unref(msg);
            _traceCause(QStringLiteral("gst-warning"),
                        QStringLiteral("decoder warning: %1").arg(text));
            _setDiagnosis(Diagnosis::CorruptAfterDecrypt,
                          tr("복호화 이후 데이터 손상\n%1").arg(text));
            continue;
        }
        if (GST_MESSAGE_TYPE(msg) == GST_MESSAGE_ERROR) {
            GError *err = nullptr;
            gchar *dbg = nullptr;
            gst_message_parse_error(msg, &err, &dbg);
            const QString text = err ? QString::fromUtf8(err->message) : QStringLiteral("GStreamer error");
            g_clear_error(&err);
            g_free(dbg);
            gst_message_unref(msg);
            gst_object_unref(bus);
            _fail(QStringLiteral("encrypted RTSP pipeline error: %1").arg(text));
            return;
        }
        if (GST_MESSAGE_TYPE(msg) == GST_MESSAGE_EOS) {
            gst_message_unref(msg);
            gst_object_unref(bus);
            _fail(QStringLiteral("encrypted RTSP pipeline EOS"));
            return;
        }
        gst_message_unref(msg);
    }
    gst_object_unref(bus);
#endif
}

QByteArray EncryptedRtspClient::_headerValue(const QByteArray &headers, const QByteArray &name)
{
    const QList<QByteArray> lines = headers.split('\n');
    const QByteArray prefix = name + ":";
    for (QByteArray line : lines) {
        if (line.endsWith('\r')) {
            line.chop(1);
        }
        if (line.size() >= prefix.size()
            && line.left(prefix.size()).compare(prefix, Qt::CaseInsensitive) == 0) {
            return line.mid(prefix.size()).trimmed();
        }
    }
    return {};
}
