/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "VideoPassthroughHelper.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QTimer>
#include <QtMultimedia/QVideoFrame>
#include <QtMultimedia/QVideoSink>
#include <QtMultimediaQuick/private/qquickvideooutput_p.h>

QGC_LOGGING_CATEGORY(VideoPassthroughHelperLog, "qgc.videopassthrough")

VideoPassthroughHelper::VideoPassthroughHelper(QObject *parent)
    : QObject(parent)
{
}

QVideoSink *VideoPassthroughHelper::sinkFromVideoOutput(QObject *item) const
{
    if (!item)
        return nullptr;
    QQuickVideoOutput *vo = qobject_cast<QQuickVideoOutput *>(item);
    if (!vo) {
        qCWarning(VideoPassthroughHelperLog) << "sinkFromVideoOutput: not a VideoOutput";
        return nullptr;
    }
    return vo->videoSink();
}

void VideoPassthroughHelper::setSourceOutput(QObject *videoOutputItem)
{
    if (_sourceItem == videoOutputItem && _sourceSink)
        return;

    if (_frameConnection)
        disconnect(_frameConnection);
    _sourceItem = videoOutputItem;
    _sourceSink = sinkFromVideoOutput(videoOutputItem);
    if (!_sourceSink) {
        _sourceItem = nullptr;
        qCWarning(VideoPassthroughHelperLog) << "setSourceOutput: invalid source";
        return;
    }
    _frameConnection = connect(_sourceSink, &QVideoSink::videoFrameChanged,
                              this, &VideoPassthroughHelper::onSourceFrameChanged);
    qCDebug(VideoPassthroughHelperLog) << "setSourceOutput: source registered";
    emit sourceSet();
}

void VideoPassthroughHelper::addSecondaryOutput(QObject *videoOutputItem)
{
    if (!videoOutputItem)
        return;
    QVideoSink *sink = sinkFromVideoOutput(videoOutputItem);
    if (!sink) {
        qCWarning(VideoPassthroughHelperLog) << "addSecondaryOutput: invalid item";
        return;
    }
    if (_secondarySinks.contains(sink))
        return;
    _secondarySinks.append(sink);
    _secondaryItems.append(QPointer<QObject>(videoOutputItem));
    qCDebug(VideoPassthroughHelperLog) << "addSecondaryOutput: count" << _secondarySinks.size();
}

void VideoPassthroughHelper::removeSecondaryOutput(QObject *videoOutputItem)
{
    int idx = -1;
    for (int i = 0; i < _secondaryItems.size(); ++i) {
        if (_secondaryItems.at(i).data() == videoOutputItem) {
            idx = i;
            break;
        }
    }
    if (idx < 0)
        return;
    _secondaryItems.removeAt(idx);
    _secondarySinks.removeAt(idx);
    qCDebug(VideoPassthroughHelperLog) << "removeSecondaryOutput: count" << _secondarySinks.size();
}

void VideoPassthroughHelper::onSourceFrameChanged(const QVideoFrame &frame)
{
    if (!frame.isValid())
        return;
    // 확대창이 메인보다 먼저 그려지는 현상 방지: 보조 출력에는 다음 이벤트 루프에서 전달해
    // 메인 윈도우가 먼저 페인트될 기회를 줌. 프레임은 복사해 전달(다음 틱에 원본이 무효화될 수 있음).
    QVideoFrame frameCopy(frame);
    QTimer::singleShot(0, this, [this, frameCopy]() mutable {
        if (!frameCopy.isValid())
            return;
        for (int i = _secondarySinks.size() - 1; i >= 0; --i) {
            if (i < _secondaryItems.size() && _secondaryItems.at(i).isNull()) {
                _secondaryItems.removeAt(i);
                _secondarySinks.removeAt(i);
                continue;
            }
            if (i < _secondarySinks.size())
                _secondarySinks.at(i)->setVideoFrame(frameCopy);
        }
    });
}
