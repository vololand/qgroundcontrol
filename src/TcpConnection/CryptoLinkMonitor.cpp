#include "CryptoLinkMonitor.h"

#include <QtCore/qapplicationstatic.h>
#include <QtCore/QDateTime>
#include <QtCore/QTimer>
#include <QtCore/QVariantMap>
#include <QtQml/qqml.h>

namespace {

QString levelText(int level)
{
    switch (level) {
    case CryptoLinkMonitor::Error:   return QObject::tr("오류");
    case CryptoLinkMonitor::Warning: return QObject::tr("경고");
    default:                         return QObject::tr("정보");
    }
}

} // namespace

Q_APPLICATION_STATIC(CryptoLinkMonitor, _cryptoLinkMonitorInstance)

CryptoLinkMonitor::CryptoLinkMonitor(QObject *parent)
    : QObject(parent)
{
}

CryptoLinkMonitor *CryptoLinkMonitor::instance()
{
    return _cryptoLinkMonitorInstance();
}

void CryptoLinkMonitor::registerQmlTypes()
{
    (void) qmlRegisterUncreatableType<CryptoLinkMonitor>(
        "QGroundControl", 1, 0, "CryptoLinkMonitor", "Reference only");
}

void CryptoLinkMonitor::_scheduleNotify()
{
    if (_notifyPending) {
        return;
    }
    _notifyPending = true;
    QTimer::singleShot(kNotifyDelayMs, this, &CryptoLinkMonitor::_notifyNow);
}

void CryptoLinkMonitor::_notifyNow()
{
    _notifyPending = false;
    emit entriesChanged();
    emit statsChanged();
}

void CryptoLinkMonitor::reportEvent(int level, const QString &source, const QString &message)
{
    if (message.isEmpty()) {
        return;
    }

    const int clamped = qBound(static_cast<int>(Info), level, static_cast<int>(Error));

    if (!_entries.isEmpty()) {
        QVariantMap head = _entries.first().toMap();
        if (head.value(QStringLiteral("level")).toInt() == clamped
            && head.value(QStringLiteral("source")).toString() == source
            && head.value(QStringLiteral("message")).toString() == message) {
            head[QStringLiteral("count")] = head.value(QStringLiteral("count")).toInt() + 1;
            head[QStringLiteral("time")]  = QDateTime::currentDateTime().toString(QStringLiteral("HH:mm:ss"));
            _entries[0] = head;
            _scheduleNotify();
            return;
        }
    }

    QVariantMap entry;
    entry[QStringLiteral("time")]      = QDateTime::currentDateTime().toString(QStringLiteral("HH:mm:ss"));
    entry[QStringLiteral("level")]     = clamped;
    entry[QStringLiteral("levelText")] = levelText(clamped);
    entry[QStringLiteral("source")]    = source;
    entry[QStringLiteral("message")]   = message;
    entry[QStringLiteral("count")]     = 1;

    _entries.prepend(entry);
    while (_entries.size() > kMaxEntries) {
        _entries.removeLast();
    }

    ++_unreadCount;
    if (clamped > _worstUnreadLevel) {
        _worstUnreadLevel = clamped;
    }

    _scheduleNotify();
}

void CryptoLinkMonitor::noteConnected(bool connected)
{
    if (_linkConnected == connected) {
        return;
    }
    _linkConnected = connected;
    _notifyNow();
}

void CryptoLinkMonitor::noteSuspended(bool suspended)
{
    if (_suspended == suspended) {
        return;
    }
    _suspended = suspended;
    _notifyNow();
}

void CryptoLinkMonitor::clear()
{
    _entries.clear();
    _unreadCount = 0;
    _worstUnreadLevel = -1;
    _notifyNow();
}

void CryptoLinkMonitor::markAllRead()
{
    if (_unreadCount == 0 && _worstUnreadLevel < 0) {
        return;
    }
    _unreadCount = 0;
    _worstUnreadLevel = -1;
    _notifyNow();
}

void CryptoLinkMonitor::requestResume()
{
    emit resumeRequested();
}
