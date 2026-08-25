#include "TngCryptoSettings.h"
#include "TngCryptoConfig.h"
#include "TngCryptoEngine.h"

#include <QtCore/qapplicationstatic.h>
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

} // namespace

Q_APPLICATION_STATIC(TngCryptoSettings, _tngCryptoSettingsInstance)

TngCryptoSettings::TngCryptoSettings(QObject *parent)
    : QObject(parent)
{
    reload();
}

TngCryptoSettings *TngCryptoSettings::instance()
{
    return _tngCryptoSettingsInstance();
}

void TngCryptoSettings::registerQmlTypes()
{
    (void) qmlRegisterUncreatableType<TngCryptoSettings>(
        "QGroundControl", 1, 0, "TngCryptoSettings", "Reference only");
}

void TngCryptoSettings::setProvider(const QString &v)
{
    const QString n = normalize(v.trimmed().toLower(),
                                { QStringLiteral("tngcore"), QStringLiteral("mcml") },
                                QStringLiteral("tngcore"));
    if (_provider == n) {
        return;
    }
    _provider = n;
    if (_provider == QLatin1String("mcml")) {
        if (!_alg.startsWith(QLatin1String("LEA"))) {
            _alg = QStringLiteral("LEA256");
        }
        _mode = QStringLiteral("CTR");
        _padding = false;
        _keySource = QStringLiteral("hex");
    } else if (_alg.startsWith(QLatin1String("LEA"))) {
        _alg = QStringLiteral("ARIA256");
    }
    emit changed();
}

void TngCryptoSettings::reload()
{
    // Server 링크가 실제로 읽는 파일과 동일 경로를 사용한다.
    // 파일이 없으면 기본 템플릿이 생성되도록 로더를 한 번 호출한다(반환값 무시).
    TngCryptoConfig tmp;
    (void) TngCryptoConfig::load(QString(), tmp, nullptr);

    _iniPath = TngCryptoConfig::resolveIniPath();

    const QSettings s(_iniPath, QSettings::IniFormat);

    _enabled         = iniToBool(s.value(QStringLiteral("crypto/enabled"), QStringLiteral("true")), true);
    _provider        = normalize(s.value(QStringLiteral("crypto/provider"), QStringLiteral("tngcore")).toString().trimmed().toLower(),
                                 { QStringLiteral("tngcore"), QStringLiteral("mcml") }, QStringLiteral("tngcore"));
    if (_provider == QLatin1String("mcml")) {
        _alg         = normalize(s.value(QStringLiteral("crypto/mcm_alg"), QStringLiteral("LEA256")).toString().trimmed().toUpper(),
                                 { QStringLiteral("LEA128"), QStringLiteral("LEA192"), QStringLiteral("LEA256") }, QStringLiteral("LEA256"));
        _mode        = QStringLiteral("CTR");
        _padding     = false;
        _keySource   = QStringLiteral("hex");
    } else {
        _alg         = normalize(s.value(QStringLiteral("crypto/alg"), QStringLiteral("ARIA256")).toString().trimmed().toUpper(),
                                 { QStringLiteral("ARIA128"), QStringLiteral("ARIA256") }, QStringLiteral("ARIA256"));
        _mode        = normalize(s.value(QStringLiteral("crypto/mode"), QStringLiteral("CTR")).toString().trimmed().toUpper(),
                                 { QStringLiteral("ECB"), QStringLiteral("CBC"), QStringLiteral("CTR") }, QStringLiteral("CTR"));
        _padding     = iniToBool(s.value(QStringLiteral("crypto/padding"), QStringLiteral("false")), false);
        _keySource   = normalize(s.value(QStringLiteral("crypto/key_source"), QStringLiteral("hex")).toString().trimmed().toLower(),
                                 { QStringLiteral("keystore_latest"), QStringLiteral("keystore_index"), QStringLiteral("hex") }, QStringLiteral("hex"));
    }
    _keyIndex        = s.value(QStringLiteral("crypto/key_index"), 1).toInt();
    _sysUnique       = s.value(QStringLiteral("crypto/sys_unique"), QStringLiteral("My_Desktop_PC")).toString();
    _packageId       = s.value(QStringLiteral("crypto/package_id"), QStringLiteral("QGC_TngTest")).toString();
    _keystorePath    = s.value(QStringLiteral("crypto/keystore_path")).toString();
    _libDir          = s.value(QStringLiteral("crypto/lib_dir"), QStringLiteral(".")).toString();
    _failOnError     = iniToBool(s.value(QStringLiteral("crypto/fail_on_error"), QStringLiteral("true")), true);
    _maxPayloadBytes = s.value(QStringLiteral("crypto/max_payload_bytes"), 2048).toInt();

    emit changed();
}

