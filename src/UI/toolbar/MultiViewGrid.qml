import QtQuick 6.8
import QGroundControl
import QGroundControl.Toolbar

// 멀티뷰 그리드(최대 3x3, 9개). 각 셀은 크롬리스 VideoTile + 독립 CustomRtspReceiver.
// - 셀 본문 클릭 = 연결/해제(기본 OFF: 눌러야 재생). [추후 목록 연동으로 교체]
// - 셀 우상단 확대 버튼 = 같은 창 안에서 그 셀만 꽉 채움(다시 누르면 그리드 복귀). 별도 창 아님.
// - 암호 on/off·속도는 AppSettings > Video Crypto SSoT (드론/스테이션과 동일).
Rectangle {
    id: multiViewRoot
    color: "#0d0d0d"
    clip: true

    readonly property bool _cryptoEnabled: (typeof QGroundControl !== "undefined" && QGroundControl.videoCryptoSettings)
        ? QGroundControl.videoCryptoSettings.enabled
        : false
    readonly property string _cryptoMode: (typeof QGroundControl !== "undefined" && QGroundControl.videoCryptoSettings)
        ? QGroundControl.videoCryptoSettings.speedMode
        : "normal"

    /// 뷰 소스 목록 { label, url }. [하드코딩 — 추후 API 교체]
    property var sources: [
        { label: qsTr("View 1"), url: "rtsp://127.0.0.1:8554/live" },
        { label: qsTr("View 2"), url: "rtsp://127.0.0.1:8554/live" },
        { label: qsTr("View 3"), url: "rtsp://127.0.0.1:8554/live" },
        { label: qsTr("View 4"), url: "rtsp://127.0.0.1:8554/live" },
        { label: qsTr("View 5"), url: "rtsp://127.0.0.1:8554/live" },
        { label: qsTr("View 6"), url: "rtsp://127.0.0.1:8554/live" },
        { label: qsTr("View 7"), url: "rtsp://127.0.0.1:8554/live" },
        { label: qsTr("View 8"), url: "rtsp://127.0.0.1:8554/live" },
        { label: qsTr("View 9"), url: "rtsp://127.0.0.1:8554/live" }
    ]

    readonly property int maxCells: 9
    readonly property int cols: 3
    readonly property int count: Math.min(sources.length, maxCells)
    /// 창 안에서 꽉 채운 셀 인덱스(-1이면 그리드).
    property int expandedIndex: -1

    readonly property real _spacing: 2
    readonly property int _rows: Math.max(1, Math.ceil(count / cols))
    readonly property real _cellW: cols > 0 ? (width - _spacing * (cols - 1)) / cols : width
    readonly property real _cellH: _rows > 0 ? (height - _spacing * (_rows - 1)) / _rows : height

    // 창이 닫힐 때 호출: 모든 셀의 RTSP 커넥션을 끊고(연결 해제) 확대 상태도 초기화.
    function disconnectAll() {
        expandedIndex = -1
        for (var i = 0; i < cellRepeater.count; i++) {
            var it = cellRepeater.itemAt(i)
            if (it)
                it.connected = false
        }
    }

    Repeater {
        id: cellRepeater
        model: multiViewRoot.count
        delegate: VideoTile {
            id: cell
            property int cellIndex: index
            property bool connected: false      // 기본 OFF (선택해야 재생)
            readonly property var _src: multiViewRoot.sources[cellIndex] || null
            readonly property bool _expanded: multiViewRoot.expandedIndex === cellIndex
            readonly property int _col: cellIndex % multiViewRoot.cols
            readonly property int _row: Math.floor(cellIndex / multiViewRoot.cols)

            // 그리드 위치 ↔ 창 전체 채움(같은 창 내부)
            x: _expanded ? 0 : _col * (multiViewRoot._cellW + multiViewRoot._spacing)
            y: _expanded ? 0 : _row * (multiViewRoot._cellH + multiViewRoot._spacing)
            width: _expanded ? multiViewRoot.width : multiViewRoot._cellW
            height: _expanded ? multiViewRoot.height : multiViewRoot._cellH
            z: _expanded ? 10 : 0
            visible: multiViewRoot.expandedIndex < 0 || _expanded

            logTag: "MultiView" + (cellIndex + 1)
            title: (_src && _src.label) ? _src.label : (qsTr("View ") + (cellIndex + 1))
            channelLabel: title
            selectionLabel: title
            selectionToken: "multiview-" + cellIndex
            channelUrl: (_src && _src.url) ? _src.url : ""
            streamEnabled: cell.connected      // 연결된 셀만 재생
            // 전송은 video_endpoints.ini. 멀티뷰 전용 키가 없어 drone 값을 따른다.
            rtpTransport: (typeof QGroundControl !== "undefined" && QGroundControl.videoEndpointSettings)
                ? QGroundControl.videoEndpointSettings.droneRtpTransport
                : "udp"
            cryptoEnabled: multiViewRoot._cryptoEnabled
            cryptoMode: multiViewRoot._cryptoMode
            useVideoManager: false
            showControls: false
            showExpandButton: false
            mapToggleEnabled: false

            // 셀 본문 클릭 = 연결/해제 (버튼 영역 제외)
            MouseArea {
                anchors.fill: parent
                z: 30
                onClicked: cell.connected = !cell.connected
            }

            // 미연결 안내 오버레이
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.55
                visible: !cell.connected
                z: 32
                Text {
                    anchors.centerIn: parent
                    text: qsTr("클릭하여 연결")
                    color: "#cccccc"
                    font.pixelSize: 12
                }
            }

            // 좌상단 라벨
            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 6
                text: cell.title
                color: "white"
                font.pixelSize: 11
                style: Text.Outline
                styleColor: "black"
                z: 40
            }

            // 우상단 확대/복귀 버튼 (같은 창 내부)
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4
                width: 22
                height: 22
                radius: 3
                color: expandBtnArea.containsMouse ? "#3a3a3a" : "#22000000"
                border.color: "#66ffffff"
                border.width: 1
                z: 41
                Text { anchors.centerIn: parent; text: cell._expanded ? "⤡" : "⤢"; color: "white"; font.pixelSize: 13 }
                MouseArea {
                    id: expandBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: multiViewRoot.expandedIndex = cell._expanded ? -1 : cell.cellIndex
                }
            }
        }
    }
}
