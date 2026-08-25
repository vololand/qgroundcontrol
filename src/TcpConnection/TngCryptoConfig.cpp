#include "TngCryptoConfig.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QSettings>
#include <QtCore/QVariant>

namespace {

constexpr auto kIniFileName       = QLatin1String("crypto.ini");
constexpr auto kLegacyIniFileName = QLatin1String("tng_crypto.ini");

QByteArray hexToBytes(const QString &hex, int expectedLen, QString *error)
{
    const QString cleaned = hex.trimmed().remove(QLatin1Char(' ')).remove(QLatin1Char(':'));
    const QByteArray bytes = QByteArray::fromHex(cleaned.toLatin1());
    if (bytes.size() != expectedLen) {
        if (error) {
            *error = QStringLiteral("hex length mismatch: got %1 bytes, expected %2 (input='%3')")
                         .arg(bytes.size())
                         .arg(expectedLen)
                         .arg(hex);
        }
        return {};
    }
    return bytes;
}

bool parseAlg(const QString &v, int *out)
{
    const QString s = v.trimmed().toUpper().remove(QLatin1Char('-')).remove(QLatin1Char(' '));
    if (s == QLatin1String("ARIA256") || s == QLatin1String("1")) { *out = TngCryptoConfig::kAlgAria256; return true; }
    if (s == QLatin1String("ARIA128") || s == QLatin1String("0")) { *out = TngCryptoConfig::kAlgAria128; return true; }
    if (s == QLatin1String("LEA128") || s == QLatin1String("10")) { *out = TngCryptoConfig::kAlgLea128; return true; }
    if (s == QLatin1String("LEA192") || s == QLatin1String("11")) { *out = TngCryptoConfig::kAlgLea192; return true; }
    if (s == QLatin1String("LEA256") || s == QLatin1String("12")) { *out = TngCryptoConfig::kAlgLea256; return true; }
    bool ok = false;
    const int n = v.trimmed().toInt(&ok);
    if (ok && (n == 0 || n == 1 || n == 10 || n == 11 || n == 12)) { *out = n; return true; }
    return false;
}

bool parseProvider(const QString &v, TngCryptoConfig::Provider *out)
{
    const QString s = v.trimmed().toLower().remove(QLatin1Char('-')).remove(QLatin1Char('_'));
    if (s.isEmpty() || s == QLatin1String("tngcore") || s == QLatin1String("tng")) {
        *out = TngCryptoConfig::Provider::TngCore;
        return true;
    }
    if (s == QLatin1String("mcml") || s == QLatin1String("mcm")) {
        *out = TngCryptoConfig::Provider::McmL;
        return true;
    }
    return false;
}

QString resolveDllInLibDir(const QString &libDir, const QString &dllName)
{
    QString dir = libDir.trimmed();
    if (dir.isEmpty() || dir == QLatin1String(".")) {
        return QCoreApplication::applicationDirPath() + QLatin1Char('/') + dllName;
    }
    const QFileInfo fi(dir);
    if (fi.isFile()) {
        return QDir(fi.absolutePath()).filePath(dllName);
    }
    QString path = QDir(dir).filePath(dllName);
    if (QFileInfo(path).isRelative()) {
        path = QDir(QCoreApplication::applicationDirPath()).filePath(path);
    }
    return QFileInfo(path).absoluteFilePath();
}

bool parseMode(const QString &v, int *out)
{
    const QString s = v.trimmed().toUpper();
    if (s == QLatin1String("ECB") || s == QLatin1String("0")) { *out = 0; return true; }
    if (s == QLatin1String("CBC") || s == QLatin1String("1")) { *out = 1; return true; }
    if (s == QLatin1String("CTR") || s == QLatin1String("2")) { *out = 2; return true; }
    bool ok = false;
    const int n = v.trimmed().toInt(&ok);
    if (ok && (n == 0 || n == 1 || n == 2)) { *out = n; return true; }
    return false;
}

bool parsePadding(const QVariant &v, int *out)
{
    const QString s = v.toString().trimmed().toLower();
    if (s == QLatin1String("false") || s == QLatin1String("0") || s == QLatin1String("none") || s.isEmpty()) {
        *out = 0;
        return true;
    }
    if (s == QLatin1String("true") || s == QLatin1String("1")) {
        *out = 1;
        return true;
    }
    bool ok = false;
    const int n = v.toInt(&ok);
    if (ok) { *out = n; return true; }
    return false;
}

bool parseBool(const QVariant &v, bool defaultValue, bool *out)
{
    if (!v.isValid() || v.toString().trimmed().isEmpty()) {
        *out = defaultValue;
        return true;
    }
    const QString s = v.toString().trimmed().toLower();
    if (s == QLatin1String("true") || s == QLatin1String("1") || s == QLatin1String("yes")) {
        *out = true;
        return true;
    }
    if (s == QLatin1String("false") || s == QLatin1String("0") || s == QLatin1String("no")) {
        *out = false;
        return true;
    }
    return false;
}

/// 첫 실행 시 설정 폴더에 기본 템플릿 생성. best-effort: 실패해도 로드 흐름을 막지 않음.
bool writeDefaultIniTemplate(const QString &path)
{
    const QFileInfo fi(path);
    QDir().mkpath(fi.absolutePath());

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        return false;
    }

