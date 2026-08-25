#pragma once

#include "TngVideoCryptoService.h"

#include <QtCore/QByteArray>
#include <QtCore/QObject>
#include <QtCore/QSet>
#include <QtCore/QUrl>

class QQuickItem;
class QTcpSocket;
class QTimer;
class QUdpSocket;

class EncryptedRtspClient : public QObject
{
    Q_OBJECT

public:
    /// 화면 중앙 오버레이에 표시할 진단 상태. 값이 클수록 근본 원인에 가깝다.
    enum class Diagnosis {
        None = 0,
        CorruptAfterDecrypt = 1, // 복호화 이후 데이터 손상
        PacketAnomaly = 2,       // RTP 시퀀스/헤더 이상
        DecryptFailed = 3,       // 복호화 실패 (알고리즘·키·IV 불일치)
        NoServerData = 4,        // 서버가 데이터를 주지 않음
        StartFailed = 5,         // 클라이언트를 시작조차 못함 (암호 코어 취득/전송 설정 오류)
        SessionEnded = 6,        // 서버가 끊어져 세션 종료 (재접속 없음)
    };

    explicit EncryptedRtspClient(QObject *parent = nullptr);
    ~EncryptedRtspClient() override;

    bool start(const QUrl &remoteUrl,
               TngVideoCryptoService::SpeedMode mode,
               QQuickItem *videoOutput,
               QString *error = nullptr);
    void stop();

signals:
    void fatalError(const QString &message);
    void sessionEnded(const QString &message);
    void diagnosisChanged(int code, const QString &message);
    /// 재생 실패의 근본 원인. 오버레이 등급/중복 규칙과 무관하게 Console 에 그대로 남긴다.
    void causeLogged(const QString &line);

private:
    enum class RtspPhase {
        Idle,
        Connecting,
        Options,
        Describe,
        Setup,
        Play,
        Streaming,
    };

    /// RTSP 세션이 실어 나르는 RTP 의 하위 전송. 최종 값은 SETUP 응답이 결정한다.
    enum class RtpTransport {
        TcpInterleaved,
        Udp,
    };

    void _fail(const QString &message);
    void _onConnected();
    void _onReadyRead();
    void _consumePlain();
    bool _sendRtsp(const QByteArray &request);
    void _sendNextRequest();
    bool _handleRtspResponse(const QByteArray &headers, const QByteArray &body);
    bool _parseSdp(const QByteArray &sdp);
    bool _parseSetupTransport(const QByteArray &headers);
    bool _buildPipeline(QString *error);
    void _teardownPipeline();
    void _pushRtp(const QByteArray &rtp);
    void _pollBus();
    void _handleInterleaved(quint8 channel, const QByteArray &payload);
    /// 제어 채널의 [u32 BE 길이][암호문] 프레임을 복호해 평문 버퍼로 옮긴다.
    void _consumeCipherFrames();
    /// SETUP 전에 RTP/RTCP 수신 포트를 확보한다. client_port 를 알려주려면 먼저 바인드해야 한다.
    bool _bindMediaSockets(QString *error);
    /// UDP 데이터그램은 유실·재정렬되므로 누적 버퍼 없이 하나씩 독립 처리한다.
    void _readMediaDatagrams();
    void _startKeepalive();
    void _sendKeepalive();
    /// 전송(TCP 인터리브/UDP)에서 받은 RTP 패킷 하나를 프레이밍에 맞게 처리해 파이프라인에 넣는다.
    /// fatal 이 false 면 이상 패킷을 버리기만 한다(UDP 는 유실이 정상이다).
    /// 파이프라인에 넣지 못하면 false 를 돌려준다.
    bool _handleRtpPacket(const QByteArray &rtp, bool fatal);
    /// 평문 RTP 패킷의 헤더를 검증하고 페이로드 선두로 복호 상태를 진단한다.
    bool _inspectRtpPacket(const QByteArray &rtp, bool fatal);
    /// RTP 헤더는 평문, 페이로드만 암호문인 패킷을 표준 RTP 패킷으로 복원한다.
    bool _decryptRtpPayload(const QByteArray &rtp, bool fatal, QByteArray *plainRtp);
    /// 복호 결과 선두 바이트가 유효한 H.264 NAL/FU 헤더인지 집계해 설정 불일치와 손상을 구분한다.
    void _inspectDecryptedPayload(const QByteArray &plain);
    void _checkRtpSequence(quint16 seq);
    /// 검증을 통과해 디코더로 넘어가는 RTP 만 여기서 집계한다.
    void _noteRtpAccepted();
    /// 해석하지 못한 데이터그램을 집계한다. 조용히 버리면 원인 추적이 불가능해진다.
    void _noteMediaDrop();
    void _checkDataFlow();
    void _setDiagnosis(Diagnosis diagnosis, const QString &message);
    void _clearDiagnosis();
    void _resetDiagnosisState();
    /// 같은 원인은 한 세션에 한 번만 남긴다. key 는 원인 종류, line 은 Console 문구다.
    void _logCause(const QString &key, const QString &line);
    /// _logCause 와 같은 중복 억제를 쓰지만 Console 에는 올리지 않는다. 원인 추적용 상세 로그다.
    void _traceCause(const QString &key, const QString &line);
    void _linkDecodePad(void *pad);