bool TngCryptoSettings::save()
{
    if (_iniPath.isEmpty()) {
        _iniPath = TngCryptoConfig::resolveIniPath();
    }

    QSettings s(_iniPath, QSettings::IniFormat);
    if (s.status() != QSettings::NoError && !s.isWritable()) {
        return false;
    }

    s.setValue(QStringLiteral("crypto/enabled"),           _enabled ? QStringLiteral("true") : QStringLiteral("false"));
    s.setValue(QStringLiteral("crypto/provider"),          _provider);
    s.setValue(QStringLiteral("crypto/fail_on_error"),     _failOnError ? QStringLiteral("true") : QStringLiteral("false"));
    s.setValue(QStringLiteral("crypto/max_payload_bytes"), _maxPayloadBytes);

    if (_provider == QLatin1String("mcml")) {
        if (!_alg.startsWith(QLatin1String("LEA"))) {
            _alg = QStringLiteral("LEA256");
        }
        const int algId = (_alg == QLatin1String("LEA128")) ? TngCryptoConfig::kAlgLea128
                        : (_alg == QLatin1String("LEA192")) ? TngCryptoConfig::kAlgLea192
                                                           : TngCryptoConfig::kAlgLea256;
        s.setValue(QStringLiteral("crypto/mcm_alg"),     _alg);
        s.setValue(QStringLiteral("crypto/mcm_key_hex"), TngCryptoConfig::defaultKeyHexForAlg(algId));
        s.setValue(QStringLiteral("crypto/mcm_iv_hex"),  TngCryptoConfig::defaultIvHex());
    } else {
        s.setValue(QStringLiteral("crypto/alg"),               _alg);
        s.setValue(QStringLiteral("crypto/mode"),              _mode);
        s.setValue(QStringLiteral("crypto/padding"),           _padding ? QStringLiteral("true") : QStringLiteral("false"));
        s.setValue(QStringLiteral("crypto/key_source"),        _keySource);
        s.setValue(QStringLiteral("crypto/key_index"),         _keyIndex);
        s.setValue(QStringLiteral("crypto/sys_unique"),        _sysUnique);
        s.setValue(QStringLiteral("crypto/package_id"),        _packageId);
        s.setValue(QStringLiteral("crypto/keystore_path"),     _keystorePath);
        s.setValue(QStringLiteral("crypto/lib_dir"),           _libDir);
    }

    s.sync();
    if (s.status() != QSettings::NoError) {
        return false;
    }

    emit saved();
    return true;
}

void TngCryptoSettings::generateKey()
{
    if (_provider == QLatin1String("mcml")) {
        emit keyGenerateResult(false, tr("MCM-L은 키스토어를 지원하지 않습니다. mcm_key_hex를 사용하세요."));
        return;
    }
    // 연결이 실제로 사용하는 ini 설정(resolved keystorePath 포함)을 기준으로 생성한다.
    TngCryptoConfig cfg;
    (void) TngCryptoConfig::load(QString(), cfg, nullptr);

    TngCryptoEngine engine;
    int index = 0;
    QString err;
    if (engine.generateAndSaveKey(cfg, &index, &err)) {
        const int keyLen = TngCryptoConfig::expectedKeyBytes(cfg.alg);
        emit keyGenerateResult(true,
            tr("키 생성·저장 완료 (index=%1, %2 bytes) → %3").arg(index).arg(keyLen).arg(cfg.keystorePath));
        refreshKeystore();
    } else {
        emit keyGenerateResult(false, tr("키 생성 실패: %1").arg(err));
    }
}

void TngCryptoSettings::refreshKeystore()
{
    if (_provider == QLatin1String("mcml")) {
        _savedKeys.clear();
        _latestIndex = -1;
        emit keystoreChanged();
        return;
    }
    TngCryptoConfig cfg;
    (void) TngCryptoConfig::load(QString(), cfg, nullptr);

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

void TngCryptoSettings::deleteKey(int index)
{
    if (_provider == QLatin1String("mcml")) {
        emit keyDeleteResult(false, tr("MCM-L은 키스토어를 지원하지 않습니다."));
        return;
    }
    TngCryptoConfig cfg;
    (void) TngCryptoConfig::load(QString(), cfg, nullptr);

    TngCryptoEngine engine;
    QString err;
    if (engine.destroyKey(cfg, index, &err)) {
        emit keyDeleteResult(true, tr("키 삭제 완료 (index=%1)").arg(index));
        refreshKeystore();
    } else {
        emit keyDeleteResult(false, tr("키 삭제 실패: %1").arg(err));
    }
}

void TngCryptoSettings::deleteAllKeys()
{
    if (_provider == QLatin1String("mcml")) {
        emit keyDeleteResult(false, tr("MCM-L은 키스토어를 지원하지 않습니다."));
        return;
    }
    TngCryptoConfig cfg;
    (void) TngCryptoConfig::load(QString(), cfg, nullptr);

    TngCryptoEngine engine;
    QString err;
    if (engine.destroyAllKeys(cfg, &err)) {
        emit keyDeleteResult(true, tr("전체 키 삭제 완료"));
        refreshKeystore();
    } else {
        emit keyDeleteResult(false, tr("전체 키 삭제 실패: %1").arg(err));
    }
}
