import QtQuick 6.8
import QGroundControl
import QGroundControl.Toolbar

// 스테이션 비디오 타일. 공용 VideoTile에 스테이션 전용 값만 주입하는 얇은 래퍼.
// 공개 API(selectedStation 등 + VideoTile의 모든 프로퍼티/시그널)는 그대로 유지된다.
VideoTile {
    id: stationVideo

    /// [기존 API 유지] 스테이션 목록 선택값. 변경 시 세션 재연결.
    property string selectedStation: ""

    title: qsTr("스테이션 비디오")
    logTag: "StationVideo"
    selectionToken: selectedStation
    selectionLabel: selectedStation
    fallbackUrl: (typeof QGroundControl !== "undefined" && QGroundControl.videoEndpointSettings)
        ? QGroundControl.videoEndpointSettings.stationUrl
        : "rtsp://127.0.0.1:8554/live"
    rtpTransport: (typeof QGroundControl !== "undefined" && QGroundControl.videoEndpointSettings)
        ? QGroundControl.videoEndpointSettings.stationRtpTransport
        : "udp"
    cryptoEnabled: (typeof QGroundControl !== "undefined" && QGroundControl.videoCryptoSettings)
        ? QGroundControl.videoCryptoSettings.enabled
        : false
    cryptoMode: (typeof QGroundControl !== "undefined" && QGroundControl.videoCryptoSettings)
        ? QGroundControl.videoCryptoSettings.speedMode
        : "normal"
}
