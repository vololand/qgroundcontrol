#pragma once

#include <QtCore/QByteArray>
#include <QtCore/QString>

struct TngCryptoConfig
{
    enum class TcpMode {
        Client, // default
        Server
    };

    enum class KeySource {
        KeystoreLatest, // default (VDataRelay)
        KeystoreIndex,
        Hex
    };

    // 내부 고정 (VDataRelay conf에 없음 — 코드 기본값만 사용)
    enum class IvMode {
        PerMessage,
        Fixed // default
    };

    enum class FrameType {
        LenPrefixIvCipher, // [u32][IV][cipher]
        IvCipher,
        RawStream,
        MavlinkFixedIv // default: 헤더 없는 raw cipher, send 단위 CTR 리셋(고정 IV)
    };

    enum class LengthEndian {
        Big, // default
        Little
    };

    enum class Provider {
        TngCore, // default
        McmL
    };

    // alg: tngCore ARIA128=0 ARIA256=1 / MCM-L LEA128=10 LEA192=11 LEA256=12
    static constexpr int kAlgAria128 = 0;
    static constexpr int kAlgAria256 = 1;
    static constexpr int kAlgLea128  = 10;
    static constexpr int kAlgLea192  = 11;
    static constexpr int kAlgLea256  = 12;

    // --- tcp (GCS 접속; VDataRelay OutputIp/Port 대응) ---
    TcpMode tcpMode = TcpMode::Client;
    QString host = QStringLiteral("127.0.0.1");
    quint16 port = 10001;

    // --- crypto (VDataRelay [crypto] 정합) ---
    QString sysUnique = QStringLiteral("My_Desktop_PC");
    QString packageId = QStringLiteral("QGC_TngTest");
    QString keystorePath; // empty => tngCore default
    QString libDir = QStringLiteral("."); // tngcore.dll / mcm-l dll / KCMVP libs

    bool enabled = true; // false => 평문 TCP 통과 (테스트용)

    Provider provider = Provider::TngCore;

    int alg = 1;      // ARIA256 (tngCore) / LEA256=12 (MCM-L)
    int mode = 2;     // CTR (의미값. MCM-L DLL에는 3으로 매핑)
    int padding = 0;  // false

    KeySource keySource = KeySource::Hex; // 테스트 기본 hex (VDataRelay는 keystore_latest)
    int keyIndex = 1;
    QByteArray key;   // key_source=hex 또는 keystore 로드 후
    QByteArray iv;    // 16 bytes
    bool failOnError = true;
    int maxPayloadBytes = 2048;
    /// 연속 실패가 이 횟수에 도달하면 자동 재연결을 멈추고 사용자 확인을 기다린다.
    int maxConsecutiveFailures = 3;
    /// 실패 후 재연결 시도 기본 간격. 연속 실패마다 2배씩 늘어난다.
    int reconnectBackoffMs = 3000;
    /// 복호 결과를 MAVLink 프레임(CRC 포함)으로 검증한다. CTR처럼 복호 자체가 실패하지 않는
    /// 모드에서 잘못된 프로토콜/키를 판별할 유일한 근거이므로 기본 활성.
    bool validateMavlink = true;
    /// 접속 후 이 시간 안에 유효한 MAVLink 프레임이 하나도 없으면 실패로 본다. 0이면 비활성.
    int handshakeTimeoutMs = 5000;
    /// 마지막 유효 MAVLink 프레임 이후 이 시간이 지나면 실패로 본다. 0이면 비활성.
    int dataTimeoutMs = 10000;

    // 내부 전용 (ini에 없음)
    IvMode ivMode = IvMode::Fixed;
    FrameType frameType = FrameType::MavlinkFixedIv;
    LengthEndian lengthEndian = LengthEndian::Big;

    /// alg에 따른 키 바이트 수 (ARIA128/LEA128=16, LEA192=24, ARIA256/LEA256=32). 그 외 -1.
    static int expectedKeyBytes(int alg);

    bool usesMcmL() const { return provider == Provider::McmL; }

    /// lib_dir 기준 tngcore.dll 절대/상대 경로
    QString resolvedDllPath() const;

    /// lib_dir 기준 mcrypto_light_v1.0-x64_win.dll 절대/상대 경로
    QString resolvedMcmDllPath() const;

    /// Lea256Key.txt 기본값. MCM-L의 mcm_key_hex / mcm_iv_hex 전용. key_hex/iv_hex는 건드리지 않는다.
    static QString defaultLeaKeyHex();
    static QString defaultIvHex();
    /// alg 키 길이에 맞게 앞에서부터 자른 key_hex.
    static QString defaultKeyHexForAlg(int alg);

    bool isValid() const;

    /// 활성 crypto.ini 경로를 해석한다(파일 생성은 하지 않음).
    /// 설정 폴더(QSettings)/crypto.ini 가 있으면 그 경로,
    /// 없고 applicationDirPath()/crypto.ini 가 있으면 그 경로,
    /// 둘 다 없으면 설정 폴더 경로(기본 생성 대상)를 반환.
    /// 각 폴더에서 구 파일명(tng_crypto.ini)이 발견되면 crypto.ini로 옮긴 뒤 사용한다.
    static QString resolveIniPath();

    /// iniPath 가 비어 있으면 resolveIniPath() 규칙을 따르고, 파일이 없으면 기본 템플릿을 만든 뒤 로드한다.
    static bool load(const QString &iniPath, TngCryptoConfig &out, QString *error = nullptr);

    /// tngcore 코어 identity(lib_dir / sys_unique / package_id / keystore_path)는 프로세스 전역이라
    /// 암호 MAVLink 링크와 암호 영상이 반드시 같은 값을 써야 한다(다르면 뒤에 붙는 쪽이 코어 취득에 실패).
    /// crypto.ini 를 정본으로 삼아 config 의 identity 필드만 덮어쓴다.
    /// crypto.ini 를 읽지 못하면 config 를 그대로 두고 false 를 반환한다.
    static bool applyGlobalIdentity(TngCryptoConfig &config, QString *error = nullptr);
};
