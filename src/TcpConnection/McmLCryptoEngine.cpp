#include "McmLCryptoEngine.h"

namespace {
constexpr unsigned char kMcAlgLea = 3;
constexpr unsigned char kMcModeCtr = 3;
constexpr unsigned int kEncryptSuccess = 0x00201010;
constexpr unsigned int kDecryptSuccess = 0x00201020;
} // namespace

McmLCryptoEngine::~McmLCryptoEngine()
{
    close();
}

bool McmLCryptoEngine::resolveSymbols(QString *error)
{
    _encrypt = reinterpret_cast<EncryptFn>(_lib.resolve("MC_Encrypt_BC"));
    _decrypt = reinterpret_cast<DecryptFn>(_lib.resolve("MC_Decrypt_BC"));
    if (!_encrypt || !_decrypt) {
        if (error) {
            *error = QStringLiteral("mcm-l dll symbol resolve failed: %1").arg(_lib.errorString());
        }
        return false;
    }
    return true;
}

bool McmLCryptoEngine::init(const TngCryptoConfig &config, QString *error)
{
    close();
    _config = config;

    if (_config.mode != 2 || _config.padding != 0) {
        if (error) {
            *error = QStringLiteral("MCM-L requires CTR and padding=false");
        }
        return false;
    }

    const int expectLen = TngCryptoConfig::expectedKeyBytes(_config.alg);
    if (expectLen <= 0 || _config.key.size() != expectLen || _config.iv.size() != kIvLen) {
        if (error) {
            *error = QStringLiteral("MCM-L key/iv invalid (key=%1 expected=%2 iv=%3)")
                         .arg(_config.key.size())
                         .arg(expectLen)
                         .arg(_config.iv.size());
        }
        return false;
    }

    const QString dllPath = _config.resolvedMcmDllPath();
    _lib.setFileName(dllPath);
    if (!_lib.load()) {
        if (error) {
            *error = QStringLiteral("failed to load mcm-l dll '%1': %2")
                         .arg(dllPath, _lib.errorString());
        }
        return false;
    }

    if (!resolveSymbols(error)) {
        _lib.unload();
        return false;
    }

    _ready = true;
    return true;
}

void McmLCryptoEngine::close()
{
    _ready = false;
    _encrypt = nullptr;
    _decrypt = nullptr;
    if (_lib.isLoaded()) {
        _lib.unload();
    }
}

QByteArray McmLCryptoEngine::crypt(bool encrypt, const QByteArray &input, QString *error)
{
    if (!_ready || !_encrypt || !_decrypt || input.isEmpty()) {
        if (error) {
            *error = QStringLiteral("MCM-L crypt invalid state/args");
        }
        return {};
    }

    // DLL writes whole 16-byte blocks: a non-aligned length touches up to 15 bytes
    // past the logical CTR output. Keep one block of slack, then trim.
    QByteArray out(input.size() + 16, Qt::Uninitialized);
    QByteArray inBuf = input;
    QByteArray iv = _config.iv;
    QByteArray key = _config.key;

    const unsigned int rc = encrypt
        ? _encrypt(reinterpret_cast<unsigned char *>(out.data()),
                   nullptr, 0,
                   reinterpret_cast<unsigned char *>(inBuf.data()),
                   static_cast<unsigned int>(inBuf.size()),
                   reinterpret_cast<unsigned char *>(iv.data()),
                   static_cast<unsigned int>(iv.size()),
                   nullptr, 0,
                   reinterpret_cast<unsigned char *>(key.data()),
                   static_cast<unsigned int>(key.size()),
                   kMcAlgLea, kMcModeCtr)
        : _decrypt(reinterpret_cast<unsigned char *>(out.data()),
                   reinterpret_cast<unsigned char *>(inBuf.data()),
                   static_cast<unsigned int>(inBuf.size()),
                   nullptr, 0,
                   reinterpret_cast<unsigned char *>(iv.data()),
                   static_cast<unsigned int>(iv.size()),
                   nullptr, 0,
                   reinterpret_cast<unsigned char *>(key.data()),
                   static_cast<unsigned int>(key.size()),
                   kMcAlgLea, kMcModeCtr);

    const unsigned int expect = encrypt ? kEncryptSuccess : kDecryptSuccess;
    if (rc != expect) {
        if (error) {
            *error = QStringLiteral("MCM-L %1 failed: 0x%2")
                         .arg(encrypt ? QStringLiteral("encrypt") : QStringLiteral("decrypt"))
                         .arg(rc, 8, 16, QLatin1Char('0'));
        }
        return {};
    }

    out.resize(input.size());
    return out;
}

QByteArray McmLCryptoEngine::encryptFixedIvMessage(const QByteArray &plain, QString *error)
{
    return crypt(true, plain, error);
}

QByteArray McmLCryptoEngine::decryptFixedIvMessage(const QByteArray &cipher, QString *error)
{
    return crypt(false, cipher, error);
}