    // tcp 접속 정보는 Comm Links UI(Server 링크)에서 관리하므로 [crypto]만 생성.
    static const char kTemplate[] =
        "[crypto]\n"
        "\n"
        ";enabled: true | false | default true (false => plaintext TCP passthrough)\n"
        "enabled = true\n"
        "\n"
        "sys_unique = imx8-vdatarelay-001\n"
        "package_id = QGC_TngTest\n"
        "\n"
        ";keystore_path: tngSetKeystorePath (empty = ini 폴더의 store/ 자동 사용)\n"
        "keystore_path = C:/tngCore/VDataRelay_v0.1.0/keystore\n"
        "\n"
        ";lib_dir: directory of tngcore.dll / KCMVP libs (. = exe dir)\n"
        "lib_dir = .\n"
        "\n"
        ";provider: tngcore | mcml | default tngcore (exclusive)\n"
        "provider = tngcore\n"
        ";alg: ARIA128 | ARIA256 | default ARIA256\n"
        "alg = ARIA256\n"
        ";mode: ECB | CBC | CTR | default CTR\n"
        "mode = CTR\n"
        ";padding: true | false | default false\n"
        "padding = false\n"
        "\n"
        ";key_source: keystore_latest | keystore_index | hex | default keystore_latest\n"
        "key_source = hex\n"
        ";key_index: used when key_source = keystore_index\n"
        "key_index = 1\n"
        ";key_hex: used when key_source = hex (32 hex ARIA128 | 64 hex ARIA256)\n"
        "key_hex = 7D1B7A0110019712056CF18DCDF79E02118A26A8B6204444F68E246F8E1967A0\n"
        "\n"
        ";iv_hex: 32 hex (16 bytes), used for CBC/CTR\n"
        "iv_hex = 50121114F32EAA789608D779C331802E\n"
        "\n"
        "; MCM-L only. Does not replace key_hex/iv_hex.\n"
        ";mcm_alg: LEA128 | LEA192 | LEA256 | default LEA256\n"
        "mcm_alg = LEA256\n"
        "mcm_key_hex = 7D1B7A0110019712056CF18DCDF79E02118A26A8B6204444F68E246F8E1967A0\n"
        "mcm_iv_hex = 50121114F32EAA789608D779C331802E\n"
        "\n"
        ";fail_on_error: true | false | default true\n"
        "fail_on_error = true\n"
        ";max_payload_bytes: >16 | default 2048\n"
        "max_payload_bytes = 2048\n"
        ";max_consecutive_failures: 연속 실패 시 자동 재연결을 멈출 횟수 | default 3\n"
        "max_consecutive_failures = 3\n"
        ";reconnect_backoff_ms: 실패 후 재연결 기본 간격(ms), 실패마다 2배 | default 3000\n"
        "reconnect_backoff_ms = 3000\n"
        ";validate_mavlink: 복호 결과를 MAVLink CRC로 검증 | true | false | default true\n"
        "validate_mavlink = true\n"
        ";handshake_timeout_ms: 접속 후 유효 MAVLink 무수신 허용 시간(ms), 0=비활성 | default 5000\n"
        "handshake_timeout_ms = 5000\n"
        ";data_timeout_ms: 운용 중 유효 MAVLink 무수신 허용 시간(ms), 0=비활성 | default 10000\n"
        "data_timeout_ms = 10000\n";

