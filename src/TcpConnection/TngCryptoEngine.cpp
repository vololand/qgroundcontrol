#include "TngCryptoEngine.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QtEndian>

#include <cstring>

TngCryptoEngine::~TngCryptoEngine()
{
    close();
}

bool TngCryptoEngine::loadSessionKey(QString *error)
{
    const int expectLen = TngCryptoConfig::expectedKeyBytes(_config.alg);
    if (expectLen <= 0) {
        if (error) {
            *error = QStringLiteral("invalid alg for key length: %1").arg(_config.alg);
        }
        return false;
    }

    if (_config.keySource == TngCryptoConfig::KeySource::Hex) {
        if (_config.key.size() != expectLen) {
            if (error) {
                *error = QStringLiteral("key_hex length mismatch: got %1 need %2")
                             .arg(_config.key.size())
                             .arg(expectLen);
            }
            return false;
        }
        return true;
    }

    const auto readLatestKey = TngCoreRuntime::instance().readLatestKey();
    const auto readKey = TngCoreRuntime::instance().readKey();

    if (_config.keySource == TngCryptoConfig::KeySource::KeystoreLatest) {
        if (!readLatestKey) {
            if (error) {
                *error = QStringLiteral("tngReadLatestKey not available in dll");
            }
            return false;
        }
        QByteArray buf(64, 0);
        int keyLen = buf.size();
        int latestIndex = 0;
        const int rc = readLatestKey(reinterpret_cast<unsigned char *>(buf.data()), &keyLen, &latestIndex);
        if (rc != 0 || keyLen <= 0) {
            if (error) {
                *error = QStringLiteral("tngReadLatestKey failed: rc=%1 keyLen=%2").arg(rc).arg(keyLen);
            }
            return false;
        }
        _config.key = buf.left(keyLen);
    } else if (_config.keySource == TngCryptoConfig::KeySource::KeystoreIndex) {
        if (!readKey) {
            if (error) {
                *error = QStringLiteral("tngReadKey not available in dll");
            }
            return false;
        }
        QByteArray buf(64, 0);
        int keyLen = buf.size();
        const int rc = readKey(_config.keyIndex, reinterpret_cast<unsigned char *>(buf.data()), &keyLen);
        if (rc != 0 || keyLen <= 0) {
            if (error) {
                *error = QStringLiteral("tngReadKey(%1) failed: rc=%2 keyLen=%3")
                             .arg(_config.keyIndex)
                             .arg(rc)
                             .arg(keyLen);
            }
            return false;
        }
        _config.key = buf.left(keyLen);
    }

    if (_config.key.size() != expectLen) {
        if (error) {
            *error = QStringLiteral("keystore key length mismatch: got %1 need %2 (alg=%3)")
                         .arg(_config.key.size())
                         .arg(expectLen)
                         .arg(_config.alg);
        }
        return false;
    }
    return true;
}

bool TngCryptoEngine::init(const TngCryptoConfig &config, QString *error)
{
    close();
    _config = config;

    if (!TngCoreRuntime::instance().acquire(_config, error)) {
        return false;
    }
    _acquired = true;

    if (!loadSessionKey(error)) {
        close();
        return false;
    }

    return true;
}

