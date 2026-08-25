#include "ServerTcpClient.h"

#include <QAbstractSocket>
#include <QHostAddress>

TcpClient::TcpClient(QObject *parent)
    : QObject(parent)
{
    reconnectTimer = new QTimer(this);
    connect(reconnectTimer, &QTimer::timeout, this, &TcpClient::checkConnection);
    reconnectTimer->start(m_reconnectIntervalMs);
}

void TcpClient::setAutoReconnect(bool enabled)
{
    m_autoReconnect = enabled;
    if (!enabled && reconnectTimer) {
        reconnectTimer->stop();
    } else if (enabled && reconnectTimer && !reconnectTimer->isActive()) {
        reconnectTimer->start(m_reconnectIntervalMs);
    }
}

void TcpClient::setReconnectIntervalMs(int ms)
{
    const int clamped = qBound(500, ms, 60000);
    if (m_reconnectIntervalMs == clamped) {
        return;
    }
    m_reconnectIntervalMs = clamped;
    if (reconnectTimer && reconnectTimer->isActive()) {
        reconnectTimer->start(m_reconnectIntervalMs);
    }
}

void TcpClient::setStatus(ConnectionStatus newStatus)
{
    if (m_status != newStatus) {
        m_status = newStatus;
        emit statusChanged();
    }
}

void TcpClient::bindSocketSignals(QTcpSocket *socket)
{
    if (!socket) {
        return;
    }
    connect(socket, &QTcpSocket::readyRead, this, &TcpClient::onReadyRead);
    connect(socket, &QTcpSocket::connected, this, &TcpClient::onConnected);
    connect(socket, &QTcpSocket::disconnected, this, &TcpClient::onDisconnected);
    connect(socket, &QAbstractSocket::errorOccurred, this, &TcpClient::onErrorOccurred);
}

void TcpClient::resetActiveSocket()
{
    if (!m_socket) {
        return;
    }
    // 시그널 재진입 방지: 핸들러 안에서 abort/delete 하지 않도록 먼저 분리
    m_socket->disconnect(this);
    if (m_socket->state() != QAbstractSocket::UnconnectedState) {
        m_socket->abort();
    }
    m_socket->deleteLater();
    m_socket = nullptr;
}

void TcpClient::start(const QString &host, quint16 port, Mode mode)
{
    m_host = host;
    m_port = port;
    m_mode = mode;

    disconnectFromServer();

    if (m_mode == Mode::Server) {
        setAutoReconnect(false);
        if (!m_server) {
            m_server = new QTcpServer(this);
            connect(m_server, &QTcpServer::newConnection, this, &TcpClient::onNewConnection);
        }

        const QHostAddress addr = (host.isEmpty() || host == QLatin1String("0.0.0.0"))
                                      ? QHostAddress::Any
                                      : QHostAddress(host);

        setStatus(Connecting);
        if (!m_server->listen(addr, port)) {
            setStatus(Disconnected);
            return;
        }
        setStatus(Disconnected);
        return;
    }

    setAutoReconnect(true);
    if (m_server) {
        m_server->close();
    }

    m_socket = new QTcpSocket(this);
    bindSocketSignals(m_socket);

    setStatus(Connecting);
    m_socket->connectToHost(host, port);
    if (m_socket->waitForConnected(3000)) {
        setStatus(Connected);
    } else {
        setStatus(Disconnected);
    }
}

void TcpClient::connectToServer(const QString &host, quint16 port)
{
    start(host, port, Mode::Client);
}

void TcpClient::onNewConnection()
{
    if (!m_server) {
        return;
    }

    QTcpSocket *incoming = m_server->nextPendingConnection();
    if (!incoming) {
        return;
    }

    resetActiveSocket();
    m_socket = incoming;
    m_socket->setParent(this);
    bindSocketSignals(m_socket);

    setStatus(Connected);
    emit connectionStatusChanged(true);
}

void TcpClient::onConnected()
{
    emit connectionStatusChanged(true);
    setStatus(Connected);
}

void TcpClient::onDisconnected()
{
    setStatus(Disconnected);
    // 소켓 핸들러 스택 위에서 링크 파괴가 일어나지 않도록 상태만 알림
    emit connectionStatusChanged(false);

    if (m_mode == Mode::Server && m_socket) {
        m_socket->disconnect(this);
        m_socket->deleteLater();
        m_socket = nullptr;
    }
}

void TcpClient::onErrorOccurred(QAbstractSocket::SocketError error)
{
    Q_UNUSED(error);
    if (m_mode == Mode::Client) {
        setStatus(Disconnected);
    }
}

void TcpClient::disconnectFromServer()
{
    setAutoReconnect(false);
    if (m_server && m_server->isListening()) {
        m_server->close();
    }
    resetActiveSocket();
    setStatus(Disconnected);
}

void TcpClient::dropActiveConnection()
{
    if (!m_socket) {
        return;
    }
    // resetActiveSocket()이 시그널을 먼저 끊으므로 onDisconnected()가 오지 않는다. 상태만 직접 알린다.
    resetActiveSocket();
    setStatus(Disconnected);
    emit connectionStatusChanged(false);
}

void TcpClient::onReadyRead()
{
    if (!m_socket) {
        return;
    }
    const QByteArray chunk = m_socket->readAll();
    if (!chunk.isEmpty()) {
        emit dataReceived(chunk);
    }
}

void TcpClient::sendData(const QByteArray &data)
{
    if (!m_socket || m_socket->state() != QAbstractSocket::ConnectedState) {
        return;
    }
    if (data.isEmpty()) {
        return;
    }
    m_socket->write(data);
    m_socket->flush();
}

void TcpClient::checkConnection()
{
    if (m_mode != Mode::Client || !m_autoReconnect) {
        return;
    }
    if (!m_socket) {
        m_socket = new QTcpSocket(this);
        bindSocketSignals(m_socket);
    }
    if (m_socket->state() == QAbstractSocket::UnconnectedState) {
        m_socket->connectToHost(m_host, m_port);
    }
}
