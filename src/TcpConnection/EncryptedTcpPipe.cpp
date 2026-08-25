#include "EncryptedTcpPipe.h"
#include "CryptoLinkMonitor.h"
#include "MAVLinkLib.h"
#include "QGCLogging.h"

#include <QtCore/QDateTime>
#include <QtCore/QtEndian>

namespace {

/// 무효 청크가 이 횟수만큼 연속되면 경고를 남긴다.
/// TCP 재분할로 청크 하나가 통째로 깨지는 것은 정상 통신에서도 일어나므로 1회로는 판단하지 않는다.
constexpr int kInvalidWarnStreak = 5;

constexpr int kWatchdogIntervalMs = 1000;

constexpr quint8 kMavlinkStxV2 = 0xFD;
constexpr quint8 kMavlinkStxV1 = 0xFE;

/// 버퍼 안의 유효한 MAVLink v1/v2 프레임 개수를 센다.
/// 고정 IV CTR 은 청크 경계가 어긋나면 앞뒤에 쓰레기가 섞이므로 모든 위치에서 STX 를 찾고,
/// 길이·플래그·msgid 뿐 아니라 CRC(crc_extra 포함)까지 맞아야 유효로 인정한다.
int countValidMavlinkFrames(const QByteArray &data)
{
    const auto *buf = reinterpret_cast<const quint8 *>(data.constData());
    const int size = data.size();
    int found = 0;

    for (int i = 0; i < size; ++i) {
        int headerLen = 0;
        int frameLen = 0;
        quint32 msgId = 0;
        const int payloadLen = (i + 1 < size) ? buf[i + 1] : 0;

        if (buf[i] == kMavlinkStxV2) {
            if (i + 12 > size) {
                continue;
            }
            const quint8 incompat = buf[i + 2];
            if (incompat & ~static_cast<quint8>(MAVLINK_IFLAG_SIGNED)) {
                continue;                                // 정의되지 않은 플래그
            }
            headerLen = 10;
            msgId = static_cast<quint32>(buf[i + 7])
                  | (static_cast<quint32>(buf[i + 8]) << 8)
                  | (static_cast<quint32>(buf[i + 9]) << 16);
            frameLen = payloadLen + 12 + ((incompat & MAVLINK_IFLAG_SIGNED) ? MAVLINK_SIGNATURE_BLOCK_LEN : 0);
        } else if (buf[i] == kMavlinkStxV1) {
            if (i + 8 > size) {
                continue;
            }
            headerLen = 6;
            msgId = buf[i + 5];
            frameLen = payloadLen + 8;
        } else {
            continue;
        }

        if (i + frameLen > size) {
            continue;
        }

        const mavlink_msg_entry_t *entry = mavlink_get_msg_entry(msgId);
        if (!entry) {
            continue;
        }

        uint16_t crc = crc_calculate(&buf[i + 1], static_cast<uint16_t>(headerLen - 1 + payloadLen));
        crc_accumulate(entry->crc_extra, &crc);

        const int crcPos = i + headerLen + payloadLen;
        const uint16_t frameCrc = static_cast<uint16_t>(buf[crcPos])
                                | static_cast<uint16_t>(buf[crcPos + 1] << 8);
        if (crc != frameCrc) {
            continue;
        }

        ++found;
        i += frameLen - 1;
    }

    return found;
}

} // namespace

EncryptedTcpPipe::EncryptedTcpPipe(QObject *parent)
    : QObject(parent)
{
    connect(&_tcp, &TcpClient::connectionStatusChanged, this, [this](bool ok) {
        if (ok) {
            onSocketConnected();
        } else {
            onSocketDisconnected();
        }
    });
    connect(&_tcp, &TcpClient::dataReceived, this, &EncryptedTcpPipe::onRawReceived);
    connect(CryptoLinkMonitor::instance(), &CryptoLinkMonitor::resumeRequested,
            this, &EncryptedTcpPipe::onResumeRequested);

    _watchdog.setInterval(kWatchdogIntervalMs);
    connect(&_watchdog, &QTimer::timeout, this, &EncryptedTcpPipe::onWatchdogTick);
}