    const qint64 written = file.write(kTemplate, static_cast<qint64>(sizeof(kTemplate) - 1));
    file.close();
    return written == static_cast<qint64>(sizeof(kTemplate) - 1);
}

bool parseKeySource(const QString &v, TngCryptoConfig::KeySource *out)
{
    const QString s = v.trimmed().toLower();
    if (s.isEmpty() || s == QLatin1String("keystore_latest")) {
        *out = TngCryptoConfig::KeySource::KeystoreLatest;
        return true;
    }
    if (s == QLatin1String("keystore_index")) {
        *out = TngCryptoConfig::KeySource::KeystoreIndex;
        return true;
    }
    if (s == QLatin1String("hex")) {
        *out = TngCryptoConfig::KeySource::Hex;
        return true;
    }
    return false;
}

/// dir에 남아 있는 구 파일명(tng_crypto.ini)을 newPath로 옮긴다.
/// 반환: 구 파일 없음 => 빈 문자열, 이동 성공 => newPath, 이동 실패 => 구 파일 경로.
/// 이동에 실패해도 구 파일을 그대로 쓰게 해서 기존 키·설정이 기본 템플릿으로 덮어써지지 않게 한다.
QString migrateLegacyIni(const QString &dir, const QString &newPath)
{
    const QString legacyPath = dir + QLatin1Char('/') + kLegacyIniFileName;
    if (!QFile::exists(legacyPath)) {
        return {};
    }
    return QFile::rename(legacyPath, newPath) ? newPath : legacyPath;
}

} // namespace

int TngCryptoConfig::expectedKeyBytes(int alg)
{
    if (alg == kAlgAria128 || alg == kAlgLea128) {
        return 16;
    }
    if (alg == kAlgLea192) {
        return 24;
    }
    if (alg == kAlgAria256 || alg == kAlgLea256) {
        return 32;
    }
    return -1;
}

QString TngCryptoConfig::resolvedDllPath() const
{
    return resolveDllInLibDir(libDir, QStringLiteral("tngcore.dll"));
}

QString TngCryptoConfig::resolvedMcmDllPath() const
{
    return resolveDllInLibDir(libDir, QStringLiteral("mcrypto_light_v1.0-x64_win.dll"));
}

QString TngCryptoConfig::defaultLeaKeyHex()
{
    return QStringLiteral("7D1B7A0110019712056CF18DCDF79E02118A26A8B6204444F68E246F8E1967A0");
}

QString TngCryptoConfig::defaultIvHex()
{
    return QStringLiteral("50121114F32EAA789608D779C331802E");
}

QString TngCryptoConfig::defaultKeyHexForAlg(int alg)
{
    const int keyLen = expectedKeyBytes(alg);
    const QString full = defaultLeaKeyHex();
    if (keyLen <= 0) {
        return {};
    }
    return full.left(keyLen * 2);
}

