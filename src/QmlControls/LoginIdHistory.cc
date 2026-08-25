/****************************************************************************
 *
 * 마지막 로그인 아이디 1개만 보관 구현 (QGC 기본 .ini).
 *
 ****************************************************************************/

#include "LoginIdHistory.h"

#include <QtCore/qapplicationstatic.h>
#include <QtCore/QSettings>
#include <QtQml/qqml.h>

Q_APPLICATION_STATIC(LoginIdHistory, _loginIdHistoryInstance)

LoginIdHistory::LoginIdHistory(QObject *parent)
    : QObject(parent)
{
    reload();
}

LoginIdHistory *LoginIdHistory::instance()
{
    return _loginIdHistoryInstance();
}

void LoginIdHistory::registerQmlTypes()
{
    (void) qmlRegisterUncreatableType<LoginIdHistory>(
        "QGroundControl", 1, 0, "LoginIdHistory", "Reference only");
}

void LoginIdHistory::reload()
{
    QSettings settings;
    settings.beginGroup(QLatin1String(kGroup));

    QString loaded = settings.value(QLatin1String(kKeyLastUserId)).toString().trimmed();

    // 예전 recentIds(최대 5)가 있으면 첫 항목을 lastUserId로 이전 후 레거시 키 제거
    if (loaded.isEmpty() && settings.contains(QLatin1String(kKeyLegacyRecentIds))) {
        const QStringList legacy = settings.value(QLatin1String(kKeyLegacyRecentIds)).toStringList();
        for (const QString &raw : legacy) {
            const QString id = raw.trimmed();
            if (!id.isEmpty()) {
                loaded = id;
                break;
            }
        }
        settings.remove(QLatin1String(kKeyLegacyRecentIds));
        if (!loaded.isEmpty()) {
            settings.setValue(QLatin1String(kKeyLastUserId), loaded);
        }
    }

    settings.endGroup();

    if (_lastUserId != loaded) {
        _lastUserId = loaded;
        emit lastUserIdChanged();
    }
}

void LoginIdHistory::remember(const QString &userId)
{
    const QString id = userId.trimmed();
    if (id.isEmpty()) {
        return;
    }

    const bool changed = (id != _lastUserId);
    _lastUserId = id;
    _save();
    if (changed) {
        emit lastUserIdChanged();
    }
}

void LoginIdHistory::clear()
{
    if (_lastUserId.isEmpty()) {
        return;
    }
    _lastUserId.clear();
    _save();
    emit lastUserIdChanged();
}

void LoginIdHistory::_save()
{
    QSettings settings;
    settings.beginGroup(QLatin1String(kGroup));
    if (_lastUserId.isEmpty()) {
        settings.remove(QLatin1String(kKeyLastUserId));
    } else {
        settings.setValue(QLatin1String(kKeyLastUserId), _lastUserId);
    }
    settings.remove(QLatin1String(kKeyLegacyRecentIds));
    settings.endGroup();
    settings.sync();
}
