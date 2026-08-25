#include "VideoCryptoSettings.h"
#include "VideoEndpointSettings.h"
#include "TngCryptoConfig.h"
#include "TngCryptoEngine.h"

#include <QtCore/qapplicationstatic.h>
#include <QtCore/QFile>
#include <QtCore/QSettings>
#include <QtCore/QVariant>
#include <QtCore/QVariantMap>
#include <QtQml/qqml.h>

namespace {

bool iniToBool(const QVariant &v, bool defaultValue)
{
    if (!v.isValid() || v.toString().trimmed().isEmpty()) {
        return defaultValue;
    }
    const QString s = v.toString().trimmed().toLower();
    if (s == QLatin1String("true") || s == QLatin1String("1") || s == QLatin1String("yes")) {
        return true;
    }
    if (s == QLatin1String("false") || s == QLatin1String("0") || s == QLatin1String("no")) {
        return false;
    }
    return defaultValue;
}

QString normalize(const QString &value, const QStringList &allowed, const QString &defaultValue)
{
    for (const QString &a : allowed) {
        if (value.compare(a, Qt::CaseInsensitive) == 0) {
            return a;
        }
    }
    return defaultValue;
}

/// video_endpoints.ini 의 [crypto] 를 읽되, 프로세스 전역인 코어 identity 는 crypto.ini 값을 채택한다.
/// 그래야 이 화면이 실제 영상 스트림과 동일한 키스토어를 관리한다.
bool loadVideoCryptoConfig(const QString &iniPath, TngCryptoConfig &cfg, QString *error)
{
    if (!TngCryptoConfig::load(iniPath, cfg, error)) {
        return false;
    }
    TngCryptoConfig::applyGlobalIdentity(cfg);
    return true;
}

} // namespace

Q_APPLICATION_STATIC(VideoCryptoSettings, _videoCryptoSettingsInstance)

VideoCryptoSettings::VideoCryptoSettings(QObject *parent)
    : QObject(parent)
{
    reload();
}

VideoCryptoSettings *VideoCryptoSettings::instance()
{
    return _videoCryptoSettingsInstance();
}

void VideoCryptoSettings::registerQmlTypes()
{
    (void) qmlRegisterUncreatableType<VideoCryptoSettings>(
        "QGroundControl", 1, 0, "VideoCryptoSettings", "Reference only");
}

QString VideoCryptoSettings::_normalizeSpeedMode(const QString &mode)
{
    return mode.trimmed().compare(QLatin1String("high"), Qt::CaseInsensitive) == 0
               ? QStringLiteral("high")
               : QStringLiteral("normal");
}

void VideoCryptoSettings::setSpeedMode(const QString &v)
{
    const QString normalized = _normalizeSpeedMode(v);
    if (_speedMode == normalized) {
        return;
    }
    _speedMode = normalized;
    // tngEncHs/tngDecHs 는 CTR 전용(매뉴얼). 고속 선택 시 cipher mode 를 CTR 로 맞춘다.
    if (_speedMode == QLatin1String("high") && _mode != QLatin1String("CTR")) {
        _mode = QStringLiteral("CTR");
    }
    emit changed();
}

void VideoCryptoSettings::reload()
{
    _iniPath = VideoEndpointSettings::resolveIniPath();
    if (!QFile::exists(_iniPath)) {
        // VideoEndpointSettings 가 템플릿을 만들도록 reload 한 번 호출.
        VideoEndpointSettings::instance()->reload();
        _iniPath = VideoEndpointSettings::resolveIniPath();
    } else {
        VideoEndpointSettings::ensureCryptoSection(_iniPath);
    }

    const QSettings s(_iniPath, QSettings::IniFormat);

    _enabled         = iniToBool(s.value(QStringLiteral("crypto/enabled"), QStringLiteral("true")), true);
    _alg             = normalize(s.value(QStringLiteral("crypto/alg"), QStringLiteral("ARIA256")).toString().trimmed().toUpper(),
                                 { QStringLiteral("ARIA128"), QStringLiteral("ARIA256") }, QStringLiteral("ARIA256"));
    _mode            = normalize(s.value(QStringLiteral("crypto/mode"), QStringLiteral("CTR")).toString().trimmed().toUpper(),
                                 { QStringLiteral("ECB"), QStringLiteral("CBC"), QStringLiteral("CTR") }, QStringLiteral("CTR"));
    _speedMode       = _normalizeSpeedMode(
        s.value(QStringLiteral("crypto/speed_mode"), _speedMode).toString());
    if (_speedMode == QLatin1String("high")) {
        _mode = QStringLiteral("CTR");
    }
    _padding         = iniToBool(s.value(QStringLiteral("crypto/padding"), QStringLiteral("false")), false);
    _keySource       = normalize(s.value(QStringLiteral("crypto/key_source"), QStringLiteral("hex")).toString().trimmed().toLower(),
                                 { QStringLiteral("keystore_latest"), QStringLiteral("keystore_index"), QStringLiteral("hex") }, QStringLiteral("hex"));
    _keyIndex        = s.value(QStringLiteral("crypto/key_index"), 1).toInt();
    _sysUnique       = s.value(QStringLiteral("crypto/sys_unique"), QStringLiteral("My_Desktop_PC")).toString();
    _packageId       = s.value(QStringLiteral("crypto/package_id"), QStringLiteral("QGC_Video")).toString();
    _keystorePath    = s.value(QStringLiteral("crypto/keystore_path")).toString();
    _libDir          = s.value(QStringLiteral("crypto/lib_dir"), QStringLiteral(".")).toString();
    _failOnError     = iniToBool(s.value(QStringLiteral("crypto/fail_on_error"), QStringLiteral("true")), true);
    _maxPayloadBytes = s.value(QStringLiteral("crypto/max_payload_bytes"), 2048).toInt();

    emit changed();
}