bool TngCryptoConfig::isValid() const
{
    if (!enabled) {
        return true;
    }

    const int keyLen = expectedKeyBytes(alg);
    if (host.isEmpty() || port == 0 || keyLen <= 0 || maxPayloadBytes <= 16 || iv.size() != 16) {
        return false;
    }

    if (provider == Provider::McmL) {
        if (mode != 2 || padding != 0 || keySource != KeySource::Hex
            || !(alg == kAlgLea128 || alg == kAlgLea192 || alg == kAlgLea256)
            || key.size() != keyLen) {
            return false;
        }
        return true;
    }

    if (!(mode == 0 || mode == 1 || mode == 2)
        || sysUnique.isEmpty() || packageId.isEmpty()
        || !(alg == kAlgAria128 || alg == kAlgAria256)) {
        return false;
    }

    if (keySource == KeySource::Hex) {
        return key.size() == keyLen;
    }
    if (keySource == KeySource::KeystoreIndex) {
        return keyIndex >= 1;
    }
    // keystore_latest: 키는 init 시 로드
    return true;
}

QString TngCryptoConfig::resolveIniPath()
{
    // QGC 기본 설정 .ini(QSettings)와 같은 폴더 우선.
    const QString settingsDir = QFileInfo(QSettings().fileName()).absolutePath();
    const QString settingsPath = settingsDir + QLatin1Char('/') + kIniFileName;
    if (QFile::exists(settingsPath)) {
        return settingsPath;
    }
    const QString migratedSettingsPath = migrateLegacyIni(settingsDir, settingsPath);
    if (!migratedSettingsPath.isEmpty()) {
        return migratedSettingsPath;
    }

    // 하위호환: 설정 폴더에 없으면 exe 폴더도 확인.
    const QString exeDir = QCoreApplication::applicationDirPath();
    const QString exePath = exeDir + QLatin1Char('/') + kIniFileName;
    if (QFile::exists(exePath)) {
        return exePath;
    }
    const QString migratedExePath = migrateLegacyIni(exeDir, exePath);
    if (!migratedExePath.isEmpty()) {
        return migratedExePath;
    }

    return settingsPath;
}

bool TngCryptoConfig::applyGlobalIdentity(TngCryptoConfig &config, QString *error)
{
    TngCryptoConfig linkConfig;
    if (!load(resolveIniPath(), linkConfig, error)) {
        return false;
    }

    config.libDir = linkConfig.libDir;
    config.sysUnique = linkConfig.sysUnique;
    config.packageId = linkConfig.packageId;
    config.keystorePath = linkConfig.keystorePath;
    return true;
}