    static void _onDecodePadAdded(void *decode, void *pad, void *userData);
    static QByteArray _headerValue(const QByteArray &headers, const QByteArray &name);

    QUrl _remoteUrl;
    QByteArray _requestUri;
    QByteArray _baseUri;
    QByteArray _trackUri;
    QByteArray _session;
    QString _encodingName;
    int _clockRate = 90000;
    int _payloadType = 96;
    int _videoRtpChannel = 0;
    int _videoRtcpChannel = 1;
    quint16 _clientRtpPort = 0;
    quint16 _clientRtcpPort = 0;
    quint16 _serverRtpPort = 0;
    quint16 _serverRtcpPort = 0;
    int _sessionTimeoutSec = 60;
    int _cseq = 0;
    RtspPhase _phase = RtspPhase::Idle;
    RtpTransport _rtpTransport = RtpTransport::TcpInterleaved;
    TngVideoCryptoService::SpeedMode _mode = TngVideoCryptoService::SpeedMode::Normal;
    TngVideoCryptoService::Framing _framing = TngVideoCryptoService::Framing::RtpPayload;
    bool _cryptoAcquired = false;
    bool _stopping = false;

    QTcpSocket *_socket = nullptr;
    QUdpSocket *_rtpSocket = nullptr;
    QUdpSocket *_rtcpSocket = nullptr;
    QTimer *_busTimer = nullptr;
    QTimer *_watchTimer = nullptr;
    QTimer *_keepaliveTimer = nullptr;
    QQuickItem *_videoOutput = nullptr;

    QByteArray _cipherBuffer;
    QByteArray _plainBuffer;

    Diagnosis _diagnosis = Diagnosis::None;
    QString _diagnosisMessage;
    QSet<QString> _loggedCauses;
    bool _decodePadLinked = false;
    qint64 _lastRtspMs = 0;
    // 검증을 통과해 실제로 디코더에 넣은 RTP 의 시각. 도착 사실(_lastDatagramMs)과 반드시
    // 구분해야 한다. 합치면 해석 불가능한 패킷이 계속 와도 "정상 수신"으로 보인다.
    qint64 _lastRtpMs = 0;
    qint64 _lastDatagramMs = 0;
    quint64 _rtpAccepted = 0;
    qint64 _firstRtpMs = 0;

    // RTP 가 한 번도 오지 않은 경우의 기준점. _lastRtspMs 는 keepalive 응답으로 갱신되어
    // "RTP 없음" 경과 시간을 재는 데 쓸 수 없다.
    qint64 _streamingSinceMs = 0;
    quint16 _lastSeq = 0;
    bool _haveLastSeq = false;
    int _seqAnomalies = 0;
    int _seqChecked = 0;
    qint64 _mediaDrops = 0;
    int _sampleChecked = 0;
    int _sampleInvalid = 0;
    int _invalidAfterSample = 0;

#ifdef QGC_GST_STREAMING
    void *_pipeline = nullptr;
    void *_appsrc = nullptr;
    void *_videoSink = nullptr;
#endif
};
