#include "TngVideoCryptoService.h"

#include "QGCLogging.h"
#include "QGCLoggingCategory.h"
#include "TngCryptoConfig.h"
#include "VideoEndpointSettings.h"

#include <QtCore/QMutexLocker>
#include <QtCore/QSettings>
#include <QtCore/QtGlobal>

QGC_LOGGING_CATEGORY(TngVideoCryptoServiceLog, "qgc.videocrypto.service")

namespace {
// RTP/UDP MTU 를 한 번에 덮고, EncryptedRtspClient 암호 프레임 상한과 맞춘다.
constexpr qsizetype kMinKeystreamBytes = 2048;
constexpr qsizetype kMaxKeystreamBytes = 256 * 1024;
}

void TngVideoCryptoService::_reportToConsole(const QString &line)
{
    qCWarning(TngVideoCryptoServiceLog) << line;
    if (QGCLogging *logging = QGCLogging::instance()) {
        logging->log(line);
    }
}

TngVideoCryptoService &TngVideoCryptoService::instance()
{
    static TngVideoCryptoService service;
    return service;
}

TngVideoCryptoService::Framing TngVideoCryptoService::framing()
{
    // 프레이밍은 세션마다 새로 읽는다. 재생을 다시 시작하면 ini 수정이 바로 반영된다.
    QSettings settings(VideoEndpointSettings::resolveIniPath(), QSettings::IniFormat);
    const QString value = settings.value(QStringLiteral("crypto/framing"),
                                         QStringLiteral("payload")).toString().trimmed().toLower();
    return (value == QLatin1String("rtsp")) ? Framing::RtspFrame : Framing::RtpPayload;
}

QByteArray TngVideoCryptoService::_fingerprint(const TngCryptoConfig &config)
{
    QByteArray fp;
    fp += QByteArray::number(config.alg);
    fp += '|';
    fp += QByteArray::number(config.mode);
    fp += '|';
    fp += QByteArray::number(static_cast<int>(config.keySource));
    fp += '|';
    fp += QByteArray::number(config.keyIndex);
    fp += '|';
    fp += config.key.toHex();
    fp += '|';
    fp += config.iv.toHex();
    fp += '|';
    fp += config.sysUnique.toUtf8();
    fp += '|';
    fp += config.packageId.toUtf8();
    fp += '|';
    fp += config.keystorePath.toUtf8();
    return fp;
}

bool TngVideoCryptoService::acquire(SpeedMode mode, QString *error)
{
    QMutexLocker locker(&_mutex);

    VideoEndpointSettings::ensureCryptoSection(VideoEndpointSettings::resolveIniPath());

    TngCryptoConfig config;
    if (!TngCryptoConfig::load(VideoEndpointSettings::resolveIniPath(), config, error)) {
        return false;
    }

    if (!config.enabled) {
        if (error) {
            *error = QStringLiteral("video crypto disabled in video_endpoints.ini [crypto]");
        }
        return false;
    }

    QString identityError;
    if (!TngCryptoConfig::applyGlobalIdentity(config, &identityError)) {
        qCWarning(TngVideoCryptoServiceLog)
            << "crypto.ini load failed, keeping video-local identity:" << identityError;
    }

    config.frameType = TngCryptoConfig::FrameType::MavlinkFixedIv;
    config.ivMode = TngCryptoConfig::IvMode::Fixed;

    const QByteArray fp = _fingerprint(config);
    const bool needInit = (_users == 0) || (_configFingerprint != fp);
    if (needInit) {
        _clearKeystream();
        if (_users > 0) {
            _engine.close();
        }
        if (!_engine.init(config, error)) {
            _configFingerprint.clear();
            _xorCacheEnabled = false;
            return false;
        }
        // 모드 2 = CTR. 패딩이 있으면 0 암호화 길이가 키스트림 길이와 달라 XOR 캐시가 틀리다.
        _xorCacheEnabled = (config.mode == 2 && config.padding == 0);
        _configFingerprint = fp;
        if (!_xorCacheEnabled) {
            _reportToConsole(QStringLiteral("영상 복호: CTR 키스트림 캐시 미적용(mode=%1, padding=%2). "
                                            "패킷마다 세션을 열고 닫아 지연이 커질 수 있습니다.")
                                 .arg(config.mode)
                                 .arg(config.padding));
        }
    }

    if (mode == SpeedMode::High && !_engine.highSpeedAvailable()) {
        if (error) {
            *error = QStringLiteral("tngcore.dll does not export tngEncHs/tngDecHs");
        }
        if (_users == 0) {
            _engine.close();
            _configFingerprint.clear();
            _clearKeystream();
            _xorCacheEnabled = false;
        }
        return false;
    }

    // 재생 시작 때 한 번만 Open 한다. 이후 패킷에서 다시 열지 않기 위해 여기서 키스트림을 만든다.
    if (needInit && _xorCacheEnabled) {
        (void) _ensureKeystream(kMinKeystreamBytes, mode, nullptr);
    }

    ++_users;
    return true;
}

void TngVideoCryptoService::release()
{
    QMutexLocker locker(&_mutex);
    if (_users <= 0) {
        return;
    }

    if (--_users == 0) {
        _engine.close();
        _configFingerprint.clear();
        _clearKeystream();
        _xorCacheEnabled = false;
    }
}