bool TngCryptoConfig::load(const QString &iniPath, TngCryptoConfig &out, QString *error)
{
    QString path = iniPath;
    if (path.isEmpty()) {
        path = resolveIniPath();
        // 첫 실행/배포 직후: 파일이 없으면 설정 폴더에 기본 템플릿 생성 후 그대로 로드.
        if (!QFile::exists(path)) {
            writeDefaultIniTemplate(path);
        }
    }

    if (!QFile::exists(path)) {
        if (error) {
            *error = QStringLiteral("crypto.ini not found: %1").arg(path);
        }
        return false;
    }

    QSettings settings(path, QSettings::IniFormat);

    // tcp 접속 정보(host/port/mode)는 ini에서 읽지 않는다.
    // Comm Links UI(Server 링크 설정)에서 관리하며 EncryptedMavlinkLink::_connect()에서 주입.

    // crypto — VDataRelay 정합 (legacy [tng] 키도 허용)
    out.sysUnique = settings.value(QStringLiteral("crypto/sys_unique"),
                                   settings.value(QStringLiteral("tng/sys_unique"), out.sysUnique)).toString();
    out.packageId = settings.value(QStringLiteral("crypto/package_id"),
                                   settings.value(QStringLiteral("tng/package_id"), out.packageId)).toString();
    if (!parseBool(settings.value(QStringLiteral("crypto/enabled"), true), true, &out.enabled)) {
        if (error) {
            *error = QStringLiteral("crypto/enabled invalid (use true|false)");
        }
        return false;
    }
    out.keystorePath = settings.value(QStringLiteral("crypto/keystore_path")).toString().trimmed();
    if (out.keystorePath.isEmpty()) {
        // 비어 있으면 crypto.ini와 같은 폴더의 store/ 를 키스토어로 사용하고 폴더를 생성한다.
        out.keystorePath = QFileInfo(path).absolutePath() + QStringLiteral("/store");
    }
    QDir().mkpath(out.keystorePath);
    out.libDir = settings.value(QStringLiteral("crypto/lib_dir"),
                                settings.value(QStringLiteral("tng/dll_path"), out.libDir)).toString().trimmed();
    if (out.libDir.isEmpty()) {
        out.libDir = QStringLiteral(".");
    }

    if (!parseProvider(settings.value(QStringLiteral("crypto/provider")).toString(), &out.provider)) {
        if (error) {
            *error = QStringLiteral("crypto/provider invalid (use tngcore|mcml)");
        }
        return false;
    }

    out.keyIndex = settings.value(QStringLiteral("crypto/key_index"), out.keyIndex).toInt();
    out.key.clear();

    if (out.provider == Provider::McmL) {
        if (!parseAlg(settings.value(QStringLiteral("crypto/mcm_alg"), QStringLiteral("LEA256")).toString(), &out.alg)) {
            if (error) {
                *error = QStringLiteral("crypto/mcm_alg invalid (LEA128|LEA192|LEA256)");
            }
            return false;
        }
        if (!(out.alg == kAlgLea128 || out.alg == kAlgLea192 || out.alg == kAlgLea256)) {
            out.alg = kAlgLea256;
        }
        out.mode = 2;
        out.padding = 0;
        out.keySource = KeySource::Hex;

        const int keyLen = expectedKeyBytes(out.alg);
        QString storedKeyHex = settings.value(QStringLiteral("crypto/mcm_key_hex")).toString();
        QString storedIvHex = settings.value(QStringLiteral("crypto/mcm_iv_hex")).toString();
        bool persistDefaults = false;
        if (storedKeyHex.trimmed().remove(QLatin1Char(' ')).remove(QLatin1Char(':')).isEmpty()) {
            storedKeyHex = defaultKeyHexForAlg(out.alg);
            persistDefaults = true;
        }
        if (storedIvHex.trimmed().remove(QLatin1Char(' ')).remove(QLatin1Char(':')).isEmpty()) {
            storedIvHex = defaultIvHex();
            persistDefaults = true;
        }

        QString keyErr;
        out.key = hexToBytes(storedKeyHex, keyLen, &keyErr);
        if (out.key.isEmpty()) {
            if (error) {
                *error = QStringLiteral("crypto/mcm_key_hex invalid for alg=%1 (need %2 bytes): %3")
                             .arg(out.alg)
                             .arg(keyLen)
                             .arg(keyErr);
            }
            return false;
        }
        QString ivErr;
        out.iv = hexToBytes(storedIvHex, 16, &ivErr);
        if (out.iv.isEmpty()) {
            if (error) {
                *error = QStringLiteral("crypto/mcm_iv_hex invalid: %1").arg(ivErr);
            }
            return false;
        }
        if (persistDefaults) {
            settings.setValue(QStringLiteral("crypto/mcm_key_hex"), storedKeyHex);
            settings.setValue(QStringLiteral("crypto/mcm_iv_hex"), storedIvHex);
            settings.setValue(QStringLiteral("crypto/mcm_alg"),
                             (out.alg == kAlgLea128) ? QStringLiteral("LEA128")
                             : (out.alg == kAlgLea192) ? QStringLiteral("LEA192")
                                                       : QStringLiteral("LEA256"));
            settings.sync();
        }
    } else {
        if (!parseAlg(settings.value(QStringLiteral("crypto/alg"), QStringLiteral("ARIA256")).toString(), &out.alg)) {
            if (error) {
                *error = QStringLiteral("crypto/alg invalid (use ARIA128|ARIA256 or 0|1)");
            }
            return false;
        }
        if (out.alg == kAlgLea128) {
            out.alg = kAlgAria128;
        } else if (out.alg == kAlgLea192 || out.alg == kAlgLea256) {
            out.alg = kAlgAria256;
        }

        if (!parseMode(settings.value(QStringLiteral("crypto/mode"), QStringLiteral("CTR")).toString(), &out.mode)) {
            if (error) {
                *error = QStringLiteral("crypto/mode invalid (use ECB|CBC|CTR or 0|1|2)");
            }
            return false;
        }
        if (!parsePadding(settings.value(QStringLiteral("crypto/padding"), false), &out.padding)) {
            if (error) {
                *error = QStringLiteral("crypto/padding invalid");
            }
            return false;
        }
        if (!parseKeySource(settings.value(QStringLiteral("crypto/key_source"), QStringLiteral("hex")).toString(),
                            &out.keySource)) {
            if (error) {
                *error = QStringLiteral("crypto/key_source invalid (keystore_latest|keystore_index|hex)");
            }
            return false;
        }

        if (out.keySource == KeySource::Hex) {
            const int keyLen = expectedKeyBytes(out.alg);
            QString keyErr;
            out.key = hexToBytes(settings.value(QStringLiteral("crypto/key_hex")).toString(), keyLen, &keyErr);
            if (out.key.isEmpty()) {
                if (error) {
                    *error = QStringLiteral("crypto/key_hex invalid for alg=%1 (need %2 bytes): %3")
                                 .arg(out.alg)
                                 .arg(keyLen)
                                 .arg(keyErr);
                }
                return false;
            }
        }

        QString ivErr;
        out.iv = hexToBytes(settings.value(QStringLiteral("crypto/iv_hex")).toString(), 16, &ivErr);
        if (out.iv.isEmpty()) {
            if (error) {
                *error = QStringLiteral("crypto/iv_hex invalid: %1").arg(ivErr);
            }
            return false;
        }
    }

    if (!parseBool(settings.value(QStringLiteral("crypto/fail_on_error"), true), true, &out.failOnError)) {
        if (error) {
            *error = QStringLiteral("crypto/fail_on_error invalid");
        }
        return false;
    }

    out.maxPayloadBytes = settings.value(QStringLiteral("crypto/max_payload_bytes"), out.maxPayloadBytes).toInt();
    out.maxConsecutiveFailures = qMax(1, settings.value(QStringLiteral("crypto/max_consecutive_failures"),
                                                        out.maxConsecutiveFailures).toInt());
    out.reconnectBackoffMs = qBound(500, settings.value(QStringLiteral("crypto/reconnect_backoff_ms"),
                                                        out.reconnectBackoffMs).toInt(), 60000);

    if (!parseBool(settings.value(QStringLiteral("crypto/validate_mavlink"), true), true, &out.validateMavlink)) {
        if (error) {
            *error = QStringLiteral("crypto/validate_mavlink invalid");
        }
        return false;
    }

    out.handshakeTimeoutMs = qMax(0, settings.value(QStringLiteral("crypto/handshake_timeout_ms"),
                                                    out.handshakeTimeoutMs).toInt());
    out.dataTimeoutMs = qMax(0, settings.value(QStringLiteral("crypto/data_timeout_ms"),
                                               out.dataTimeoutMs).toInt());

    // 와이어 포맷은 송신측(릴레이)이 정하며 key_source와 무관하다(키 출처만 다름).
    // 릴레이와 검증된 방식: 고정 IV(iv_hex, 전송 안 함) + 헤더 없는 raw cipher (MavlinkFixedIv).
    // iv_hex는 릴레이가 사용하는 IV와 반드시 동일해야 한다.
    out.lengthEndian = LengthEndian::Big;
    out.ivMode = IvMode::Fixed;
    out.frameType = FrameType::MavlinkFixedIv;

    if (!out.isValid()) {
        if (error) {
            *error = QStringLiteral("crypto.ini incomplete or invalid: %1").arg(path);
        }
        return false;
    }

    return true;
}
