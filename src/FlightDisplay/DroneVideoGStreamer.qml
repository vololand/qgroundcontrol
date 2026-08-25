/****************************************************************************
 *
 * DroneVideo 전용 GStreamer 비디오 아이템.
 * - channelIndex >= 0 이면 VideoManager 커스텀 다중 영상 채널로 등록·재생.
 * - channelIndex < 0 이면 registerDroneVideoWidget() 등 기존 단일 위젯용으로만 사용.
 *
 ****************************************************************************/

import QtQuick
import QGroundControl
import org.freedesktop.gstreamer.Qt6GLVideoItem

Item {
    property int channelIndex: -1
    property string channelUrl: ""

    GstGLQt6VideoItem {
        id: droneVideoGstItem
        anchors.fill: parent
    }

    Component.onCompleted: {
        if (channelIndex >= 0 && channelUrl) {
            QGroundControl.videoManager.registerCustomVideoWidget(channelIndex, droneVideoGstItem)
            QGroundControl.videoManager.setCustomChannelUrl(channelIndex, channelUrl)
        }
    }

    Component.onDestruction: {
        if (channelIndex >= 0)
            QGroundControl.videoManager.unregisterCustomVideoWidget(channelIndex)
    }
}
