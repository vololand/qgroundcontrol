#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QVariantList>

/// crypto.ini [crypto] 섹션의 편집 가능한 항목만 QML에 노출한다.
/// 저장은 QSettings로 이루어지며 key_hex/iv_hex 등 노출하지 않는 키는 그대로 보존된다.
/// 변경 사항은 Server 링크 재연결 시점(EncryptedMavlinkLink::_connect)에만 반영된다.
class TngCryptoSettings : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool     enabled         READ enabled         WRITE setEnabled         NOTIFY changed)
    Q_PROPERTY(QString  provider        READ provider        WRITE setProvider        NOTIFY changed)
    Q_PROPERTY(QString  alg             READ alg             WRITE setAlg             NOTIFY changed)
    Q_PROPERTY(QString  mode            READ mode            WRITE setMode            NOTIFY changed)
    Q_PROPERTY(bool     padding         READ padding         WRITE setPadding         NOTIFY changed)
    Q_PROPERTY(QString  keySource       READ keySource       WRITE setKeySource       NOTIFY changed)
    Q_PROPERTY(int      keyIndex        READ keyIndex        WRITE setKeyIndex        NOTIFY changed)
    Q_PROPERTY(QString  sysUnique       READ sysUnique       WRITE setSysUnique       NOTIFY changed)
    Q_PROPERTY(QString  packageId       READ packageId       WRITE setPackageId       NOTIFY changed)
    Q_PROPERTY(QString  keystorePath    READ keystorePath    WRITE setKeystorePath    NOTIFY changed)
    Q_PROPERTY(QString  libDir          READ libDir          WRITE setLibDir          NOTIFY changed)
    Q_PROPERTY(bool     failOnError     READ failOnError     WRITE setFailOnError     NOTIFY changed)
    Q_PROPERTY(int      maxPayloadBytes READ maxPayloadBytes WRITE setMaxPayloadBytes NOTIFY changed)
    Q_PROPERTY(QString  iniFilePath     READ iniFilePath     NOTIFY changed)
    Q_PROPERTY(QVariantList savedKeys   READ savedKeys       NOTIFY keystoreChanged)
    Q_PROPERTY(int      latestIndex     READ latestIndex     NOTIFY keystoreChanged)

public:
    explicit TngCryptoSettings(QObject *parent = nullptr);

    static TngCryptoSettings *instance();
    static void registerQmlTypes();

    bool     enabled()         const { return _enabled; }
    QString  provider()        const { return _provider; }
    QString  alg()             const { return _alg; }
    QString  mode()            const { return _mode; }
    bool     padding()         const { return _padding; }
    QString  keySource()       const { return _keySource; }
    int      keyIndex()        const { return _keyIndex; }
    QString  sysUnique()       const { return _sysUnique; }
    QString  packageId()       const { return _packageId; }
    QString  keystorePath()    const { return _keystorePath; }
    QString  libDir()          const { return _libDir; }
    bool     failOnError()     const { return _failOnError; }
    int      maxPayloadBytes() const { return _maxPayloadBytes; }
    QString  iniFilePath()     const { return _iniPath; }
    QVariantList savedKeys()   const { return _savedKeys; }
    int      latestIndex()     const { return _latestIndex; }

    void setEnabled(bool v)              { if (_enabled != v)         { _enabled = v;         emit changed(); } }
    void setProvider(const QString &v);
    void setAlg(const QString &v)        { if (_alg != v)             { _alg = v;             emit changed(); } }
    void setMode(const QString &v)       { if (_mode != v)            { _mode = v;            emit changed(); } }
    void setPadding(bool v)              { if (_padding != v)         { _padding = v;         emit changed(); } }
    void setKeySource(const QString &v)  { if (_keySource != v)       { _keySource = v;       emit changed(); } }
    void setKeyIndex(int v)              { if (_keyIndex != v)        { _keyIndex = v;        emit changed(); } }
    void setSysUnique(const QString &v)  { if (_sysUnique != v)       { _sysUnique = v;       emit changed(); } }
    void setPackageId(const QString &v)  { if (_packageId != v)       { _packageId = v;       emit changed(); } }
    void setKeystorePath(const QString &v){ if (_keystorePath != v)   { _keystorePath = v;    emit changed(); } }
    void setLibDir(const QString &v)     { if (_libDir != v)          { _libDir = v;          emit changed(); } }
    void setFailOnError(bool v)          { if (_failOnError != v)     { _failOnError = v;     emit changed(); } }
    void setMaxPayloadBytes(int v)       { if (_maxPayloadBytes != v) { _maxPayloadBytes = v; emit changed(); } }

    Q_INVOKABLE void reload();

    /// tngCore: 기존처럼 alg/mode 등만 기록하고 key_hex/iv_hex는 보존.
    /// MCM-L: mcm_alg / mcm_key_hex / mcm_iv_hex만 기록. TNG key_hex/iv_hex/alg는 건드리지 않는다.
    Q_INVOKABLE bool save();

    /// tngGenerateRandomNumber로 키를 생성해 키스토어(store/)에 tngSaveKey로 저장한다.
    /// 현재 ini의 alg/sys_unique/package_id/keystore_path 기준으로 동작한다.
    /// 결과는 keyGenerateResult(ok, message)로 통지된다.
    Q_INVOKABLE void generateKey();

    /// 키스토어(store/)에 저장된 키 목록과 최신 인덱스를 다시 조회한다.
    /// savedKeys(= [{index, date, label}, ...])와 latestIndex를 갱신하고 keystoreChanged를 emit한다.
    Q_INVOKABLE void refreshKeystore();

    /// 특정 인덱스 키를 tngDestroyKey로 안전 삭제한다. 탐색기 폴더 삭제와 달리 목록에서도 빠진다.
    /// 성공 시 refreshKeystore()로 목록을 갱신하고, 결과는 keyDeleteResult(ok, message)로 통지된다.
    Q_INVOKABLE void deleteKey(int index);

    /// 저장된 전체 키를 tngDestroyAllKey로 안전 삭제한다(내부 카운터까지 초기화).
    Q_INVOKABLE void deleteAllKeys();

signals:
    void changed();
    void saved();
    void keyGenerateResult(bool ok, const QString &message);
    void keyDeleteResult(bool ok, const QString &message);
    void keystoreChanged();

private:
    QString _iniPath;

    bool    _enabled         = true;
    QString _provider        = QStringLiteral("tngcore");
    QString _alg             = QStringLiteral("ARIA256");
    QString _mode            = QStringLiteral("CTR");
    bool    _padding         = false;
    QString _keySource       = QStringLiteral("hex");
    int     _keyIndex        = 1;
    QString _sysUnique       = QStringLiteral("My_Desktop_PC");
    QString _packageId       = QStringLiteral("QGC_TngTest");
    QString _keystorePath;
    QString _libDir          = QStringLiteral(".");
    bool    _failOnError     = true;
    int     _maxPayloadBytes = 2048;

    QVariantList _savedKeys;      // [{ index:int, date:QString, label:QString }, ...]
    int          _latestIndex = -1;
};