void EncryptedTcpPipe::startWatchdog()
{
    if (!_config.validateMavlink) {
        return;
    }
    _connectedAtMs = QDateTime::currentMSecsSinceEpoch();
    _lastValidAtMs = 0;
    _invalidStreak = 0;
    _sawValidData = false;
    _timeoutReported = false;
    _watchdog.start();
}

void EncryptedTcpPipe::stopWatchdog()
{
    _watchdog.stop();
}

void EncryptedTcpPipe::inspectPlain(const QByteArray &plain)
{
    if (!_config.validateMavlink) {
        clearFailureState();
        return;
    }

    if (countValidMavlinkFrames(plain) > 0) {
        _lastValidAtMs = QDateTime::currentMSecsSinceEpoch();
        _sawValidData = true;
        _invalidStreak = 0;
        _timeoutReported = false;
        clearFailureState();
        return;
    }

    ++_invalidStreak;
    if (_invalidStreak >= kInvalidWarnStreak) {
        // 메시지에 가변 값을 넣지 않아야 CryptoLinkMonitor 가 한 줄로 묶어 ×N 으로 센다.
        report(CryptoLinkMonitor::Warning,
               tr("복호 결과에서 유효한 MAVLink 프레임을 찾지 못했습니다 (프로토콜/키 불일치 의심)"));
    }
}

void EncryptedTcpPipe::onWatchdogTick()
{
    if (!_connected || !_config.validateMavlink || _timeoutReported) {
        return;
    }

    const qint64 now = QDateTime::currentMSecsSinceEpoch();

    if (!_sawValidData) {
        if (_config.handshakeTimeoutMs > 0 && (now - _connectedAtMs) > _config.handshakeTimeoutMs) {
            _timeoutReported = true;
            handleFailure(tr("접속 후 %1초 동안 유효한 MAVLink 데이터가 없습니다")
                              .arg(_config.handshakeTimeoutMs / 1000.0, 0, 'f', 1));
        }
        return;
    }

    if (_config.dataTimeoutMs > 0 && (now - _lastValidAtMs) > _config.dataTimeoutMs) {
        _timeoutReported = true;
        handleFailure(tr("%1초 동안 유효한 MAVLink 데이터가 없습니다")
                          .arg(_config.dataTimeoutMs / 1000.0, 0, 'f', 1));
    }
}

QString EncryptedTcpPipe::sourceLabel() const
{
    return QStringLiteral("%1:%2").arg(_config.host).arg(_config.port);
}

void EncryptedTcpPipe::report(int level, const QString &message)
{
    CryptoLinkMonitor::instance()->reportEvent(level, sourceLabel(), message);
}

void EncryptedTcpPipe::clearFailureState()
{
    if (_failureStreak != 0) {
        _failureStreak = 0;
        _tcp.setReconnectIntervalMs(_config.reconnectBackoffMs);
    }
    if (_suspended) {
        _suspended = false;
        CryptoLinkMonitor::instance()->noteSuspended(false);
    }
}

