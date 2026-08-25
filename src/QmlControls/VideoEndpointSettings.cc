/****************************************************************************
 *
 * CustomFlyView 드론/스테이션 영상 RTSP 설정 구현 (video_endpoints.ini).
 *
 ****************************************************************************/

#include "VideoEndpointSettings.h"

#include <QtCore/qapplicationstatic.h>
#include <QtCore/QCoreApplication>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QSettings>
#include <QtCore/QStringList>
#include <QtQml/qqml.h>

Q_APPLICATION_STATIC(VideoEndpointSettings, _videoEndpointSettingsInstance)

VideoEndpointSettings::VideoEndpointSettings(QObject *parent)
    : QObject(parent)
{
    reload();
}

VideoEndpointSettings *VideoEndpointSettings::instance()
{
    return _videoEndpointSettingsInstance();
}

void VideoEndpointSettings::registerQmlTypes()
{
    (void) qmlRegisterUncreatableType<VideoEndpointSettings>(
        "QGroundControl", 1, 0, "VideoEndpointSettings", "Reference only");
}

QString VideoEndpointSettings::_normalizeRtpTransport(const QString &transport)
{
    const QString normalized = transport.trimmed().toLower();
    if (normalized == QLatin1String("tcp") || normalized == QLatin1String("auto")) {
        return normalized;
    }
    return QStringLiteral("udp");
}

QString VideoEndpointSettings::_applyRtpTransport(const QString &urlIn, const QString &transportIn)
{
    const QString url = urlIn.trimmed();
    if (url.isEmpty()) {
        return QString();
    }
    if (!url.startsWith(QStringLiteral("rtsp://"), Qt::CaseInsensitive)) {
        return url; // udp:// 등은 그대로
    }
    if (url.contains(QStringLiteral("rtsp_transport="))) {
        return url; // 이미 지정됨
    }
    const QString transport = _normalizeRtpTransport(transportIn);
    if (transport == QLatin1String("auto")) {
        return url; // 옵션을 지정하지 않으면 GStreamer/FFmpeg가 UDP 우선 후 TCP를 협상한다.
    }
    const QChar sep = url.contains(QLatin1Char('?')) ? QLatin1Char('&') : QLatin1Char('?');
    return url + sep + QStringLiteral("rtsp_transport=") + transport;
}

void VideoEndpointSettings::setDroneRtpTransport(const QString &v)
{
    const QString transport = _normalizeRtpTransport(v);
    if (_droneRtpTransport != transport) {
        _droneRtpTransport = transport;
        emit changed();
    }
}

void VideoEndpointSettings::setStationRtpTransport(const QString &v)
{
    const QString transport = _normalizeRtpTransport(v);
    if (_stationRtpTransport != transport) {
        _stationRtpTransport = transport;
        emit changed();
    }
}

QString VideoEndpointSettings::resolveIniPath()
{
    // QGC 기본 설정 .ini(QSettings)와 같은 폴더 우선.
    const QString settingsDir = QFileInfo(QSettings().fileName()).absolutePath();
    const QString settingsPath = settingsDir + QStringLiteral("/video_endpoints.ini");
    if (QFile::exists(settingsPath)) {
        return settingsPath;
    }

    // 하위호환: 설정 폴더에 없으면 exe 폴더도 확인.
    const QString exePath = QCoreApplication::applicationDirPath() + QStringLiteral("/video_endpoints.ini");
    if (QFile::exists(exePath)) {
        return exePath;
    }

    // 둘 다 없으면 설정 폴더 경로(기본 생성 대상)를 반환.
    return settingsPath;
}

void VideoEndpointSettings::ensureCryptoSection(const QString &path)
{
    if (path.isEmpty()) {
        return;
    }

    QSettings s(path, QSettings::IniFormat);
    auto setIfMissing = [&s](const QString &key, const QVariant &value) {
        if (!s.contains(key)) {
            s.setValue(key, value);
        }
    };

    // crypto.ini [crypto] 의 세션 키 세트. 이미 있으면 덮어쓰지 않는다.
    // sys_unique/package_id/keystore_path/lib_dir 은 여기서 다루지 않는다.
    // tngcore 코어 identity 는 프로세스 전역이라 crypto.ini 값을 그대로 따른다.
    setIfMissing(QStringLiteral("crypto/enabled"), QStringLiteral("true"));
    setIfMissing(QStringLiteral("crypto/alg"), QStringLiteral("ARIA256"));
    setIfMissing(QStringLiteral("crypto/mode"), QStringLiteral("CTR"));
    setIfMissing(QStringLiteral("crypto/speed_mode"), QStringLiteral("normal"));
    setIfMissing(QStringLiteral("crypto/padding"), QStringLiteral("false"));
    setIfMissing(QStringLiteral("crypto/key_source"), QStringLiteral("hex"));
    setIfMissing(QStringLiteral("crypto/key_index"), 1);
    setIfMissing(QStringLiteral("crypto/key_hex"),
                 QStringLiteral("7D1B7A0110019712056CF18DCDF79E02118A26A8B6204444F68E246F8E1967A0"));
    setIfMissing(QStringLiteral("crypto/iv_hex"),
                 QStringLiteral("50121114F32EAA789608D779C331802E"));
    setIfMissing(QStringLiteral("crypto/fail_on_error"), QStringLiteral("true"));
    setIfMissing(QStringLiteral("crypto/max_payload_bytes"), 2048);
    setIfMissing(QStringLiteral("crypto/framing"), QStringLiteral("payload"));
    s.sync();
}