QByteArray TngVideoCryptoService::encryptChunk(const QByteArray &plain, SpeedMode mode, QString *error)
{
    QMutexLocker locker(&_mutex);
    if (_users <= 0) {
        if (error) {
            *error = QStringLiteral("video crypto service is not acquired");
        }
        return {};
    }

    return _xorOrEngine(plain, mode, true, error);
}

QByteArray TngVideoCryptoService::decryptChunk(const QByteArray &cipher, SpeedMode mode, QString *error)
{
    QMutexLocker locker(&_mutex);
    if (_users <= 0) {
        if (error) {
            *error = QStringLiteral("video crypto service is not acquired");
        }
        return {};
    }

    return _xorOrEngine(cipher, mode, false, error);
}

QByteArray TngVideoCryptoService::_xorOrEngine(const QByteArray &data, SpeedMode mode, bool encrypt,
                                              QString *error)
{
    // Fixed IV CTR 은 패킷마다 같은 키스트림이다. 세션을 이어 치지 않고 XOR 만 한다.
    // 캐시 실패 시에만 엔진(패킷마다 Open/Close)으로 폴백한다. 성공한 캐시를 패킷마다 다시 열지 않는다.
    if (!data.isEmpty() && _xorCacheEnabled && !_keystreamUnusable
        && _ensureKeystream(data.size(), mode, nullptr)) {
        const QByteArray out = _xorKeystream(data);
        // 길이 보장이 깨진 경우에만 비게 된다. 그때는 세션 경로로 살려 본다.
        if (out.size() == data.size()) {
            return out;
        }
    }

    if (encrypt) {
        return mode == SpeedMode::High
                   ? _engine.encryptFixedIvHighSpeedMessage(data, error)
                   : _engine.encryptFixedIvMessage(data, error);
    }
    return mode == SpeedMode::High
               ? _engine.decryptFixedIvHighSpeedMessage(data, error)
               : _engine.decryptFixedIvMessage(data, error);
}

void TngVideoCryptoService::_clearKeystream()
{
    _keystream.clear();
    _keystreamUnusable = false;
    _oversizeReported = false;
}

bool TngVideoCryptoService::_ensureKeystream(qsizetype bytes, SpeedMode mode, QString *error)
{
    if (bytes <= 0) {
        return false;
    }
    if (_keystream.size() >= bytes) {
        return true;
    }
    if (bytes > kMaxKeystreamBytes) {
        if (!_oversizeReported) {
            _oversizeReported = true;
            _reportToConsole(QStringLiteral("영상 복호: 청크 %1바이트가 키스트림 상한 %2바이트를 넘어 "
                                            "세션 경로로 처리합니다.")
                                 .arg(bytes)
                                 .arg(kMaxKeystreamBytes));
        }
        return false;
    }

    const qsizetype want = qMin(kMaxKeystreamBytes, qMax(bytes, kMinKeystreamBytes));
    const QByteArray zeros(want, '\0');
    QString genError;
    QByteArray ks = (mode == SpeedMode::High)
                        ? _engine.encryptFixedIvHighSpeedMessage(zeros, &genError)
                        : _engine.encryptFixedIvMessage(zeros, &genError);
    // 키스트림은 CTR 블록 열이라 high/normal 이 같아야 한다. high 생성만 실패하면 normal 로 한 번 더 시도한다.
    if (ks.size() != want && mode == SpeedMode::High) {
        ks = _engine.encryptFixedIvMessage(zeros, &genError);
    }
    if (ks.size() != want) {
        _keystreamUnusable = true;
        _keystream.clear();
        _reportToConsole(QStringLiteral("영상 복호: 키스트림 생성 실패(요청 %1바이트, 결과 %2바이트)%3\n"
                                        "패킷마다 세션을 여는 경로로 되돌립니다.")
                             .arg(want)
                             .arg(ks.size())
                             .arg(genError.isEmpty() ? QString()
                                                     : QStringLiteral(" - %1").arg(genError)));
        if (error && !genError.isEmpty()) {
            *error = genError;
        }
        return false;
    }

    _keystream = ks;
    qCDebug(TngVideoCryptoServiceLog) << "cached CTR keystream" << _keystream.size() << "bytes";
    return true;
}

QByteArray TngVideoCryptoService::_xorKeystream(const QByteArray &data) const
{
    const qsizetype n = data.size();
    // 호출 전에 _ensureKeystream 이 길이를 보장하지만, 넘치면 캐시 밖을 읽어 크래시가 된다.
    if (_keystream.size() < n) {
        _reportToConsole(QStringLiteral("영상 복호: 키스트림 %1바이트가 청크 %2바이트보다 짧아 "
                                        "이 패킷을 버립니다.")
                             .arg(_keystream.size())
                             .arg(n));
        return {};
    }

    QByteArray out(n, Qt::Uninitialized);
    const auto *in = reinterpret_cast<const uchar *>(data.constData());
    const auto *ks = reinterpret_cast<const uchar *>(_keystream.constData());
    auto *dst = reinterpret_cast<uchar *>(out.data());
    for (qsizetype i = 0; i < n; ++i) {
        dst[i] = static_cast<uchar>(in[i] ^ ks[i]);
    }
    return out;
}