void EncryptedTcpPipe::handleFailure(const QString &message)
{
    report(CryptoLinkMonitor::Error, message);
    emit errorOccurred(message);

    if (!_config.failOnError) {
        return;
    }

    _rxBuffer.clear();
    ++_failureStreak;

    const int limit = qMax(1, _config.maxConsecutiveFailures);
    if (_failureStreak >= limit) {
        _suspended = true;
        CryptoLinkMonitor::instance()->noteSuspended(true);
        _tcp.disconnectFromServer();
        // disconnectFromServer()는 소켓 시그널을 먼저 끊으므로 onSocketDisconnected()가 오지 않는다.
        // 직접 호출하지 않으면 _connected가 true로 남아 링크가 살아있는 것처럼 보인다.
        onSocketDisconnected();

        const QString reason = tr("연속 %1회 실패로 자동 재연결을 중지했습니다. 상대 장비의 프로토콜/키 설정을 확인한 뒤 재개하세요.")
                                   .arg(_failureStreak);
        report(CryptoLinkMonitor::Error, reason);
        emit suspended(reason);
        return;
    }

    // 임계 이내: 현재 연결만 끊고 백오프 후 재시도한다(서버 모드는 리스닝 유지).
    const int backoffShift = qMin(_failureStreak - 1, 8);
    _tcp.setReconnectIntervalMs(_config.reconnectBackoffMs * (1 << backoffShift));
    report(CryptoLinkMonitor::Warning,
           tr("연결을 끊고 재시도합니다 (%1/%2)").arg(_failureStreak).arg(limit));
    _tcp.dropActiveConnection();
}

void EncryptedTcpPipe::onResumeRequested()
{
    if (!_suspended) {
        return;
    }

    const TngCryptoConfig cfg = _config;
    _suspended = false;
    _failureStreak = 0;
    CryptoLinkMonitor::instance()->noteSuspended(false);

    QString err;
    if (!start(cfg, &err)) {
        report(CryptoLinkMonitor::Error, tr("재개 실패: %1").arg(err));
        emit errorOccurred(err);
    } else {
        report(CryptoLinkMonitor::Info, tr("사용자 요청으로 연결을 재개했습니다"));
    }
}

bool EncryptedTcpPipe::start(const TngCryptoConfig &config, QString *error)
{
    stop();
    _config = config;
    _failureStreak = 0;
    _suspended = false;
    CryptoLinkMonitor::instance()->noteSuspended(false);
    _tcp.setReconnectIntervalMs(_config.reconnectBackoffMs);

    if (!_config.enabled) {
        _started = true;
        const TcpClient::Mode m = (_config.tcpMode == TngCryptoConfig::TcpMode::Server)
                                      ? TcpClient::Mode::Server
                                      : TcpClient::Mode::Client;
        _tcp.start(_config.host, _config.port, m);
        if (m == TcpClient::Mode::Client) {
            _tcp.setAutoReconnect(true);
            if (_tcp.status() == TcpClient::Connected) {
                onSocketConnected();
            }
        }
        return true;
    }

    if (!initCrypto(error)) {
        return false;
    }

    _started = true;
    const TcpClient::Mode mode = (_config.tcpMode == TngCryptoConfig::TcpMode::Server)
                                     ? TcpClient::Mode::Server
                                     : TcpClient::Mode::Client;
    _tcp.start(_config.host, _config.port, mode);

    // client 는 원격 종료 후에도 재연결 유지
    if (mode == TcpClient::Mode::Client) {
        _tcp.setAutoReconnect(true);
    }

    if (mode == TcpClient::Mode::Client && _tcp.status() == TcpClient::Connected) {
        onSocketConnected();
    }
    return true;
}

void EncryptedTcpPipe::stop()
{
    if (!_started && !_connected) {
        return;
    }

    // 1) 추가 I/O / 재연결 차단
    _connected = false;
    _started = false;
    _rxBuffer.clear();
    stopWatchdog();
    CryptoLinkMonitor::instance()->noteConnected(false);
    _tcp.setAutoReconnect(false);

    // 2) 소켓 먼저 정리 (DLL unload 전에 네트워크 콜백 끊기)
    _tcp.disconnectFromServer();

    // 3) 마지막에 암호 모듈 정리
    closeCrypto();
}

bool EncryptedTcpPipe::isConnected() const
{
    return _started && _connected && (!_config.enabled || cryptoReady());
}