bool TngCryptoEngine::generateAndSaveKey(const TngCryptoConfig &config, int *outIndex, QString *error)
{
    const int keyLen = TngCryptoConfig::expectedKeyBytes(config.alg);
    if (keyLen <= 0) {
        if (error) {
            *error = QStringLiteral("invalid alg for key length: %1").arg(config.alg);
        }
        return false;
    }

    if (!openCoreForKeystore(config, error)) {
        return false;
    }

    const auto genRnd = TngCoreRuntime::instance().genRnd();
    const auto saveKey = TngCoreRuntime::instance().saveKey();
    const auto setDeviceInfo = TngCoreRuntime::instance().setDeviceInfo();

    if (!genRnd || !saveKey) {
        if (error) {
            *error = QStringLiteral("tngGenerateRandomNumber/tngSaveKey not available in dll");
        }
        close();
        return false;
    }

    const QString nativeKsPath = QDir::toNativeSeparators(_config.keystorePath);

    int devRc = 0;
    if (setDeviceInfo) {
        QByteArray mid  = _config.sysUnique.toUtf8();
        QByteArray name = _config.packageId.toUtf8();
        QByteArray hw   = QByteArrayLiteral("QGC");
        QByteArray fw   = QByteArrayLiteral("QGC");
        QByteArray sn   = QByteArrayLiteral("QGC");
        devRc = setDeviceInfo(reinterpret_cast<unsigned char *>(mid.data()),
                              reinterpret_cast<unsigned char *>(hw.data()),
                              reinterpret_cast<unsigned char *>(fw.data()),
                              reinterpret_cast<unsigned char *>(sn.data()),
                              reinterpret_cast<unsigned char *>(name.data()));
    }

    QByteArray key(keyLen, Qt::Uninitialized);
    const int genRc = genRnd(reinterpret_cast<unsigned char *>(key.data()), keyLen, 0);
    if (genRc != 0) {
        if (error) {
            *error = QStringLiteral("tngGenerateRandomNumber failed: %1").arg(genRc);
        }
        close();
        return false;
    }

    char exp[10];
    std::memset(exp, 0, sizeof(exp));
    std::memcpy(exp, "EXP11111", 8);

    int index = 0;
    const int saveRc = saveKey(key.data(), keyLen, exp, static_cast<int>(sizeof(exp)), &index);
    key.fill(0);

    if (saveRc != 0) {
        if (error) {
            *error = QStringLiteral("tngSaveKey failed: %1 (devInfoRc=%2, keyLen=%3, path=%4)")
                         .arg(saveRc).arg(devRc).arg(keyLen).arg(nativeKsPath);
        }
        close();
        return false;
    }

    if (outIndex) {
        *outIndex = index;
    }

    close();
    return true;
}

bool TngCryptoEngine::queryKeystore(const TngCryptoConfig &config, QList<KeyEntry> *outKeys, int *outLatestIndex, QString *error)
{
    if (outKeys) {
        outKeys->clear();
    }
    if (outLatestIndex) {
        *outLatestIndex = -1;
    }

    if (!openCoreForKeystore(config, error)) {
        return false;
    }

    const auto getSavedKeyList = TngCoreRuntime::instance().getSavedKeyList();
    if (!getSavedKeyList) {
        if (error) {
            *error = QStringLiteral("tngGetSavedKeyList not available in dll");
        }
        close();
        return false;
    }

    struct TngKeyList {
        int index;
        char curyyyymmdd[10];
    };
    TngKeyList list[50];
    std::memset(list, 0, sizeof(list));
    int listSize = 0;
    getSavedKeyList(list, &listSize);
    if (listSize < 0) {
        listSize = 0;
    }
    if (listSize > 50) {
        listSize = 50;
    }

    if (outKeys) {
        for (int i = 0; i < listSize; ++i) {
            KeyEntry e;
            e.index = list[i].index;
            QByteArray d(list[i].curyyyymmdd, 10);
            const int z = d.indexOf('\0');
            if (z >= 0) {
                d.truncate(z);
            }
            e.date = QString::fromLatin1(d);
            outKeys->append(e);
        }
    }

    const auto readLatestKey = TngCoreRuntime::instance().readLatestKey();
    if (outLatestIndex && readLatestKey) {
        QByteArray buf(64, Qt::Uninitialized);
        int keyLen = 0;
        int latestIdx = -1;
        const int rc = readLatestKey(reinterpret_cast<unsigned char *>(buf.data()), &keyLen, &latestIdx);
        buf.fill(0);
        if (rc == 0 && latestIdx >= 1) {
            *outLatestIndex = latestIdx;
        }
    }

    close();
    return true;
}

bool TngCryptoEngine::openCoreForKeystore(const TngCryptoConfig &config, QString *error)
{
    close();
    _config = config;

    if (!TngCoreRuntime::instance().acquire(_config, error)) {
        return false;
    }
    _acquired = true;
    return true;
}

bool TngCryptoEngine::destroyKey(const TngCryptoConfig &config, int index, QString *error)
{
    if (!openCoreForKeystore(config, error)) {
        return false;
    }
    const auto destroy = TngCoreRuntime::instance().destroyKey();
    if (!destroy) {
        if (error) {
            *error = QStringLiteral("tngDestroyKey not available in dll");
        }
        close();
        return false;
    }

    const int rc = destroy(index);
    close();
    if (rc != 0) {
        if (error) {
            *error = QStringLiteral("tngDestroyKey failed: rc=%1 (index=%2)").arg(rc).arg(index);
        }
        return false;
    }
    return true;
}

