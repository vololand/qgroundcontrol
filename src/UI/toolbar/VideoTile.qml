import QtQuick 6.8
import QGroundControl
import QGroundControl.ScreenTools
import QtQuick.Controls 6.8
import QtMultimedia 6.8
import QGroundControl.Controls
import org.freedesktop.gstreamer.Qt6GLVideoItem

// 드론/스테이션/MultiView 공용 비디오 타일.
// RTSP 수신(GStreamer: CustomRtspReceiver, 비-GStreamer: Qt MediaPlayer) + 표시 + 연결상태 + 오버레이 컨트롤.
// 소스 종류별 차이는 프로퍼티로만 주입한다(별도 컴포넌트를 만들지 않는다).
Rectangle {
    id: videoRoot
    implicitHeight: width * 0.5625
    color: "#1a1a1a"
    border.color: "#333"
    radius: 4

    // [공통 프로퍼티]
    property var backend: null
    property bool mapOverlayMode: false
    property bool mapToggleEnabled: true
    property bool showExpandButton: true
    /// 짐벌/하단 버튼바 등 오버레이 컨트롤 표시 여부. MultiView 그리드 셀 등은 false(영상만).
    property bool showControls: true
    /// true면 확대창 패스스루의 소스로 등록(메인 한 개만).
    property bool isMainVideo: false
    property bool placeholderBlackMode: false
    property bool streamEnabled: true
    /// 채널 단위 재생: 비어 있지 않으면 이 URL 사용(설정/backend 대신).
    property string channelUrl: ""
    /// 채널 표시 이름(연결 중 문구 등). 비어 있으면 selectionLabel 또는 "카메라" 사용.
    property string channelLabel: ""

    // [소스 종류 주입용 프로퍼티]
    /// 팝업 타이틀바 제목(예: "드론 비디오", "스테이션 비디오").
    property string title: qsTr("비디오")
    /// 로그 접두사(예: "DroneVideo").
    property string logTag: "VideoTile"
    /// 목록 선택 식별자. 값이 바뀌면(같은 URL이어도) 세션을 새로 연다.
    property string selectionToken: ""
    /// 연결 중 문구 폴백 이름(channelLabel이 비었을 때 사용).
    property string selectionLabel: ""
    /// channelUrl이 비었을 때 사용할 폴백 RTSP URL(드론/스테이션 각 설정값 주입).
    property string fallbackUrl: "rtsp://127.0.0.1:8554/live"
    /// RTSP가 전달하는 RTP의 하위 전송. udp(default) | tcp(interleaved) | auto.
    property string rtpTransport: "udp"
    /// 서버/API RTSP 전체 세션 암호화 여부. AppSettings > Video Crypto([crypto].enabled) SSoT.
    /// 로컬기기(useVideoManager)에는 적용하지 않는다.
    property bool cryptoEnabled: false
    /// tngCore 복호 모드. normal(tngDecSymm) | high(tngDecHs). Video Crypto speed_mode SSoT.
    property string cryptoMode: "normal"

    /// 로컬 기기(origin=local): true면 자체 RTSP 수신 대신 QGC가 관리하는 공유 videoContent 서피스를 이 타일에 붙인다.
    /// (부모가 attach/detach 처리. QGC 비디오 설정이 꺼져 있으면 디코딩이 없어 표시되지 않음. 연결 1대 전제.)
    property bool useVideoManager: false

    signal toggleMapVideoRequested()
    /// 로컬 모드 진입/이탈 시 부모(CustomFlyView)에게 공유 videoContent 서피스 붙임/반납을 요청.
    signal requestAttachSharedVideo(var host)
    signal requestDetachSharedVideo(var host)
    signal requestPopupMinimize()
    signal requestPopupToggleMaximize()
    signal requestPopupClose()

    readonly property color _controlBaseColor: "#66000000"
    readonly property color _controlHoverColor: "#88353535"
    readonly property color _controlPressedColor: "#AA2C7BE5"
    readonly property color _controlBorderColor: "#99ffffff"
    readonly property real _directionButtonSize: 32
    readonly property int _bottomButtonCount: 6  // 확대(⤢) 제외
    readonly property real _bottomButtonSpacing: 6
    readonly property real _bottomBarHeight: 36
    readonly property real _bottomBarMargin: 6
    readonly property real _topOverlayMargin: 8
    readonly property real _popupTitleBarHeight: 32
    readonly property real _topOverlayHeight: mapOverlayMode ? 20 : (connectingStatusText.implicitHeight > 0 ? connectingStatusText.implicitHeight : 20)

    // 레이아웃: 하단 버튼바 높이만큼 비디오 하단 여백
    readonly property real _topReservedHeight: {
        if (placeholderBlackMode) return 0
        if (mapOverlayMode) return _popupTitleBarHeight
        return (connectingStatusText.visible && connectingStatusText.text !== "") ? (connectingStatusText.y + connectingStatusText.height) : 0
    }

    readonly property real _bottomButtonSize: Math.min(28, Math.max(22, (_bottomBarHeight - _bottomBarMargin * 2)))

    // 폴백 소스: backend가 주면 그것, 없으면 주입된 fallbackUrl(드론/스테이션 설정), 최종 하드코딩.
    readonly property string rtspSource: (backend && backend.rtspUrl)
        ? backend.rtspUrl
        : (fallbackUrl && String(fallbackUrl).trim() !== "" ? String(fallbackUrl).trim() : "rtsp://127.0.0.1:8554/live")
    /// 채널 URL이 있으면 우선 사용, 없으면 rtspSource(설정/backend)
    readonly property string _channelOrDefaultUrl: (typeof channelUrl !== "undefined" && channelUrl && String(channelUrl).trim() !== "")
        ? String(channelUrl).trim()
        : rtspSource
    /// URL에 박힌 rtsp_transport를 제거한다. 타일 rtpTransport가 SSoT가 되도록 한다.
    function _stripRtpTransport(url) {
        var source = String(url || "").trim()
        if (source.indexOf("rtsp_transport=") < 0)
            return source
        source = source.replace(/([?&])rtsp_transport=[^&]*/gi, function(match, sep) {
            return sep === "?" ? "?" : ""
        })
        source = source.replace(/\?&/g, "?").replace(/&&/g, "&").replace(/[?&]$/g, "")
        return source
    }

    /// 타일 rtpTransport로 전송 옵션을 적용한다(기존 쿼리 값도 덮어씀).
    function _withRtpTransport(url, transport) {
        var source = _stripRtpTransport(url)
        if (source.indexOf("rtsp://") !== 0)
            return String(url || "").trim()

        var mode = String(transport || "udp").trim().toLowerCase()
        if (mode === "auto")
            return source
        if (mode !== "tcp")
            mode = "udp"
        return source + (source.indexOf("?") >= 0 ? "&" : "?") + "rtsp_transport=" + mode
    }

    /// 직접 URL의 rtsp_transport가 최우선이며, 없으면 타일의 RTP 전송 설정을 적용한다.
    readonly property string _effectiveRtspSource: (_channelOrDefaultUrl === "")
        ? ""
        : _withRtpTransport(_channelOrDefaultUrl, rtpTransport)
    /// 재연결 시 백엔드가 새 RTSP 세션을 열도록, 재생에 사용하는 소스(리셋 가능)
    property string _playbackSource: ""
    /// GStreamer 리시버 재로드 펄스. selectionToken 변경 시 false→true로 토글해 세션을 새로 연다.
    property bool _gstReloadPulse: true
    /// GStreamer 빌드에서 CustomRtspReceiver 사용(독립 파이프라인). VideoManager 미사용.
    readonly property bool useGStreamer: (typeof QGroundControl !== "undefined" && QGroundControl.videoManager && QGroundControl.videoManager.gstreamerEnabled && typeof CustomRtspReceiver !== "undefined")

    function _logVideo(msg) {
        var full = "[" + logTag + "] " + msg
        if (typeof debugMessageModel !== "undefined" && debugMessageModel) {
            debugMessageModel.log(full)
            debugMessageModel.logToConsole(full)
        }
        console.warn("[" + logTag + "]", msg)
    }

    function _teardownSession() {
        mediaPlayer.stop()
        _playbackSource = ""
    }

    function _mediaStatusString(s) {
        if (s === MediaPlayer.NoMedia) return "NoMedia"
        if (s === MediaPlayer.Loading) return "Loading"
        if (s === MediaPlayer.Loaded) return "Loaded"
        if (s === MediaPlayer.Stalled) return "Stalled"
        if (s === MediaPlayer.Buffering) return "Buffering"
        if (s === MediaPlayer.BufferedMedia) return "BufferedMedia"
        if (s === MediaPlayer.EndOfMedia) return "EndOfMedia"
        if (s === MediaPlayer.InvalidMedia) return "InvalidMedia"
        return "status=" + s
    }

    function _applySourceAndPlay() {
        if (videoRoot.useGStreamer) return
        if (videoRoot.cryptoEnabled) {
            _logVideo("encrypted RTSP requires GStreamer (in-process decrypt)")
            _playbackSource = ""
            return
        }
        if (!streamEnabled || !_channelOrDefaultUrl) {
            _playbackSource = ""
            return
        }
        _logVideo("play source: " + _effectiveRtspSource + " [transport=" + (_effectiveRtspSource.indexOf("rtsp_transport=tcp") >= 0 ? "tcp" : _effectiveRtspSource.indexOf("rtsp_transport=udp") >= 0 ? "udp" : "url-default") + "]")
        var connectingOrActive = (mediaPlayer.mediaStatus !== MediaPlayer.NoMedia &&
                                  mediaPlayer.mediaStatus !== MediaPlayer.InvalidMedia)
        if (connectingOrActive) {
            _teardownSession()
            _playbackSource = ""
            sourceResetRestartTimer.start()
            return
        }
        _playbackSource = _effectiveRtspSource
        mediaPlayer.play()
    }

    // GStreamer 경로에서는 소스/전송/암호 값이 CustomRtspReceiver 프로퍼티로 바로 전달되고
    // 각 setter가 세션을 다시 연다. Loader를 내렸다 올리면 재생성 비용만 늘어난다.
    onRtspSourceChanged: if (!videoRoot.useVideoManager && !videoRoot.useGStreamer) Qt.callLater(_applySourceAndPlay)
    onChannelUrlChanged: if (!videoRoot.useVideoManager && !videoRoot.useGStreamer) Qt.callLater(_applySourceAndPlay)
    onRtpTransportChanged: if (!videoRoot.useVideoManager && !videoRoot.useGStreamer) Qt.callLater(_applySourceAndPlay)
    onCryptoEnabledChanged: if (!videoRoot.useVideoManager && !videoRoot.useGStreamer) Qt.callLater(_applySourceAndPlay)
    onCryptoModeChanged: if (!videoRoot.useVideoManager && !videoRoot.useGStreamer) Qt.callLater(_applySourceAndPlay)

    // Video Crypto([crypto]) 저장 시 재연결해 enabled/키/알고리듬/속도를 반영한다.
    Connections {
        target: (typeof QGroundControl !== "undefined") ? QGroundControl.videoCryptoSettings : null
        enabled: !videoRoot.useVideoManager
        function onSaved() { videoRoot._restartForSelectionChange() }
    }
    onStreamEnabledChanged: {
        if (videoRoot.useVideoManager)
            return
        if (streamEnabled)
            Qt.callLater(_applySourceAndPlay)
        else
            _teardownSession()
    }
    onUseVideoManagerChanged: _updateSharedVideoBinding()
    // 원칙: 목록 선택이 바뀔 때마다 세션을 새로 연다(같은 URL이어도 재연결).
    onSelectionTokenChanged: _restartForSelectionChange()

    /// 로컬 모드 진입/이탈에 따라 공유 videoContent 서피스 붙임/반납을 부모에 요청한다.
    function _updateSharedVideoBinding() {
        if (videoRoot.useVideoManager) {
            // 로컬로 전환: 자체 RTSP 세션은 정리하고 공유 서피스를 요청.
            _teardownSession()
            videoRoot.requestAttachSharedVideo(sharedVideoArea)
        } else {
            videoRoot.requestDetachSharedVideo(sharedVideoArea)
        }
    }

    function _restartForSelectionChange() {
        if (videoRoot.useVideoManager) {
            // 로컬 모드: 연결된 기체 영상은 QGC videoContent가 렌더. 붙임 상태만 보장.
            _updateSharedVideoBinding()
            return
        }
        if (videoRoot.useGStreamer) {
            // Loader.active를 한 틱 내렸다 올려 CustomRtspReceiver를 재생성(파괴자에서 _stop).
            videoRoot._gstReloadPulse = false
            gstReloadTimer.restart()
        } else {
            _teardownSession()
            if (streamEnabled && _channelOrDefaultUrl)
                Qt.callLater(_applySourceAndPlay)
        }
    }

    /// 현재 디코딩 서피스를 확대창 host로 이동한다. 수신기/디코더는 재생성하지 않는다.
    function attachVideoSurface(host) {
        if (!host || videoSurface.parent === host)
            return
        videoSurface.anchors.fill = undefined
        videoSurface.parent = host
        videoSurface.anchors.fill = host
        videoRoot._videoSurfaceExpanded = true
    }

    /// 확대창에 이동한 디코딩 서피스를 원래 타일로 복귀시킨다.
    function restoreVideoSurface() {
        if (videoSurface.parent === videoSurfaceHome)
            return
        videoSurface.anchors.fill = undefined
        videoSurface.parent = videoSurfaceHome
        videoSurface.anchors.fill = videoSurfaceHome
        videoRoot._videoSurfaceExpanded = false
    }

    property bool _videoSurfaceExpanded: false

    Item {
        id: videoSurfaceHome
        anchors.fill: parent
        z: 0
    }

    Item {
        id: videoSurface
        parent: videoSurfaceHome
        anchors.fill: videoSurfaceHome
        z: 0

        // 로컬(QGC 연결) 기기: QGC가 관리하는 공유 videoContent 서피스가 여기로 reparent 되어 렌더.
        Item {
            id: sharedVideoArea
            anchors.fill: parent
            anchors.leftMargin: videoRoot._videoSurfaceExpanded ? 0 : 1
            anchors.rightMargin: videoRoot._videoSurfaceExpanded ? 0 : 1
            anchors.topMargin: videoRoot._videoSurfaceExpanded ? 0 : 1
            anchors.bottomMargin: videoRoot._videoSurfaceExpanded ? 0 : (videoRoot.placeholderBlackMode ? 2 : (videoRoot.showControls ? videoRoot._bottomBarHeight : 1))
            visible: !videoRoot.placeholderBlackMode && videoRoot.useVideoManager
            z: 0
        }

        // GStreamer 출력 (CustomRtspReceiver — 서버/API RTSP)
        Item {
            id: gstVideoArea
            anchors.fill: parent
            anchors.leftMargin: videoRoot._videoSurfaceExpanded ? 0 : 1
            anchors.rightMargin: videoRoot._videoSurfaceExpanded ? 0 : 1
            anchors.topMargin: videoRoot._videoSurfaceExpanded ? 0 : 1
            anchors.bottomMargin: videoRoot._videoSurfaceExpanded ? 0 : (videoRoot.placeholderBlackMode ? 2 : (videoRoot.showControls ? videoRoot._bottomBarHeight : 1))
            visible: !videoRoot.placeholderBlackMode && videoRoot.useGStreamer && !videoRoot.useVideoManager
            z: 0
            GstGLQt6VideoItem {
                id: gstVideoItem
                anchors.fill: parent
                forceAspectRatio: false
            }
            Loader {
                id: gstReceiverLoader
                // 미선택(streamEnabled=false)이면 리시버 자체를 내려 세션 종료. 재로드 펄스로 선택 변경 시 재생성.
                // useVideoManager(로컬 기기) 모드에서는 CustomRtspReceiver를 만들지 않는다(VideoManager가 렌더).
                active: videoRoot.useGStreamer && !videoRoot.useVideoManager && videoRoot.streamEnabled && videoRoot._effectiveRtspSource !== "" && videoRoot._gstReloadPulse
                anchors.fill: parent
                sourceComponent: Component {
                    CustomRtspReceiver {
                        channelUrl: videoRoot._effectiveRtspSource
                        videoOutput: gstVideoItem
                        streamEnabled: videoRoot.streamEnabled
                        cryptoEnabled: videoRoot.cryptoEnabled
                        cryptoMode: videoRoot.cryptoMode
                    }
                }
            }
        }

        VideoOutput {
            id: videoOutput
            anchors.fill: parent
            anchors.leftMargin: videoRoot._videoSurfaceExpanded ? 0 : 1
            anchors.rightMargin: videoRoot._videoSurfaceExpanded ? 0 : 1
            anchors.topMargin: videoRoot._videoSurfaceExpanded ? 0 : 1
            anchors.bottomMargin: videoRoot._videoSurfaceExpanded ? 0 : (videoRoot.placeholderBlackMode ? 2 : videoRoot._bottomBarHeight)
            fillMode: VideoOutput.PreserveAspectCrop
            visible: !videoRoot.placeholderBlackMode && !videoRoot.useGStreamer

            Rectangle {
                anchors.fill: parent
                color: "black"
                visible: mediaPlayer.mediaStatus < MediaPlayer.BufferedMedia
                z: 1
            }
        }
    }

    Item {
        id: cameraControls
        anchors.fill: parent
        anchors.leftMargin: 1
        anchors.rightMargin: 1
        anchors.topMargin: 1
        anchors.bottomMargin: videoRoot.placeholderBlackMode ? 2 : videoRoot._bottomBarHeight
        z: 20
        visible: !videoRoot.placeholderBlackMode && videoRoot.showControls

        Item {
            id: gimbalPad
            anchors.fill: parent
            Repeater {
                model: [
                    { t: "▲", edge: "top" },
                    { t: "◀", edge: "left" },
                    { t: "▶", edge: "right" },
                    { t: "▼", edge: "bottom" }
                ]
                RoundButton {
                    width: videoRoot._directionButtonSize
                    height: videoRoot._directionButtonSize
                    text: modelData.t
                    anchors.horizontalCenter: (modelData.edge === "top" || modelData.edge === "bottom") ? parent.horizontalCenter : undefined
                    anchors.verticalCenter: (modelData.edge === "left" || modelData.edge === "right") ? parent.verticalCenter : undefined
                    anchors.left: modelData.edge === "left" ? parent.left : undefined
                    anchors.right: modelData.edge === "right" ? parent.right : undefined
                    anchors.top: modelData.edge === "top" ? parent.top : undefined
                    anchors.bottom: modelData.edge === "bottom" ? parent.bottom : undefined
                    anchors.leftMargin: modelData.edge === "left" ? 1 : 0
                    anchors.rightMargin: modelData.edge === "right" ? 1 : 0
                    anchors.topMargin: modelData.edge === "top" ? 1 : 0
                    anchors.bottomMargin: modelData.edge === "bottom" ? 1 : 0
                    background: Item {}
                    contentItem: Text {
                        text: parent.text
                        anchors.centerIn: parent
                        color: parent.pressed ? "#cccccc" : "white"
                        font.pixelSize: 14
                    }
                    scale: pressed ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90 } }
                }
            }
        }
    }

    // 하단 버튼바 (확대 버튼 제외, 가로 정렬)
    Row {
        id: bottomButtonBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: videoRoot._bottomBarMargin
        spacing: videoRoot._bottomButtonSpacing
        layoutDirection: Qt.LeftToRight
        visible: !videoRoot.placeholderBlackMode && videoRoot.showControls
        z: 30

        Repeater {
            model: [
                { icon: "qrc:/qmlimages/crossHair.svg", action: null },
                { icon: "qrc:/qmlimages/ZoomMinus.svg", action: null },
                { icon: "qrc:/qmlimages/camera_video.svg", action: null },
                { icon: "qrc:/qmlimages/camera_photo.svg", action: null },
                { icon: "qrc:/qmlimages/PaperPlane.svg", action: null },
                { icon: "qrc:/qmlimages/Gears.svg", action: () => streamingSettingsPopup.open() }
            ]
            RoundButton {
                width: videoRoot._bottomButtonSize
                height: videoRoot._bottomButtonSize
                icon.source: modelData.icon
                icon.color: "white"
                icon.width: width * 0.58
                icon.height: height * 0.58
                display: AbstractButton.IconOnly
                onClicked: if (modelData.action) modelData.action()
                background: Rectangle {
                    radius: width / 2
                    color: parent.pressed ? videoRoot._controlPressedColor : (parent.hovered ? videoRoot._controlHoverColor : videoRoot._controlBaseColor)
                    border.color: videoRoot._controlBorderColor
                    border.width: 1
                }
            }
        }
    }

    Popup {
        id: streamingSettingsPopup
        // 패널 타일 높이보다 팝업이 커서 아래로 잘리므로 Overlay에 올려 기어 버튼 위로 배치한다.
        parent: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: 220
        padding: 10
        z: 10000
        background: Rectangle {
            radius: 8
            color: "#CC202020"
            border.width: 1
            border.color: "#66ffffff"
        }

        function _reposition() {
            if (!Overlay.overlay || !bottomButtonBar)
                return
            var margin = 8
            // 하단바 우측(기어) 기준으로 팝업을 위쪽에 붙인다.
            var anchor = bottomButtonBar.mapToItem(Overlay.overlay, bottomButtonBar.width, 0)
            x = Math.max(margin, Math.min(anchor.x - width, Overlay.overlay.width - width - margin))
            var above = anchor.y - height - margin
            if (above >= margin) {
                y = above
            } else {
                // 위 공간 부족 시 버튼바 아래로, 화면 안으로만 클램프
                y = Math.max(margin, Math.min(anchor.y + bottomButtonBar.height + margin,
                                              Overlay.overlay.height - height - margin))
            }
        }

        onAboutToShow: Qt.callLater(_reposition)
        onOpened: _reposition()

        contentItem: Column {
            spacing: 8
            onImplicitHeightChanged: if (streamingSettingsPopup.opened) streamingSettingsPopup._reposition()

            Label { text: qsTr("스트리밍 설정"); color: "white"; font.pixelSize: 13 }
            ComboBox { width: parent.width; model: ["720p", "1080p"] }
            ComboBox { width: parent.width; model: ["24 FPS", "30 FPS", "60 FPS"] }
            ComboBox { width: parent.width; model: ["2 Mbps", "4 Mbps", "8 Mbps"] }
        }
    }

    // 상단 타이틀바 (Overlay 모드 전용)
    Rectangle {
        id: popupTopBar
        visible: videoRoot.mapOverlayMode && !videoRoot.placeholderBlackMode
        z: 5000
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: videoRoot._popupTitleBarHeight
        color: "#222222"
        border.width: 1
        border.color: "#3a3a3a"

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            text: videoRoot.title
            color: "white"
            font.pixelSize: 12
        }

        MouseArea {
            id: popupTitleDragArea
            anchors.fill: parent
            onDoubleClicked: videoRoot.requestPopupToggleMaximize()
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height

            Repeater {
                model: [
                    { t: "—", c: "#2f2f2f", s: 14, f: () => videoRoot.requestPopupMinimize() },
                    { t: "□", c: "#2f2f2f", s: 12, f: () => videoRoot.requestPopupToggleMaximize() },
                    { t: "×", c: "#C42B1C", s: 16, f: () => videoRoot.requestPopupClose() }
                ]
                Rectangle {
                    width: index === 2 ? 40 : 36
                    height: popupTopBar.height
                    color: ma.containsMouse ? modelData.c : "transparent"
                    Text { anchors.centerIn: parent; text: modelData.t; color: "white"; font.pixelSize: modelData.s }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: modelData.f() }
                }
            }
        }
    }

    readonly property bool _showConnectingState: videoRoot.useGStreamer ? false : (mediaPlayer.mediaStatus !== MediaPlayer.BufferedMedia && mediaPlayer.mediaStatus !== MediaPlayer.LoadedMedia)

    BusyIndicator {
        anchors.centerIn: parent
        visible: !videoRoot.placeholderBlackMode && videoRoot.streamEnabled && videoRoot._showConnectingState
        running: visible
        z: 2
    }

    Text {
        id: connectingStatusText
        anchors.left: parent.left
        anchors.top: videoRoot.mapOverlayMode ? popupTopBar.bottom : parent.top
        anchors.margins: 8
        visible: !videoRoot.placeholderBlackMode && videoRoot.streamEnabled && videoRoot._showConnectingState
        text: (channelLabel || selectionLabel || "카메라") + " 연결 확인 중..."
        color: "#aaa"
        font.pixelSize: 11
        z: 3
    }

    // 확대/맵 전환 버튼 (축소 상태에서만 표시)
    Item {
        id: expandMapButton
        anchors.right: parent.right
        anchors.top: videoRoot.mapOverlayMode ? popupTopBar.bottom : parent.top
        anchors.margins: videoRoot._topOverlayMargin
        width: videoRoot._topOverlayHeight
        height: videoRoot._topOverlayHeight
        visible: videoRoot.showExpandButton && !videoRoot.mapOverlayMode && !videoRoot.placeholderBlackMode
        enabled: videoRoot.mapToggleEnabled
        opacity: enabled ? 1.0 : 0.45
        z: 10
        Text {
            anchors.centerIn: parent
            text: "⤢"
            color: expandMapMouseArea.pressed ? "#cccccc" : "white"
            font.pixelSize: parent.height * 1.2
            style: Text.Outline
            styleColor: "#cc000000"
        }
        MouseArea {
            id: expandMapMouseArea
            anchors.fill: parent
            onClicked: videoRoot.toggleMapVideoRequested()
        }
    }

    MediaPlayer {
        id: mediaPlayer
        videoOutput: videoOutput
        source: videoRoot.useGStreamer ? "" : videoRoot._playbackSource
        audioOutput: AudioOutput { muted: true }
        onMediaStatusChanged: {
            if (videoRoot.useGStreamer) return
            videoRoot._logVideo("mediaStatus: " + videoRoot._mediaStatusString(mediaStatus))
            if (mediaStatus === MediaPlayer.InvalidMedia || mediaStatus === MediaPlayer.NoMedia) {
                videoRoot._playbackSource = ""
                reconnectTimer.restart()
            } else if (mediaStatus === MediaPlayer.EndOfMedia) {
                endOfMediaRestartTimer.start()
            }
        }
        onErrorOccurred: (error, errorString) => {
            if (videoRoot.useGStreamer) return
            videoRoot._logVideo("error: " + error + " " + errorString + " source: " + videoRoot._effectiveRtspSource)
            videoRoot._playbackSource = ""
            reconnectTimer.start()
        }
    }

    Timer { id: reconnectTimer; interval: 3000; onTriggered: _applySourceAndPlay() }
    Timer { id: endOfMediaRestartTimer; interval: 400; onTriggered: _applySourceAndPlay() }
    Timer { id: sourceResetRestartTimer; interval: 200; repeat: false; onTriggered: () => { videoRoot._playbackSource = videoRoot._effectiveRtspSource; mediaPlayer.play() } }
    Timer { id: gstReloadTimer; interval: 0; repeat: false; onTriggered: videoRoot._gstReloadPulse = true }

    Component.onCompleted: {
        _logVideo("created, channelUrl=" + channelUrl + " streamEnabled=" + streamEnabled + " useGStreamer=" + videoRoot.useGStreamer + " useVideoManager=" + videoRoot.useVideoManager)
        if (videoRoot.useVideoManager) {
            videoRoot.requestAttachSharedVideo(sharedVideoArea)
        } else if (!videoRoot.useGStreamer) {
            Qt.callLater(_applySourceAndPlay)
            if (videoRoot.isMainVideo && typeof VideoPassthroughHelper !== "undefined")
                VideoPassthroughHelper.setSourceOutput(videoOutput)
        }
    }

    Component.onDestruction: {
        // 파괴 전 공유 서피스를 반드시 반납(부모 홀더로 reparent)해 dangling 방지.
        if (videoRoot.useVideoManager)
            videoRoot.requestDetachSharedVideo(sharedVideoArea)
    }
}
