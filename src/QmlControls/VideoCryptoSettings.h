#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QVariantList>

/// video_endpoints.ini [crypto] 섹션의 편집 가능한 항목만 QML에 노출한다.
class VideoCryptoSettings : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool     enabled         READ enabled         WRITE setEnabled         NOTIFY changed)
    Q_PROPERTY(QString  alg             READ alg             WRITE setAlg             NOTIFY changed)
    Q_PROPERTY(QString  mode            READ mode            WRITE setMode            NOTIFY changed)
    /// tngCore API 속도. normal | high (고속은 CTR + tngEncHs/tngDecHs).
    Q_PROPERTY(QString  speedMode       READ speedMode       WRITE setSpeedMode       NOTIFY changed)
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
    explicit VideoCryptoSettings(QObject *parent = nullptr);

    static VideoCryptoSettings *instance();
    static void registerQmlTypes();

    bool     enabled()         const { return _enabled; }
    QString  alg()             const { return _alg; }
    QString  mode()            const { return _mode; }
    QString  speedMode()       const { return _speedMode; }
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
    void setAlg(const QString &v)        { if (_alg != v)             { _alg = v;             emit changed(); } }
    void setMode(const QString &v)       { if (_mode != v)            { _mode = v;            emit changed(); } }
    void setSpeedMode(const QString &v);
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
    Q_INVOKABLE bool save();
    Q_INVOKABLE void generateKey();
    Q_INVOKABLE void refreshKeystore();
    Q_INVOKABLE void deleteKey(int index);
    Q_INVOKABLE void deleteAllKeys();

signals:
    void changed();
    void saved();
    void keyGenerateResult(bool ok, const QString &message);
    void keyDeleteResult(bool ok, const QString &message);
    void keystoreChanged();

private:
    static QString _normalizeSpeedMode(const QString &mode);

    QString _iniPath;

    bool    _enabled         = true;
    QString _alg             = QStringLiteral("ARIA256");
    QString _mode            = QStringLiteral("CTR");
    QString _speedMode       = QStringLiteral("normal");
    bool    _padding         = false;
    QString _keySource       = QStringLiteral("hex");
    int     _keyIndex        = 1;
    QString _sysUnique       = QStringLiteral("My_Desktop_PC");
    QString _packageId       = QStringLiteral("QGC_Video");
    QString _keystorePath;
    QString _libDir          = QStringLiteral(".");
    bool    _failOnError     = true;
    int     _maxPayloadBytes = 2048;

    QVariantList _savedKeys;
    int          _latestIndex = -1;
};
