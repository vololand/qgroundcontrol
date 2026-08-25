#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QVariantList>

class CryptoLinkMonitor : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList entries          READ entries          NOTIFY entriesChanged)
    Q_PROPERTY(int          unreadCount      READ unreadCount      NOTIFY entriesChanged)
    Q_PROPERTY(int          worstUnreadLevel READ worstUnreadLevel NOTIFY entriesChanged)
    Q_PROPERTY(bool         suspended        READ suspended        NOTIFY statsChanged)
    Q_PROPERTY(bool         linkConnected    READ linkConnected    NOTIFY statsChanged)

public:
    enum Level {
        Info    = 0,
        Warning = 1,
        Error   = 2
    };
    Q_ENUM(Level)

    explicit CryptoLinkMonitor(QObject *parent = nullptr);

    static CryptoLinkMonitor *instance();
    static void registerQmlTypes();

    QVariantList entries()      const { return _entries; }
    int          unreadCount()  const { return _unreadCount; }
    int          worstUnreadLevel() const { return _worstUnreadLevel; }
    bool         suspended()    const { return _suspended; }
    bool         linkConnected()const { return _linkConnected; }

    Q_INVOKABLE void clear();
    Q_INVOKABLE void markAllRead();

    Q_INVOKABLE void requestResume();

public slots:
    void reportEvent(int level, const QString &source, const QString &message);
    void noteConnected(bool connected);
    void noteSuspended(bool suspended);

signals:
    void entriesChanged();
    void statsChanged();
    void resumeRequested();

private:
    void _scheduleNotify();
    void _notifyNow();

    static constexpr int kMaxEntries  = 200;
    static constexpr int kNotifyDelayMs = 400;

    QVariantList _entries;
    int  _unreadCount      = 0;
    int  _worstUnreadLevel = -1;
    bool _suspended        = false;
    bool _linkConnected    = false;
    bool _notifyPending    = false;
};
