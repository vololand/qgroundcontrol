#pragma once

#include "TngCryptoConfig.h"

#include <QtCore/QByteArray>
#include <QtCore/QLibrary>
#include <QtCore/QString>

class McmLCryptoEngine
{
public:
    static constexpr int kIvLen = 16;

    McmLCryptoEngine() = default;
    ~McmLCryptoEngine();

    McmLCryptoEngine(const McmLCryptoEngine &) = delete;
    McmLCryptoEngine &operator=(const McmLCryptoEngine &) = delete;

    bool init(const TngCryptoConfig &config, QString *error = nullptr);
    void close();

    bool isReady() const { return _ready; }

    /// 송신: 고정 IV CTR. 매 호출 카운터를 IV로 리셋.
    QByteArray encryptFixedIvMessage(const QByteArray &plain, QString *error = nullptr);
    /// 수신: 고정 IV CTR. 매 호출 카운터를 IV로 리셋.
    QByteArray decryptFixedIvMessage(const QByteArray &cipher, QString *error = nullptr);

private:
    using EncryptFn = unsigned int (*)(unsigned char *, unsigned char *, unsigned int,
                                       unsigned char *, unsigned int,
                                       unsigned char *, unsigned int,
                                       unsigned char *, unsigned int,
                                       unsigned char *, unsigned int,
                                       unsigned char, unsigned char);
    using DecryptFn = unsigned int (*)(unsigned char *, unsigned char *, unsigned int,
                                       unsigned char *, unsigned int,
                                       unsigned char *, unsigned int,
                                       unsigned char *, unsigned int,
                                       unsigned char *, unsigned int,
                                       unsigned char, unsigned char);

    bool resolveSymbols(QString *error);
    QByteArray crypt(bool encrypt, const QByteArray &input, QString *error);

    QLibrary _lib;
    TngCryptoConfig _config;
    EncryptFn _encrypt = nullptr;
    DecryptFn _decrypt = nullptr;
    bool _ready = false;
};
