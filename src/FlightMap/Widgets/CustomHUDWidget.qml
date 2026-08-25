import QtQuick

import QGroundControl.ScreenTools

Item {
    id: root

    // ── 사이드이펙트 대응 ──────────────────────────────────────────────────────
    // Item은 implicitHeight 기본값이 0이므로 반드시 명시.
    // CustomFlyView.qml의 droneStatus ColumnLayout에서 DroneList(fillHeight)가
    // 이 값을 기준으로 공간을 배분하므로, maximumHeight와 일치시켜야 레이아웃 안정.
    implicitHeight: ScreenTools.defaultFontPixelHeight * 14
    implicitWidth:  parent ? parent.width : 300

    // CustomFlyView에서 선택된 로컬기기(QGC Vehicle) 데이터를 주입
    property real rollDeg:    0   // deg
    property real pitchDeg:   0   // deg
    property real headingDeg: 0   // deg (0~360)
    property real speedMps:   0   // m/s
    property real altM:       0   // m

    // 전체 배경 (좌우 테이프와 동일한 색으로 중앙 투명 영역 통일)
    Rectangle {
        anchors.fill: parent
        //color: "#121212"
        color: "#111111" 
    }

    // ── 중앙 PFD 행 (헤딩 스트립 제외 나머지) ────────────────────────────────
    Item {
        id: pfdRow
        anchors.top:    parent.top
        anchors.bottom: headingStrip.top
        anchors.left:   parent.left
        anchors.right:  parent.right

        // ── 왼쪽 속도 테이프 (65px) ─────────────────────────────────────────
        Canvas {
            id: spdTape
            anchors.left:   parent.left
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width: 65
            clip: true
            renderTarget: Canvas.FramebufferObject

            property real spdValue: root.speedMps
            onSpdValueChanged: requestPaint()
            onWidthChanged:    requestPaint()
            onHeightChanged:   requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d")

                var cx = width
                var cy = height / 2
                var pxPerUnit = 11
                var step = 5

                // 배경
                ctx.fillStyle = "#CC111111"
                ctx.fillRect(0, 0, width, height)

                // 눈금 및 레이블
                ctx.lineWidth = 1
                for (var v = -30; v <= 30; v += step) {
                    var val = Math.round(spdValue / step) * step + v
                    if (val < 0) continue
                    var y = cy - (val - spdValue) * pxPerUnit
                    if (y < 2 || y > height - 2) continue

                    var isMajor = (val % 10 === 0)
                    ctx.strokeStyle = isMajor ? "#AAAAAA" : "#666666"
                    ctx.beginPath()
                    ctx.moveTo(cx - (isMajor ? 14 : 7), y)
                    ctx.lineTo(cx - 1, y)
                    ctx.stroke()

                    if (isMajor) {
                        ctx.fillStyle = "#CCCCCC"
                        ctx.font = ScreenTools.smallFontPointSize + "pt sans-serif"
                        ctx.textAlign = "right"
                        ctx.fillText(val.toFixed(0), cx - 16, y + 4)
                    }
                }

                // 값 박스 위 타이틀(SPD) + 단위(m/s) 한 줄
                ctx.font = "bold " + ScreenTools.smallFontPointSize + "pt sans-serif"
                ctx.fillStyle = "#00ACC1"
                ctx.textAlign = "left"
                ctx.fillText("SPD", 3, cy - 16)
                ctx.fillStyle = "#888888"
                ctx.textAlign = "right"
                ctx.fillText("m/s", width - 3, cy - 16)

                // 현재값 박스
                ctx.fillStyle = "#00607080"
                ctx.fillRect(0, cy - 13, width - 1, 26)
                ctx.strokeStyle = "#00ACC1"
                ctx.lineWidth = 1
                ctx.strokeRect(0, cy - 13, width - 1, 26)

                ctx.fillStyle = "#FFFFFF"
                ctx.font = "bold " + ScreenTools.defaultFontPointSize + "pt sans-serif"
                ctx.textAlign = "center"
                ctx.fillText(spdValue.toFixed(1), (width - 1) / 2, cy + 5)
            }
        }
        
        Canvas {
            id: ahrsCanvas
            anchors.centerIn: parent
            width:  Math.max(40, Math.min(pfdRow.width - 130 - 10, pfdRow.height - 6) * 0.7)
            height: width
            renderTarget: Canvas.FramebufferObject

            property real rollAngle:  root.rollDeg
            property real pitchAngle: root.pitchDeg

            onRollAngleChanged:  requestPaint()
            onPitchAngleChanged: requestPaint()
            // width가 동적 바인딩으로 자주 바뀌므로 Timer로 디바운스하여 과도한 requestPaint() 연쇄 방지
            onWidthChanged:  ahrsResizeTimer.restart()
            onHeightChanged: ahrsResizeTimer.restart()
            Component.onCompleted: requestPaint()

            Timer {
                id: ahrsResizeTimer
                interval: 120
                repeat:   false
                onTriggered: ahrsCanvas.requestPaint()
            }

            onPaint: {
                var ctx = getContext("2d")

                var cx = width / 2, cy = height / 2
                var r  = Math.min(cx, cy) - 4   // 클리핑 반경
                var pxPerDeg = r / 30            // 30° = 반경 전체

                // 이전 프레임 잔상 제거 (누적 렌더링 방지)
                ctx.clearRect(0, 0, width, height)

                // ── 클리핑 원 ──────────────────────────────
                ctx.save()
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, Math.PI * 2)
                ctx.clip()

                // ── roll 회전 적용 ──────────────────────────
                ctx.translate(cx, cy)
                ctx.rotate(rollAngle * Math.PI / 180)
                // 좌우방향 변경

                // 피치 오프셋
                var pitchOffset = pitchAngle * pxPerDeg

                // 회전·피치와 무관하게 클리핑 원을 항상 완전히 덮도록 넉넉히 채운다.
                var big = r * 2

                // 하늘 (지평선 위 전체)
                ctx.fillStyle = "#1A3A5C"
                ctx.fillRect(-big, -big, big * 2, big - pitchOffset)

                // 지면 (지평선 아래 전체)
                ctx.fillStyle = "#3D2B1A"
                ctx.fillRect(-big, -pitchOffset, big * 2, big * 2)

                // 지평선
                ctx.strokeStyle = "#FFFFFF"
                ctx.lineWidth = 2
                ctx.beginPath()
                ctx.moveTo(-r, -pitchOffset)
                ctx.lineTo( r, -pitchOffset)
                ctx.stroke()

                // 피치 사다리 (5° 단위)
                for (var p = -30; p <= 30; p += 5) {
                    if (p === 0) continue
                    var py   = -pitchOffset - p * pxPerDeg
                    var hw   = (p % 10 === 0) ? r * 0.35 : r * 0.2
                    var isMaj = (p % 10 === 0)
                    ctx.strokeStyle = "#CCCCCC"
                    ctx.lineWidth = isMaj ? 1.5 : 1
                    ctx.beginPath()
                    ctx.moveTo(-hw, py)
                    ctx.lineTo( hw, py)
                    ctx.stroke()
                    if (isMaj) {
                        ctx.fillStyle = "#CCCCCC"
                        ctx.font = ScreenTools.smallFontPointSize + "pt sans-serif"
                        ctx.textAlign = "center"
                        ctx.fillText(Math.abs(p), hw + 10, py + 4)
                        ctx.fillText(Math.abs(p), -hw - 10, py + 4)
                    }
                }

                ctx.restore()  // 클리핑 & 회전 해제

                // ── 베젤 원 (경계선) ───────────────────────
                ctx.strokeStyle = "#555555"
                ctx.lineWidth = 2
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, Math.PI * 2)
                ctx.stroke()

                // ── 롤 눈금 호 ─────────────────────────────
                var rollMarks = [-60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60]
                rollMarks.forEach(function(deg) {
                    var rad = (deg - 90) * Math.PI / 180
                    var inner = r - (deg % 30 === 0 ? 12 : 7)
                    ctx.strokeStyle = deg === 0 ? "#FF5722" : "#888888"
                    ctx.lineWidth = deg === 0 ? 2 : 1
                    ctx.beginPath()
                    ctx.moveTo(cx + Math.cos(rad) * r,     cy + Math.sin(rad) * r)
                    ctx.lineTo(cx + Math.cos(rad) * inner,  cy + Math.sin(rad) * inner)
                    ctx.stroke()
                })

                // ── 롤 포인터 삼각형 (고정, 위쪽) ──────────
                ctx.fillStyle = "#FF5722"
                ctx.beginPath()
                ctx.moveTo(cx - 5, cy - r + 16)
                ctx.lineTo(cx + 5, cy - r + 16)
                ctx.lineTo(cx,     cy - r + 6)
                ctx.closePath()
                ctx.fill()

                // ── 중앙 에이밍 마크 ────────────────────────
                ctx.strokeStyle = "#FFFFFF"
                ctx.lineWidth = 2
                ctx.beginPath()
                ctx.moveTo(cx - 30, cy); ctx.lineTo(cx - 8, cy)
                ctx.moveTo(cx + 8,  cy); ctx.lineTo(cx + 30, cy)
                ctx.arc(cx, cy, 4, 0, Math.PI * 2)
                ctx.stroke()
            }
        }
        
        // ── 오른쪽 고도 테이프 (65px) ────────────────────────────────────────
        Canvas {
            id: altTape
            anchors.right:  parent.right
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width: 65
            clip: true
            renderTarget: Canvas.FramebufferObject

            property real altValue: root.altM
            onAltValueChanged: requestPaint()
            onWidthChanged:    requestPaint()
            onHeightChanged:   requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d")

                var cx = 0
                var cy = height / 2
                var pxPerUnit = 8
                var step = 5

                ctx.fillStyle = "#CC111111"
                ctx.fillRect(0, 0, width, height)

                ctx.lineWidth = 1
                for (var v = -30; v <= 30; v += step) {
                    var val = Math.round(altValue / step) * step + v
                    var y = cy - (val - altValue) * pxPerUnit
                    if (y < 2 || y > height - 2) continue

                    var isMajor = (val % 10 === 0)
                    ctx.strokeStyle = isMajor ? "#AAAAAA" : "#666666"
                    ctx.beginPath()
                    ctx.moveTo(cx + 1, y)
                    ctx.lineTo(cx + (isMajor ? 14 : 7), y)
                    ctx.stroke()

                    if (isMajor) {
                        ctx.fillStyle = "#CCCCCC"
                        ctx.font = ScreenTools.smallFontPointSize + "pt sans-serif"
                        ctx.textAlign = "left"
                        ctx.fillText(val.toFixed(0), cx + 16, y + 4)
                    }
                }

                // 값 박스 위 타이틀(ALT) + 단위(m) 한 줄
                ctx.font = "bold " + ScreenTools.smallFontPointSize + "pt sans-serif"
                ctx.fillStyle = "#43A047"
                ctx.textAlign = "left"
                ctx.fillText("ALT", 3, cy - 16)
                ctx.fillStyle = "#888888"
                ctx.textAlign = "right"
                ctx.fillText("m", width - 3, cy - 16)

                // 현재값 박스
                ctx.fillStyle = "#001B5E2080"
                ctx.fillRect(cx + 1, cy - 13, width - 1, 26)
                ctx.strokeStyle = "#43A047"
                ctx.lineWidth = 1
                ctx.strokeRect(cx + 1, cy - 13, width - 1, 26)

                ctx.fillStyle = "#FFFFFF"
                ctx.font = "bold " + ScreenTools.defaultFontPointSize + "pt sans-serif"
                ctx.textAlign = "center"
                ctx.fillText(altValue.toFixed(1), cx + 1 + (width - 1) / 2, cy + 5)
            }
        }
    }

    // ── 하단 헤딩 스트립 (고정 30px) ──────────────────────────────────────────
    Canvas {
        id: headingStrip
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        height: 30
        clip: true
        renderTarget: Canvas.FramebufferObject

        property real hdgValue: root.headingDeg
        onHdgValueChanged: requestPaint()
        onWidthChanged:    requestPaint()
        onHeightChanged:   requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            var ctx = getContext("2d")

            ctx.fillStyle = "#CC111111"
            ctx.fillRect(0, 0, width, height)

            // 상단 구분선
            ctx.strokeStyle = "#444444"
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(width, 0)
            ctx.stroke()

            var centerX  = width / 2
            var pxPerDeg = width / 60   // 화면에 ±30° 표시

            var compassLabels = { 0: "N", 90: "E", 180: "S", 270: "W" }

            // 눈금을 "실제 방위 각도"(5° 배수)에 고정해 부드럽게 스크롤시킨다.
            // 화면 오프셋에 고정하면 hdgValue 반올림 경계에서 라벨이 깜빡이므로 지양.
            var startDeg = Math.ceil((hdgValue - 40) / 5) * 5
            for (var deg = startDeg; deg <= hdgValue + 40; deg += 5) {
                var x = centerX + (deg - hdgValue) * pxPerDeg
                if (x < 0 || x > width) continue

                var norm    = ((deg % 360) + 360) % 360
                var isMajor = (deg % 10 === 0)   // deg는 5의 배수이므로 반올림 불필요
                ctx.strokeStyle = isMajor ? "#AAAAAA" : "#555555"
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(x, 1)
                ctx.lineTo(x, isMajor ? 10 : 6)
                ctx.stroke()

                if (isMajor) {
                    var lbl = compassLabels[norm] !== undefined
                            ? compassLabels[norm]
                            : norm.toFixed(0)
                    ctx.fillStyle = compassLabels[norm] !== undefined ? "#00E5FF" : "#CCCCCC"
                    ctx.font = ScreenTools.smallFontPointSize + "pt sans-serif"
                    ctx.textAlign = "center"
                    ctx.fillText(lbl, x, 25)
                }
            }

            // 중앙 포인터 ▼
            ctx.fillStyle = "#FF5722"
            ctx.beginPath()
            ctx.moveTo(centerX - 5, 1)
            ctx.lineTo(centerX + 5, 1)
            ctx.lineTo(centerX,     9)
            ctx.closePath()
            ctx.fill()
        }
    }
}