bool TngCryptoEngine::destroyAllKeys(const TngCryptoConfig &config, QString *error)
{
    if (!openCoreForKeystore(config, error)) {
        return false;
    }
    const auto destroyAll = TngCoreRuntime::instance().destroyAllKey();
    if (!destroyAll) {
        if (error) {
            *error = QStringLiteral("tngDestroyAllKey not available in dll");
        }
        close();
        return false;
    }

    destroyAll();
    close();
    return true;
}

void TngCryptoEngine::closeSessions()
{
    const auto closeSession = TngCoreRuntime::instance().closeSession();
    if (_encSessionOpen && closeSession) {
        closeSession(_encSessionIndex);
    }
    if (_decSessionOpen && closeSession) {
        closeSession(_decSessionIndex);
    }
    _encSessionOpen = false;
    _decSessionOpen = false;
    _encSessionIndex = 0;
    _decSessionIndex = 0;
    _sessionIv.clear();
}

void TngCryptoEngine::close()
{
    // 세션은 코어 반납보다 먼저 닫아야 tngCloseSession 심볼이 아직 유효하다.
    closeSessions();

    if (_acquired) {
        TngCoreRuntime::instance().release();
        _acquired = false;
    }
}

bool TngCryptoEngine::openOneSession(unsigned int *sessionIndex, const QByteArray &iv, QString *error)
{
    const int expectedKeyLen = TngCryptoConfig::expectedKeyBytes(_config.alg);
    if (!_acquired || !sessionIndex || iv.size() != kIvLen
        || expectedKeyLen <= 0 || _config.key.size() != expectedKeyLen) {
        if (error) {
            *error = QStringLiteral("openOneSession invalid state/args (keyLen=%1 expected=%2 alg=%3)")
                         .arg(_config.key.size())
                         .arg(expectedKeyLen)
                         .arg(_config.alg);
        }
        return false;
    }

    QByteArray key = _config.key;
    QByteArray ivBuf = iv;
    *sessionIndex = 0;
    const int openRc = TngCoreRuntime::instance().openSession()(
        sessionIndex,
        reinterpret_cast<unsigned char *>(key.data()),
        static_cast<unsigned int>(key.size()),
        _config.alg,
        _config.mode,
        reinterpret_cast<unsigned char *>(ivBuf.data()),
        static_cast<unsigned int>(ivBuf.size()),
        static_cast<unsigned int>(_config.padding));
    if (openRc != 0) {
        if (error) {
            *error = QStringLiteral("tngOpenSession failed: %1").arg(openRc);
        }
        return false;
    }
    return true;
}

bool TngCryptoEngine::openSessions(QString *error)
{
    if (!_acquired) {
        if (error) {
            *error = QStringLiteral("openSessions: core not inited");
        }
        return false;
    }

    if (_config.frameType == TngCryptoConfig::FrameType::MavlinkFixedIv) {
        closeSessions();
        return true;
    }

    if (_config.ivMode == TngCryptoConfig::IvMode::PerMessage) {
        closeSessions();
        return true;
    }

    closeSessions();

    QByteArray iv = _config.iv;
    if (iv.size() != kIvLen) {
        if (error) {
            *error = QStringLiteral("openSessions: fixed IV missing/invalid");
        }
        return false;
    }

    if (!openOneSession(&_encSessionIndex, iv, error)) {
        return false;
    }
    _encSessionOpen = true;

    if (!openOneSession(&_decSessionIndex, iv, error)) {
        closeSessions();
        return false;
    }
    _decSessionOpen = true;
    _sessionIv = iv;

    return true;
}

