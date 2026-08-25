#pragma once

#include <QtCore/QByteArray>
#include <QtCore/QMutex>
#include <QtCore/QString>

#include "TngCryptoEngine.h"

class TngVideoCryptoService
{
public:
    enum class SpeedMode {
        Normal,
        High,
    };

    /// 송신측이 무엇을 암호화하는지. video_endpoints.ini [crypto] framing 이 결정한다.
    enum class Framing {
        RtpPayload, ///< 제어 채널은 평문이고 RTP 페이로드만 암호문이다.
        RtspFrame,  ///< 제어 채널의 모든 PDU 가 [u32 BE 길이][암호문] 으로 온다.
    };

    static TngVideoCryptoService &instance();

    /// ini 를 읽어 프레이밍을 돌려준다. 값이 없거나 알 수 없으면 RtpPayload 다.
    static Framing framing();

    bool acquire(SpeedMode mode, QString *error = nullptr);
    void release();

    QByteArray encryptChunk(const QByteArray &plain, SpeedMode mode, QString *error = nullptr);
    QByteArray decryptChunk(const QByteArray &cipher, SpeedMode mode, QString *error = nullptr);

private:
    TngVideoCryptoService() = default;
    ~TngVideoCryptoService() = default;

    Q_DISABLE_COPY_MOVE(TngVideoCryptoService)

    static QByteArray _fingerprint(const TngCryptoConfig &config);

    /// 조용히 폴백하면 성능 저하 원인을 추적할 수 없다. 로그 창(Console)에도 같은 줄을 남긴다.
    static void _reportToConsole(const QString &line);

    void _clearKeystream();
    /// CTR Fixed IV 키스트림을 bytes 이상 확보한다. 실패해도 기존 세션 경로로 넘어가면 된다.
    bool _ensureKeystream(qsizetype bytes, SpeedMode mode, QString *error);
    QByteArray _xorKeystream(const QByteArray &data) const;
    /// CTR 암·복호는 같은 XOR 이다. 캐시가 없으면 패킷마다 Open/Close 하던 엔진 경로로 폴백한다.
    QByteArray _xorOrEngine(const QByteArray &data, SpeedMode mode, bool encrypt, QString *error);

    QMutex _mutex;
    TngCryptoEngine _engine;
    QByteArray _configFingerprint;
    int _users = 0;

    /// CTR + padding 없음일 때만 XOR 캐시를 쓴다. CBC/패딩은 기존 세션 경로.
    bool _xorCacheEnabled = false;
    /// 키스트림 생성이 규약과 안 맞으면 매 패킷마다 재시도하지 않는다.
    bool _keystreamUnusable = false;
    /// 상한을 넘는 청크는 캐시를 못 쓴다. 패킷마다 같은 줄을 찍지 않도록 한 번만 알린다.
    bool _oversizeReported = false;
    QByteArray _keystream;
};