bool VideoCryptoSettings::save()
{
    if (_iniPath.isEmpty()) {
        _iniPath = VideoEndpointSettings::resolveIniPath();
    }

    VideoEndpointSettings::ensureCryptoSection(_iniPath);

    QSettings s(_iniPath, QSettings::IniFormat);
    if (s.status() != QSettings::NoError && !s.isWritable()) {
        return false;
    }

    // 노출 항목만 기록. key_hex/iv_hex 등 나머지 키는 QSettings가 보존한다.
    s.setValue(QStringLiteral("crypto/enabled"),           _enabled ? QStringLiteral("true") : QStringLiteral("false"));
    s.setValue(QStringLiteral("crypto/alg"),               _alg);
    s.setValue(QStringLiteral("crypto/mode"),              _mode);
    s.setValue(QStringLiteral("crypto/speed_mode"),        _speedMode);
    s.setValue(QStringLiteral("crypto/padding"),           _padding ? QStringLiteral("true") : QStringLiteral("false"));
    s.setValue(QStringLiteral("crypto/key_source"),        _keySource);
    s.setValue(QStringLiteral("crypto/key_index"),         _keyIndex);
    s.setValue(QStringLiteral("crypto/sys_unique"),        _sysUnique);
    s.setValue(QStringLiteral("crypto/package_id"),        _packageId);
    s.setValue(QStringLiteral("crypto/keystore_path"),     _keystorePath);
    s.setValue(QStringLiteral("crypto/lib_dir"),           _libDir);
    s.setValue(QStringLiteral("crypto/fail_on_error"),     _failOnError ? QStringLiteral("true") : QStringLiteral("false"));
    s.setValue(QStringLiteral("crypto/max_payload_bytes"), _maxPayloadBytes);

    s.sync();
    if (s.status() != QSettings::NoError) {
        return false;
    }

    emit saved();
    return true;
}

void VideoCryptoSettings::generateKey()
{
    TngCryptoConfig cfg;
    QString err;
    if (!loadVideoCryptoConfig(_iniPath, cfg, &err)) {
        emit keyGenerateResult(false, tr("설정 로드 실패: %1").arg(err));
        return;
    }

    TngCryptoEngine engine;
    int index = 0;
    if (engine.generateAndSaveKey(cfg, &index, &err)) {
        const int keyLen = TngCryptoConfig::expectedKeyBytes(cfg.alg);
        emit keyGenerateResult(true,
            tr("키 생성·저장 완료 (index=%1, %2 bytes) → %3").arg(index).arg(keyLen).arg(cfg.keystorePath));
        refreshKeystore();
    } else {
        emit keyGenerateResult(false, tr("키 생성 실패: %1").arg(err));
    }
}

void VideoCryptoSettings::refreshKeystore()
{
    TngCryptoConfig cfg;
    (void) loadVideoCryptoConfig(_iniPath, cfg, nullptr);

    TngCryptoEngine engine;
    QList<TngCryptoEngine::KeyEntry> keys;
    int latest = -1;
    engine.queryKeystore(cfg, &keys, &latest, nullptr);

    _savedKeys.clear();
    for (const TngCryptoEngine::KeyEntry &e : keys) {
        QVariantMap m;
        m.insert(QStringLiteral("index"), e.index);
        m.insert(QStringLiteral("date"), e.date);
        m.insert(QStringLiteral("label"),
                 e.date.isEmpty() ? QString::number(e.index)
                                  : QStringLiteral("%1  (%2)").arg(e.index).arg(e.date));
        _savedKeys.append(m);
    }
    _latestIndex = latest;
    emit keystoreChanged();
}

void VideoCryptoSettings::deleteKey(int index)
{
    TngCryptoConfig cfg;
    QString err;
    if (!loadVideoCryptoConfig(_iniPath, cfg, &err)) {
        emit keyDeleteResult(false, tr("설정 로드 실패: %1").arg(err));
        return;
    }

    TngCryptoEngine engine;
    if (engine.destroyKey(cfg, index, &err)) {
        emit keyDeleteResult(true, tr("키 삭제 완료 (index=%1)").arg(index));
        refreshKeystore();
    } else {
        emit keyDeleteResult(false, tr("키 삭제 실패: %1").arg(err));
    }
}

void VideoCryptoSettings::deleteAllKeys()
{
    TngCryptoConfig cfg;
    QString err;
    if (!loadVideoCryptoConfig(_iniPath, cfg, &err)) {
        emit keyDeleteResult(false, tr("설정 로드 실패: %1").arg(err));
        return;
    }

    TngCryptoEngine engine;
    if (engine.destroyAllKeys(cfg, &err)) {
        emit keyDeleteResult(true, tr("전체 키 삭제 완료"));
        refreshKeystore();
    } else {
        emit keyDeleteResult(false, tr("전체 키 삭제 실패: %1").arg(err));
    }
}