QByteArray TngCryptoEngine::generateIv(QString *error)
{
    const auto genRnd = TngCoreRuntime::instance().genRnd();
    if (!genRnd) {
        if (error) {
            *error = QStringLiteral("tngGenerateRandomNumber not available in dll");
        }
        return {};
    }

    QByteArray iv(kIvLen, Qt::Uninitialized);
    const int rc = genRnd(reinterpret_cast<unsigned char *>(iv.data()), kIvLen, 0);
    if (rc != 0) {
        if (error) {
            *error = QStringLiteral("tngGenerateRandomNumber(IV) failed: %1").arg(rc);
        }
        return {};
    }
    return iv;
}

QByteArray TngCryptoEngine::cryptOnSession(bool encrypt, unsigned int sessionIndex, const QByteArray &input, QString *error, bool highSpeed)
{
    if (!_acquired || input.isEmpty()) {
        if (error) {
            *error = QStringLiteral("cryptOnSession invalid state/args");
        }
        return {};
    }

    QByteArray out(input.size() + 16, Qt::Uninitialized);
    unsigned char *outPtr = reinterpret_cast<unsigned char *>(out.data());
    unsigned int outLen = 0;

    const TngCoreRuntime &rt = TngCoreRuntime::instance();
    auto fn = highSpeed ? (encrypt ? rt.encHs() : rt.decHs()) : (encrypt ? rt.encSymm() : rt.decSymm());
    if (!fn) {
        if (error) {
            *error = QStringLiteral("tngCore %1-speed %2 symbol unavailable")
                         .arg(highSpeed ? QStringLiteral("high") : QStringLiteral("normal"),
                              encrypt ? QStringLiteral("encrypt") : QStringLiteral("decrypt"));
        }
        return {};
    }
    const int rc = fn(sessionIndex,
                      reinterpret_cast<const unsigned char *>(input.constData()),
                      static_cast<unsigned int>(input.size()),
                      &outPtr,
                      &outLen);

    if (rc != 0) {
        if (error) {
            *error = QStringLiteral("tng %1-speed %2 failed: %3")
                         .arg(highSpeed ? QStringLiteral("high") : QStringLiteral("normal"),
                              encrypt ? QStringLiteral("encrypt") : QStringLiteral("decrypt"))
                         .arg(rc);
        }
        return {};
    }

    if (outPtr != reinterpret_cast<unsigned char *>(out.data())) {
        return QByteArray(reinterpret_cast<const char *>(outPtr), static_cast<int>(outLen));
    }
    out.resize(static_cast<int>(outLen));
    return out;
}

QByteArray TngCryptoEngine::cryptWithIv(bool encrypt, const QByteArray &iv, const QByteArray &input, QString *error, bool highSpeed)
{
    if (!_acquired || iv.size() != kIvLen || input.isEmpty()) {
        if (error) {
            *error = QStringLiteral("cryptWithIv invalid state/args");
        }
        return {};
    }

    unsigned int sessionIndex = 0;
    if (!openOneSession(&sessionIndex, iv, error)) {
        return {};
    }

    const QByteArray out = cryptOnSession(encrypt, sessionIndex, input, error, highSpeed);
    TngCoreRuntime::instance().closeSession()(sessionIndex);
    return out;
}

QByteArray TngCryptoEngine::buildWireFrame(const QByteArray &iv, const QByteArray &cipher, QString *error)
{
    if (_config.frameType == TngCryptoConfig::FrameType::RawStream) {
        return cipher;
    }

    QByteArray payload;
    payload.reserve(kIvLen + cipher.size());
    payload.append(iv);
    payload.append(cipher);

    if (_config.frameType == TngCryptoConfig::FrameType::IvCipher) {
        return payload;
    }

    const quint32 payloadLen = static_cast<quint32>(payload.size());
    if (static_cast<int>(payloadLen) > _config.maxPayloadBytes) {
        if (error) {
            *error = QStringLiteral("payload exceeds max_payload_bytes");
        }
        return {};
    }

    QByteArray frame;
    frame.reserve(4 + static_cast<int>(payloadLen));
    const quint32 encodedLen = (_config.lengthEndian == TngCryptoConfig::LengthEndian::Little)
                                   ? qToLittleEndian(payloadLen)
                                   : qToBigEndian(payloadLen);
    frame.append(reinterpret_cast<const char *>(&encodedLen), 4);
    frame.append(payload);
    return frame;
}

