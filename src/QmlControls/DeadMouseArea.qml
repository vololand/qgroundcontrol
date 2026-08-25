import QtQuick
import QtQuick.Controls

MouseArea {
    // 기본(LeftButton만)이면 우클릭이 아래 뷰(CustomFlyView 패널 등)로 새어 나간다.
    acceptedButtons: Qt.AllButtons
    preventStealing:true
    hoverEnabled:   true
    onWheel:    (wheel) => { wheel.accepted = true; }
    onPressed:  (mouse) => { mouse.accepted = true; }
    onReleased: (mouse) => { mouse.accepted = true; }
}
