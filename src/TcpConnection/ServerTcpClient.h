#ifndef TCPCLIENT_H
#define TCPCLIENT_H

#include <QObject>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTimer>

class TcpClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int status READ status NOTIFY statusChanged)
public:
    enum ConnectionStatus {
        Connected = 0,
        Connecting = 1,
        Disconnected = 2
    };

    enum class Mode {
        Client,
        Server
    };

    explicit TcpClient(QObject *parent = nullptr);
    int status() const { return m_status; }

    /// Client: connect to host:port. Server: bind host (0.0.0.0 가능) and listen port.
    void start(const QString &host, quint16 port, Mode mode = Mode::Client);
    void connectToServer(const QString &host, quint16 port); // client shortcut
    void disconnectFromServer();

    /// 현재 연결만 끊는다. disconnectFromServer()와 달리 서버 리스닝과 자동 재연결 설정을 유지하므로
    /// 상위에서 복구 가능한 오류로 판단했을 때 재시도 여지를 남길 수 있다.
    void dropActiveConnection();

    void sendData(const QByteArray &data);
    void setAutoReconnect(bool enabled); // client mode only
    void setReconnectIntervalMs(int ms); // client mode only

signals:
    void dataReceived(const QByteArray &data);
    void connectionStatusChanged(bool connected);
    void statusChanged();

private slots:
    void onReadyRead();
    void onConnected();
    void onDisconnected();
    void onErrorOccurred(QAbstractSocket::SocketError error);
    void onNewConnection();
    void checkConnection();

private:
    void setStatus(ConnectionStatus newStatus);
    void bindSocketSignals(QTcpSocket *socket);
    void resetActiveSocket();

    QTcpSocket *m_socket = nullptr;
    QTcpServer *m_server = nullptr;
    QTimer *reconnectTimer = nullptr;

    int m_status = Disconnected;
    Mode m_mode = Mode::Client;
    QString m_host = QStringLiteral("127.0.0.1");
    quint16 m_port = 1004;
    bool m_autoReconnect = true;
    int m_reconnectIntervalMs = 3000;
};

#endif
