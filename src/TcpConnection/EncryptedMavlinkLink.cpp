#include "EncryptedMavlinkLink.h"
#include "TngCryptoConfig.h"

EncryptedMavlinkConfiguration::EncryptedMavlinkConfiguration(const QString &name, QObject *parent)
    : LinkConfiguration(name, parent)
{
}

EncryptedMavlinkConfiguration::EncryptedMavlinkConfiguration(const EncryptedMavlinkConfiguration *copy, QObject *parent)
    : LinkConfiguration(copy, parent)
    , _iniPath(copy->_iniPath)
    , _host(copy->_host)
    , _port(copy->_port)
    , _mode(copy->_mode)
{
}

void EncryptedMavlinkConfiguration::copyFrom(const LinkConfiguration *source)
{
    LinkConfiguration::copyFrom(source);
    const auto *src = qobject_cast<const EncryptedMavlinkConfiguration *>(source);
    if (!src) {
        return;
    }
    setIniPath(src->_iniPath);
    setHost(src->_host);
    setPort(src->_port);
    setMode(src->_mode);
}

void EncryptedMavlinkConfiguration::loadSettings(QSettings &settings, const QString &root)
{
    setIniPath(settings.value(root + "/iniPath", _iniPath).toString());
    setHost(settings.value(root + "/host", _host).toString());
    setPort(static_cast<quint16>(settings.value(root + "/port", _port).toUInt()));
    setMode(settings.value(root + "/mode", _mode).toInt());
}

void EncryptedMavlinkConfiguration::saveSettings(QSettings &settings, const QString &root) const
{
    settings.setValue(root + "/iniPath", _iniPath);
    settings.setValue(root + "/host", _host);
    settings.setValue(root + "/port", _port);
    settings.setValue(root + "/mode", _mode);
}

void EncryptedMavlinkConfiguration::setIniPath(const QString &path)
{
    if (_iniPath == path) {
        return;
    }
    _iniPath = path;
    emit iniPathChanged();
}

void EncryptedMavlinkConfiguration::setHost(const QString &host)
{
    if (_host == host) {
        return;
    }
    _host = host;
    emit hostChanged();
}

void EncryptedMavlinkConfiguration::setPort(quint16 port)
{
    if (_port == port) {
        return;
    }
    _port = port;
    emit portChanged();
}

void EncryptedMavlinkConfiguration::setMode(int mode)
{
    const int clamped = (mode == 1) ? 1 : 0;
    if (_mode == clamped) {
        return;
    }
    _mode = clamped;
    emit modeChanged();
}

/*===========================================================================*/

EncryptedMavlinkLink::EncryptedMavlinkLink(SharedLinkConfigurationPtr &config, QObject *parent)
    : LinkInterface(config, parent)
    , _cfg(qobject_cast<EncryptedMavlinkConfiguration *>(config.get()))
{
    connect(&_pipe, &EncryptedTcpPipe::connected, this, &EncryptedMavlinkLink::_onPipeConnected);
    connect(&_pipe, &EncryptedTcpPipe::disconnected, this, &EncryptedMavlinkLink::_onPipeDisconnected);
    connect(&_pipe, &EncryptedTcpPipe::plainReceived, this, &EncryptedMavlinkLink::_onPlainReceived);
    connect(&_pipe, &EncryptedTcpPipe::suspended, this, &EncryptedMavlinkLink::_onPipeSuspended);
}

EncryptedMavlinkLink::~EncryptedMavlinkLink()
{
    _connected = false;
    _pipe.stop();
}

bool EncryptedMavlinkLink::isConnected() const
{
    return _connected;
}

bool EncryptedMavlinkLink::_connect()
{
    TngCryptoConfig cryptoCfg;
    QString err;
    const QString iniPath = _cfg ? _cfg->iniPath() : QString();
    if (!TngCryptoConfig::load(iniPath, cryptoCfg, &err)) {
        emit communicationError(tr("Vololand"), err);
        return false;
    }

    if (_cfg) {
        cryptoCfg.host = _cfg->host();
        cryptoCfg.port = _cfg->port();
        cryptoCfg.tcpMode = (_cfg->mode() == 1) ? TngCryptoConfig::TcpMode::Server
                                                : TngCryptoConfig::TcpMode::Client;
    }
    _secure = cryptoCfg.enabled;

    if (!_pipe.start(cryptoCfg, &err)) {
        emit communicationError(tr("Vololand"), err);
        return false;
    }

    if (_pipe.isConnected()) {
        _onPipeConnected();
    }
    return true;
}

void EncryptedMavlinkLink::disconnect()
{
    _connected = false;
    _pipe.stop();
    emit disconnected();
}

void EncryptedMavlinkLink::_writeBytes(const QByteArray &bytes)
{
    _pipe.sendPlain(bytes);
    emit bytesSent(this, bytes);
}

void EncryptedMavlinkLink::_onPipeDisconnected()
{
    if (!_connected) {
        return;
    }
    _connected = false;
}

void EncryptedMavlinkLink::_onPipeConnected()
{
    if (_connected) {
        return;
    }
    _connected = true;
    emit connected();
}

void EncryptedMavlinkLink::_onPlainReceived(const QByteArray &plain)
{
    emit bytesReceived(this, plain);
}

void EncryptedMavlinkLink::_onPipeSuspended(const QString &reason)
{
    emit communicationError(tr("Vololand"), reason);
}
