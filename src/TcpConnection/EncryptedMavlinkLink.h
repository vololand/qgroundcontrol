#pragma once

#include "LinkConfiguration.h"
#include "LinkInterface.h"
#include "EncryptedTcpPipe.h"

#include <QtCore/QString>

class EncryptedMavlinkConfiguration : public LinkConfiguration
{
    Q_OBJECT

    Q_PROPERTY(QString iniPath READ iniPath WRITE setIniPath NOTIFY iniPathChanged)
    Q_PROPERTY(QString host    READ host    WRITE setHost    NOTIFY hostChanged)
    Q_PROPERTY(quint16 port    READ port    WRITE setPort    NOTIFY portChanged)
    Q_PROPERTY(int     mode    READ mode    WRITE setMode    NOTIFY modeChanged) // 0=client, 1=server

public:
    explicit EncryptedMavlinkConfiguration(const QString &name, QObject *parent = nullptr);
    explicit EncryptedMavlinkConfiguration(const EncryptedMavlinkConfiguration *copy, QObject *parent = nullptr);

    LinkType type() const override { return LinkConfiguration::TypeTngEncryptedTest; }
    void copyFrom(const LinkConfiguration *source) override;
    void loadSettings(QSettings &settings, const QString &root) override;
    void saveSettings(QSettings &settings, const QString &root) const override;
    QString settingsURL() const override { return QStringLiteral("ServerSettings.qml"); }
    QString settingsTitle() const override { return tr("Server Link Settings"); }

    QString iniPath() const { return _iniPath; }
    void setIniPath(const QString &path);
    QString host() const { return _host; }
    void setHost(const QString &host);
    quint16 port() const { return _port; }
    void setPort(quint16 port);
    int mode() const { return _mode; }
    void setMode(int mode);

signals:
    void iniPathChanged();
    void hostChanged();
    void portChanged();
    void modeChanged();

private:
    QString _iniPath;                         // empty => QGC 설정 폴더(QSettings)/crypto.ini ([crypto] 전용)
    QString _host = QStringLiteral("127.0.0.1");
    quint16 _port = 10002;
    int     _mode = 0;                        // 0=client, 1=server
};

class EncryptedMavlinkLink : public LinkInterface
{
    Q_OBJECT

public:
    explicit EncryptedMavlinkLink(SharedLinkConfigurationPtr &config, QObject *parent = nullptr);
    ~EncryptedMavlinkLink() override;

    bool isConnected() const override;
    void disconnect() override;
    bool isSecureConnection() const override { return _secure; }

private slots:
    void _writeBytes(const QByteArray &bytes) override;
    void _onPipeConnected();
    void _onPipeDisconnected();
    void _onPlainReceived(const QByteArray &plain);
    void _onPipeSuspended(const QString &reason);

private:
    bool _connect() override;

    EncryptedMavlinkConfiguration *_cfg = nullptr;
    EncryptedTcpPipe _pipe;
    bool _connected = false;
    bool _secure = true; // crypto/enabled 반영
};
