#pragma once

#include "TngCoreRuntime.h"
#include "TngCryptoConfig.h"

#include <QtCore/QByteArray>
#include <QtCore/QList>
#include <QtCore/QString>

/// tngCore 세션 1벌. DLL 로드와 tngInitCore/tngCloseCore(프로세스 전역)는 TngCoreRuntime 이
/// 참조 계수로 소유하므로, 이 클래스는 자기 설정·키·세션·프레이밍만 책임진다.
/// 따라서 여러 인스턴스(암호 MAVLink 링크 / 암호 영상)가 동시에 살아 있어도 서로를 무효화하지 않는다.
class TngCryptoEngine
{
public:
    static constexpr int kIvLen = 16;

    /// 키스토어에 저장된 키 1건의 요약(인덱스 + 저장일 yyyymmdd).
    struct KeyEntry {
        int index = 0;
        QString date;
    };

    TngCryptoEngine() = default;
    ~TngCryptoEngine();

    TngCryptoEngine(const TngCryptoEngine &) = delete;
    TngCryptoEngine &operator=(const TngCryptoEngine &) = delete;

    bool init(const TngCryptoConfig &config, QString *error = nullptr);
    void close();

    /// [독립 실행] 키스토어에 새 키를 생성·저장한다(연결과 무관한 1회성 작업).
    bool generateAndSaveKey(const TngCryptoConfig &config, int *outIndex, QString *error = nullptr);

    /// [독립 실행] 키스토어에 저장된 키 목록(tngGetSavedKeyList)과 최신 인덱스(tngReadLatestKey)를 조회한다.
    /// 저장된 키가 없으면 outKeys는 비고 outLatestIndex는 -1.
    bool queryKeystore(const TngCryptoConfig &config, QList<KeyEntry> *outKeys, int *outLatestIndex, QString *error = nullptr);

    /// [독립 실행] 특정 인덱스 키를 안전 삭제한다(tngDestroyKey). 성공 시 내부 목록에서 제거된다.
    /// 주의: 탐색기 폴더 삭제와 달리 tngCore 내부 부기(카운터)까지 갱신된다.
    bool destroyKey(const TngCryptoConfig &config, int index, QString *error = nullptr);

    /// [독립 실행] 저장된 전체 키를 안전 삭제한다(tngDestroyAllKey). 내부 카운터도 초기화된다.
    bool destroyAllKeys(const TngCryptoConfig &config, QString *error = nullptr);

    bool isReady() const { return _acquired; }
    bool sessionsReady() const { return _encSessionOpen && _decSessionOpen; }

    /// TCP 연결 시: fixed IV 모드면 TX/RX 세션 Open
    bool openSessions(QString *error = nullptr);
    void closeSessions();

    /// 송신: Enc → [u32 BE len][IV][cipher] 반환
    QByteArray sealFrame(const QByteArray &plain, QString *error = nullptr);

    /// 수신: payload=[IV][cipher] → Dec → plain
    QByteArray unsealPayload(const QByteArray &payload, QString *error = nullptr);

    /// MavlinkFixedIv 전용: 고정 IV로 메시지 1건 암호화 (매 호출 CTR 카운터 리셋, 헤더 없음)
    QByteArray encryptFixedIvMessage(const QByteArray &plain, QString *error = nullptr);
    /// MavlinkFixedIv 전용: 고정 IV로 메시지 1건 복호화 (매 호출 CTR 카운터 리셋)
    QByteArray decryptFixedIvMessage(const QByteArray &cipher, QString *error = nullptr);
    /// 영상 테스트용: MavlinkFixedIv와 동일한 청크 경계/고정 IV를 tngEncHs로 처리한다.
    QByteArray encryptFixedIvHighSpeedMessage(const QByteArray &plain, QString *error = nullptr);
    /// 영상 테스트용: MavlinkFixedIv와 동일한 청크 경계/고정 IV를 tngDecHs로 처리한다.
    QByteArray decryptFixedIvHighSpeedMessage(const QByteArray &cipher, QString *error = nullptr);
    bool highSpeedAvailable() const { return TngCoreRuntime::instance().highSpeedAvailable(); }

private:
    /// 전역 코어를 취득하고 config 를 적용한다(독립 실행 작업 공통).
    /// 성공 시 호출측이 작업 후 close() 책임. 실패 시 내부에서 정리하고 false.
    bool openCoreForKeystore(const TngCryptoConfig &config, QString *error);
    bool loadSessionKey(QString *error);
    QByteArray generateIv(QString *error);
    bool openOneSession(unsigned int *sessionIndex, const QByteArray &iv, QString *error);
    QByteArray cryptOnSession(bool encrypt, unsigned int sessionIndex, const QByteArray &input, QString *error, bool highSpeed = false);
    QByteArray cryptWithIv(bool encrypt, const QByteArray &iv, const QByteArray &input, QString *error, bool highSpeed = false);
    QByteArray buildWireFrame(const QByteArray &iv, const QByteArray &cipher, QString *error);

    TngCryptoConfig _config;

    /// TngCoreRuntime 참조를 이 인스턴스가 하나 들고 있는지. close() 에서 정확히 한 번만 반납한다.
    bool _acquired = false;

    // 연결 수명 세션 (iv_mode=fixed). TX/RX 분리 — CTR 카운터 충돌 방지.
    QByteArray _sessionIv;
    unsigned int _encSessionIndex = 0;
    unsigned int _decSessionIndex = 0;
    bool _encSessionOpen = false;
    bool _decSessionOpen = false;
};