void EncryptedTcpPipe::sendPlain(const QByteArray &plain)
{
    if (!isConnected() || plain.isEmpty()) {
        return;
    }

    if (!_config.enabled) {
        _tcp.sendData(plain);
        return;
    }

    // 송신측 규약과 대칭: _writeBytes(=1 send) 전체를 한 번의 고정 IV CTR 로 암호화해 그대로 전송.
    // (카운터는 이 호출 시작에서 리셋, 버퍼 내부는 연속)
    if (_config.frameType == TngCryptoConfig::FrameType::MavlinkFixedIv) {
        QString serr;
        const QByteArray cipher = encryptFixedIv(plain, &serr);
        if (cipher.isEmpty()) {
            handleFailure(serr);
            return;
        }
        _tcp.sendData(cipher);
        return;
    }

    if (_config.usesMcmL()) {
        handleFailure(QStringLiteral("MCM-L supports MavlinkFixedIv only"));
        return;
    }

    QString err;
    const QByteArray frame = _crypto.sealFrame(plain, &err);
    if (frame.isEmpty()) {
        handleFailure(err);
        return;
    }

    _tcp.sendData(frame);
}

void EncryptedTcpPipe::onSocketConnected()
{
    _rxBuffer.clear();

    if (!_config.enabled) {
        _connected = true;
        CryptoLinkMonitor::instance()->noteConnected(true);
        startWatchdog();
        emit connected();
        return;
    }

    if (!cryptoReady()) {
        handleFailure(QStringLiteral("crypto not ready on TCP connect"));
        return;
    }

    QString sessErr;
    if (!openCryptoSessions(&sessErr)) {
        handleFailure(sessErr);
        return;
    }

    _connected = true;
    CryptoLinkMonitor::instance()->noteConnected(true);
    startWatchdog();
    emit connected();
}

void EncryptedTcpPipe::onSocketDisconnected()
{
    _rxBuffer.clear();
    stopWatchdog();
    closeCryptoSessions();
    // 서버가 끊으면 재접속하지 않고 세션만 종료한다. 수동 재연결은 링크를 다시 켤 때.
    if (_connected) {
        _connected = false;
        _tcp.setAutoReconnect(false);
        CryptoLinkMonitor::instance()->noteConnected(false);
        const QString message = tr("서버 연결이 끊어져 세션을 종료했습니다");
        report(CryptoLinkMonitor::Error, message);
        QGCLogging::instance()->log(tr("FC 세션 종료\n%1").arg(message));
        emit disconnected();
    }
}

void EncryptedTcpPipe::onRawReceived(const QByteArray &chunk)
{
    if (!_connected || chunk.isEmpty()) {
        return;
    }
    _rxBuffer.append(chunk);
    processRxBuffer();
}

