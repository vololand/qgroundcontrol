/****************************************************************************
 *
 * 마지막 로그인 아이디 1개만 보관 (QGC 기본 .ini [LoginHistory]).
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>

class LoginIdHistory : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString lastUserId READ lastUserId NOTIFY lastUserIdChanged)

public:
    explicit LoginIdHistory(QObject *parent = nullptr);

    static LoginIdHistory *instance();
    static void registerQmlTypes();

    QString lastUserId() const { return _lastUserId; }

    /// QSettings에서 다시 읽는다.
    Q_INVOKABLE void reload();

    /// 로그인 성공 ID를 마지막 로그인으로 덮어쓴다. 빈 문자열/비밀번호는 저장하지 않는다.
    Q_INVOKABLE void remember(const QString &userId);

    /// 저장된 마지막 로그인 ID를 지운다.
    Q_INVOKABLE void clear();

signals:
    void lastUserIdChanged();

private:
    void _save();

    static constexpr char kGroup[] = "LoginHistory";
    static constexpr char kKeyLastUserId[] = "lastUserId";
    static constexpr char kKeyLegacyRecentIds[] = "recentIds"; // 이전 5개 목록 호환

    QString _lastUserId;
};
