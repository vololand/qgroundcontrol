/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QObject>
#include <QtCore/QPointer>

class QVideoFrame;
class QVideoSink;
class QQuickVideoOutput;

/// 메인 비디오 출력(DroneVideo)의 프레임을 확대창 등 보조 출력으로 전달하는 패스스루.
/// 한 번 디코딩한 스트림을 여러 창에 공유해 동기화·멀티화면 확장에 유리함.
class VideoPassthroughHelper : public QObject
{
    Q_OBJECT

public:
    explicit VideoPassthroughHelper(QObject *parent = nullptr);

    /// 메인 VideoOutput (QML VideoOutput 아이템). 이 sink의 videoFrameChanged를 수신해 보조로 전달.
    Q_INVOKABLE void setSourceOutput(QObject *videoOutputItem);

    /// 확대창 등 보조 VideoOutput 추가. 메인에서 수신한 프레임을 여기로 setVideoFrame.
    Q_INVOKABLE void addSecondaryOutput(QObject *videoOutputItem);

    /// 보조 출력 제거 (확대창 닫을 때).
    Q_INVOKABLE void removeSecondaryOutput(QObject *videoOutputItem);

    /// 메인 소스가 등록되었는지. 확대창은 이게 true일 때만 보조 등록하면 메인 수신 전에 영상이 나오는 현상 방지.
    Q_INVOKABLE bool isSourceSet() const { return _sourceSink != nullptr; }

signals:
    /// setSourceOutput 호출로 메인 소스가 등록되었을 때. 이미 확대창이 열려 있으면 이때 보조 등록.
    void sourceSet();

private:
    QVideoSink *sinkFromVideoOutput(QObject *item) const;
    void onSourceFrameChanged(const class QVideoFrame &frame);

    QPointer<QObject> _sourceItem;
    QVideoSink *_sourceSink = nullptr;
    QMetaObject::Connection _frameConnection;
    QList<QVideoSink *> _secondarySinks;
    QList<QPointer<QObject>> _secondaryItems;
};