void EncryptedTcpPipe::processRxBuffer()
{
    if (!_config.enabled) {
        if (_rxBuffer.isEmpty()) {
            return;
        }
        const QByteArray plain = _rxBuffer;
        _rxBuffer.clear();
        inspectPlain(plain);
        emit plainReceived(plain);
        return;
    }

    if (_config.frameType == TngCryptoConfig::FrameType::MavlinkFixedIv) {
        // 송신측 규약: send() 시작에서만 CTR 카운터를 고정 IV로 리셋하고, send 내부는 연속 암호화.
        // TCP recv 청크 = 송신측 send 로 보고, 청크 전체를 한 번의 고정 IV CTR 로 복호한다.
        // (QGC MAVLink 파서가 바이트 경계와 무관하게 재프레이밍하므로 메시지 분할 불필요)
        if (_rxBuffer.isEmpty()) {
            return;
        }
        QString derr;
        const QByteArray plain = decryptFixedIv(_rxBuffer, &derr);
        _rxBuffer.clear();
        if (plain.isEmpty()) {
            handleFailure(derr);
            return;
        }
        inspectPlain(plain);
        emit plainReceived(plain);
        return;
    }

    if (_config.frameType == TngCryptoConfig::FrameType::RawStream) {
        if (_rxBuffer.isEmpty()) {
            return;
        }
        QString err;
        const QByteArray plain = _crypto.unsealPayload(_rxBuffer, &err);
        _rxBuffer.clear();
        if (plain.isEmpty()) {
            handleFailure(err);
            return;
        }
        inspectPlain(plain);
        emit plainReceived(plain);
        return;
    }

    if (_config.frameType == TngCryptoConfig::FrameType::IvCipher) {
        if (_rxBuffer.size() <= TngCryptoEngine::kIvLen) {
            return;
        }
        QString err;
        const QByteArray plain = _crypto.unsealPayload(_rxBuffer, &err);
        _rxBuffer.clear();
        if (plain.isEmpty()) {
            handleFailure(err);
            return;
        }
        inspectPlain(plain);
        emit plainReceived(plain);
        return;
    }

    while (_rxBuffer.size() >= 4) {
        const quint32 payloadLen = (_config.lengthEndian == TngCryptoConfig::LengthEndian::Little)
                                       ? qFromLittleEndian<quint32>(reinterpret_cast<const uchar *>(_rxBuffer.constData()))
                                       : qFromBigEndian<quint32>(reinterpret_cast<const uchar *>(_rxBuffer.constData()));

        if (payloadLen < static_cast<quint32>(TngCryptoEngine::kIvLen + 1)) {
            handleFailure(QStringLiteral("invalid payload_len=%1").arg(payloadLen));
            return;
        }

        if (static_cast<int>(payloadLen) > _config.maxPayloadBytes) {
            handleFailure(QStringLiteral("payload_len too large: %1 (max=%2)")
                              .arg(payloadLen)
                              .arg(_config.maxPayloadBytes));
            return;
        }

        const int frameSize = 4 + static_cast<int>(payloadLen);
        if (_rxBuffer.size() < frameSize) {
            return;
        }

        const QByteArray payload = _rxBuffer.mid(4, static_cast<int>(payloadLen));
        _rxBuffer.remove(0, frameSize);

        QString err;
        const QByteArray plain = _crypto.unsealPayload(payload, &err);
        if (plain.isEmpty()) {
            handleFailure(err);
            // failOnError=false 로 흘려보내는 경우에만 남은 프레임을 계속 처리한다.
            if (_config.failOnError) {
                return;
            }
            continue;
        }
        inspectPlain(plain);
        emit plainReceived(plain);
    }
}

bool EncryptedTcpPipe::initCrypto(QString *error)
{
    if (_config.usesMcmL()) {
        return _mcm.init(_config, error);
    }
    return _crypto.init(_config, error);
}

void EncryptedTcpPipe::closeCrypto()
{
    _mcm.close();
    _crypto.close();
}

bool EncryptedTcpPipe::cryptoReady() const
{
    return _config.usesMcmL() ? _mcm.isReady() : _crypto.isReady();
}

bool EncryptedTcpPipe::openCryptoSessions(QString *error)
{
    if (_config.usesMcmL()) {
        if (!_mcm.isReady()) {
            if (error) {
                *error = QStringLiteral("MCM-L not ready");
            }
            return false;
        }
        return true;
    }
    return _crypto.openSessions(error);
}

void EncryptedTcpPipe::closeCryptoSessions()
{
    if (!_config.usesMcmL()) {
        _crypto.closeSessions();
    }
}

QByteArray EncryptedTcpPipe::encryptFixedIv(const QByteArray &plain, QString *error)
{
    if (_config.usesMcmL()) {
        return _mcm.encryptFixedIvMessage(plain, error);
    }
    return _crypto.encryptFixedIvMessage(plain, error);
}

QByteArray EncryptedTcpPipe::decryptFixedIv(const QByteArray &cipher, QString *error)
{
    if (_config.usesMcmL()) {
        return _mcm.decryptFixedIvMessage(cipher, error);
    }
    return _crypto.decryptFixedIvMessage(cipher, error);
}