QByteArray TngCryptoEngine::sealFrame(const QByteArray &plain, QString *error)
{
    if (!_acquired || plain.isEmpty()) {
        return {};
    }

    if (_config.frameType == TngCryptoConfig::FrameType::MavlinkFixedIv) {
        return encryptFixedIvMessage(plain, error);
    }

    if (_config.ivMode == TngCryptoConfig::IvMode::PerMessage) {
        const QByteArray iv = generateIv(error);
        if (iv.size() != kIvLen) {
            return {};
        }
        const QByteArray cipher = cryptWithIv(true, iv, plain, error);
        if (cipher.isEmpty()) {
            return {};
        }
        return buildWireFrame(iv, cipher, error);
    }

    if (!_encSessionOpen || _sessionIv.size() != kIvLen) {
        if (error) {
            *error = QStringLiteral("sealFrame: enc session not open");
        }
        return {};
    }

    const QByteArray cipher = cryptOnSession(true, _encSessionIndex, plain, error);
    if (cipher.isEmpty()) {
        return {};
    }
    return buildWireFrame(_sessionIv, cipher, error);
}

QByteArray TngCryptoEngine::unsealPayload(const QByteArray &payload, QString *error)
{
    if (_config.frameType == TngCryptoConfig::FrameType::RawStream) {
        if (_config.ivMode == TngCryptoConfig::IvMode::PerMessage) {
            if (error) {
                *error = QStringLiteral("raw_stream + per_message unsupported");
            }
            return {};
        }
        if (!_decSessionOpen) {
            if (error) {
                *error = QStringLiteral("unseal: dec session not open");
            }
            return {};
        }
        return cryptOnSession(false, _decSessionIndex, payload, error);
    }

    if (payload.size() <= kIvLen) {
        if (error) {
            *error = QStringLiteral("payload too short for IV+cipher: %1").arg(payload.size());
        }
        return {};
    }

    const QByteArray iv = payload.left(kIvLen);
    const QByteArray cipher = payload.mid(kIvLen);

    if (_config.ivMode == TngCryptoConfig::IvMode::PerMessage) {
        return cryptWithIv(false, iv, cipher, error);
    }

    if (!_decSessionOpen) {
        if (error) {
            *error = QStringLiteral("unseal: dec session not open");
        }
        return {};
    }
    return cryptOnSession(false, _decSessionIndex, cipher, error);
}

QByteArray TngCryptoEngine::encryptFixedIvMessage(const QByteArray &plain, QString *error)
{
    if (_config.iv.size() != kIvLen) {
        if (error) {
            *error = QStringLiteral("encryptFixedIvMessage: fixed IV invalid (%1)").arg(_config.iv.size());
        }
        return {};
    }
    return cryptWithIv(true, _config.iv, plain, error);
}

QByteArray TngCryptoEngine::decryptFixedIvMessage(const QByteArray &cipher, QString *error)
{
    if (_config.iv.size() != kIvLen) {
        if (error) {
            *error = QStringLiteral("decryptFixedIvMessage: fixed IV invalid (%1)").arg(_config.iv.size());
        }
        return {};
    }
    return cryptWithIv(false, _config.iv, cipher, error);
}

QByteArray TngCryptoEngine::encryptFixedIvHighSpeedMessage(const QByteArray &plain, QString *error)
{
    if (_config.mode != 2) {
        if (error) {
            *error = QStringLiteral("high-speed encryption requires CTR mode");
        }
        return {};
    }
    if (_config.iv.size() != kIvLen) {
        if (error) {
            *error = QStringLiteral("encryptFixedIvHighSpeedMessage: fixed IV invalid (%1)").arg(_config.iv.size());
        }
        return {};
    }
    return cryptWithIv(true, _config.iv, plain, error, true);
}

QByteArray TngCryptoEngine::decryptFixedIvHighSpeedMessage(const QByteArray &cipher, QString *error)
{
    if (_config.mode != 2) {
        if (error) {
            *error = QStringLiteral("high-speed decryption requires CTR mode");
        }
        return {};
    }
    if (_config.iv.size() != kIvLen) {
        if (error) {
            *error = QStringLiteral("decryptFixedIvHighSpeedMessage: fixed IV invalid (%1)").arg(_config.iv.size());
        }
        return {};
    }
    return cryptWithIv(false, _config.iv, cipher, error, true);
}