bool VideoEndpointSettings::_writeDefaultTemplate(const QString &path)
{
    const QFileInfo fi(path);
    QDir().mkpath(fi.absolutePath());

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        return false;
    }

    static const char kTemplate[] =
        "[General]\n"
        "drone_url = rtsp://127.0.0.1:8554/live\n"
        "drone_rtp_transport = udp\n"
        "\n"
        "station_url = rtsp://127.0.0.1:8554/live\n"
        "station_rtp_transport = udp\n"
        "\n"
        "[crypto]\n"
        "enabled = true\n"
        "alg = ARIA256\n"
        "mode = CTR\n"
        "; speed_mode: normal(tngDecSymm) | high(tngDecHs, CTR only)\n"
        "speed_mode = normal\n"
        "padding = false\n"
        "key_source = hex\n"
        "key_index = 1\n"
        "key_hex = 7D1B7A0110019712056CF18DCDF79E02118A26A8B6204444F68E246F8E1967A0\n"
        "iv_hex = 50121114F32EAA789608D779C331802E\n"
        "fail_on_error = true\n"
        "max_payload_bytes = 2048\n"
        "; framing: payload(RTP 페이로드만 암호, 제어 채널 평문)\n"
        ";        | rtsp(핸드셰이크부터 모든 PDU 가 [u32 BE 길이][암호문])\n"
        "framing = payload\n";

    file.write(kTemplate);
    file.close();
    return true;
}

void VideoEndpointSettings::reload()
{
    _iniPath = resolveIniPath();
    if (!QFile::exists(_iniPath)) {
        _writeDefaultTemplate(_iniPath);
    } else {
        ensureCryptoSection(_iniPath);
    }

    const QSettings s(_iniPath, QSettings::IniFormat);

    // QSettings는 INI의 [General]을 그룹 없는 최상위로 매핑하고, general 그룹은 [%General]에 쓴다.
    // 따라서 [general] 아래 키는 최상위 이름으로 읽어야 한다.
    // 과거 저장으로 [%General]이 만들어진 파일은 그 값이 사용자 입력이므로 먼저 흡수한다.
    const auto readKey = [&s](const QString &key, const QString &fallback) {
        return s.value(QStringLiteral("general/") + key, s.value(key, fallback)).toString();
    };

    _droneUrl = readKey(QStringLiteral("drone_url"), _droneUrl).trimmed();
    _stationUrl = readKey(QStringLiteral("station_url"), _stationUrl).trimmed();

    // 기존 *_transport 키를 하위 호환 폴백으로 읽고, 신규 *_rtp_transport를 우선한다.
    const QString legacyDroneTransport =
        readKey(QStringLiteral("drone_transport"), _droneRtpTransport);
    const QString legacyStationTransport =
        readKey(QStringLiteral("station_transport"), _stationRtpTransport);
    _droneRtpTransport = _normalizeRtpTransport(
        readKey(QStringLiteral("drone_rtp_transport"), legacyDroneTransport));
    _stationRtpTransport = _normalizeRtpTransport(
        readKey(QStringLiteral("station_rtp_transport"), legacyStationTransport));

    if (_droneUrl.isEmpty())   { _droneUrl = QStringLiteral("rtsp://127.0.0.1:8554/live"); }
    if (_stationUrl.isEmpty()) { _stationUrl = QStringLiteral("rtsp://127.0.0.1:8554/live"); }

    emit changed();
}

bool VideoEndpointSettings::save()
{
    if (_iniPath.isEmpty()) {
        _iniPath = resolveIniPath();
    }

    QSettings s(_iniPath, QSettings::IniFormat);
    if (s.status() != QSettings::NoError && !s.isWritable()) {
        return false;
    }

    // 최상위 키가 정본이다. 예약어 충돌로 [%General]에 갈라져 있던 general/* 는 제거해 중복을 없앤다.
    const auto writeKey = [&s](const QString &key, const QString &value) {
        s.setValue(key, value);
        s.remove(QStringLiteral("general/") + key);
    };

    writeKey(QStringLiteral("drone_url"), _droneUrl);
    writeKey(QStringLiteral("drone_rtp_transport"), _droneRtpTransport);
    writeKey(QStringLiteral("station_url"), _stationUrl);
    writeKey(QStringLiteral("station_rtp_transport"), _stationRtpTransport);

    // 구버전 채널 crypto 키는 재생에 쓰이지 않음. 남아 있으면 제거해 혼선을 막는다.
    const QStringList obsoleteKeys = {
        QStringLiteral("drone_crypto_enabled"),   QStringLiteral("drone_crypto_mode"),
        QStringLiteral("station_crypto_enabled"), QStringLiteral("station_crypto_mode")
    };
    for (const QString &key : obsoleteKeys) {
        s.remove(key);
        s.remove(QStringLiteral("general/") + key);
    }

    s.sync();
    if (s.status() != QSettings::NoError) {
        return false;
    }

    emit saved();
    return true;
}
