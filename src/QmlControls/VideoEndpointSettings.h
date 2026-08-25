/****************************************************************************
 *
 * CustomFlyView 드론/스테이션 영상 RTSP 설정 (video_endpoints.ini).
 * [general] = URL / RTP transport
 * [crypto]  = video 세션 키·알고리듬 (VideoCryptoSettings, MAVLink crypto.ini 와 분리)
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>

/// video_endpoints.ini 를 QML에 노출한다.
/// RTSP 제어는 TCP를 사용하고, resolved* 는 RTP 하위 전송(udp/tcp)을 URL 옵션으로 적용한다.
class VideoEndpointSettings : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString droneUrl          READ droneUrl          WRITE setDroneUrl          NOTIFY changed)
    Q_PROPERTY(QString droneRtpTransport READ droneRtpTransport WRITE setDroneRtpTransport NOTIFY changed)
    Q_PROPERTY(QString stationUrl        READ stationUrl        WRITE setStationUrl        NOTIFY changed)
    Q_PROPERTY(QString stationRtpTransport READ stationRtpTransport WRITE setStationRtpTransport NOTIFY changed)
    Q_PROPERTY(QString resolvedDroneUrl   READ resolvedDroneUrl   NOTIFY changed)
    Q_PROPERTY(QString resolvedStationUrl READ resolvedStationUrl NOTIFY changed)
    Q_PROPERTY(QString iniFilePath       READ iniFilePath       NOTIFY changed)

public:
    explicit VideoEndpointSettings(QObject *parent = nullptr);

    static VideoEndpointSettings *instance();
    static void registerQmlTypes();

    QString droneUrl()             const { return _droneUrl; }
    QString droneRtpTransport()    const { return _droneRtpTransport; }
    QString stationUrl()           const { return _stationUrl; }
    QString stationRtpTransport()  const { return _stationRtpTransport; }
    QString resolvedDroneUrl()     const { return _applyRtpTransport(_droneUrl, _droneRtpTransport); }
    QString resolvedStationUrl()   const { return _applyRtpTransport(_stationUrl, _stationRtpTransport); }
    QString iniFilePath()       const { return _iniPath; }

    void setDroneUrl(const QString &v)       { if (_droneUrl != v) { _droneUrl = v; emit changed(); } }
    void setDroneRtpTransport(const QString &v);
    void setStationUrl(const QString &v)     { if (_stationUrl != v) { _stationUrl = v; emit changed(); } }
    void setStationRtpTransport(const QString &v);

    /// 현재 활성 video_endpoints.ini에서 값을 다시 읽는다(없으면 기본 템플릿 생성 후 로드).
    Q_INVOKABLE void reload();

    /// 편집한 값을 video_endpoints.ini [general]에 기록한다. [crypto] 키는 보존한다.
    Q_INVOKABLE bool save();

    /// 활성 ini 경로를 해석한다(설정 폴더 → exe 폴더 → 설정 폴더 순).
    static QString resolveIniPath();

    /// [crypto] 필수 키가 없으면 기본값을 채워 넣는다(기존 [general] 보존).
    static void ensureCryptoSection(const QString &path);

signals:
    void changed();
    void saved();

private:
    /// rtsp:// URL이면 RTP 하위 전송을 적용한다. auto는 GStreamer/FFmpeg 기본 협상을 사용한다.
    static QString _applyRtpTransport(const QString &url, const QString &transport);
    static QString _normalizeRtpTransport(const QString &transport);
    static bool _writeDefaultTemplate(const QString &path);

    QString _iniPath;
    QString _droneUrl            = QStringLiteral("rtsp://127.0.0.1:8554/live");
    QString _droneRtpTransport   = QStringLiteral("udp");
    QString _stationUrl          = QStringLiteral("rtsp://127.0.0.1:8554/live");
    QString _stationRtpTransport = QStringLiteral("udp");
};
