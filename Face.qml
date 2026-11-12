import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property color color: "#76a043"
    property bool playing: false
    property real wink: 1
    property real bob: 0

    implicitWidth: 30
    implicitHeight: 22

    onPlayingChanged: if (playing) intro.restart()

    SequentialAnimation {
        id: intro
        PropertyAction { target: root; property: "wink"; value: 1 }
        PropertyAction { target: root; property: "bob"; value: 0 }
        PauseAnimation { duration: 450 }
        NumberAnimation { target: root; property: "bob"; to: -3; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "bob"; to: 0; duration: 260; easing.type: Easing.OutBounce }
        PauseAnimation { duration: 250 }
        NumberAnimation { target: root; property: "wink"; to: 0.1; duration: 110; easing.type: Easing.InQuad }
        PauseAnimation { duration: 220 }
        NumberAnimation { target: root; property: "wink"; to: 1; duration: 180; easing.type: Easing.OutBack }
    }

    component Arc: Shape {
        id: arc
        property real cx: 0
        property real cy: 0
        property real r: 5
        property real start: 200
        property real sweep: 140
        property real stroke: 3.8
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: arc.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                moveToStart: true
                centerX: arc.cx
                centerY: arc.cy
                radiusX: arc.r
                radiusY: arc.r
                startAngle: arc.start
                sweepAngle: arc.sweep
            }
        }
    }

    Item {
        anchors.fill: parent
        transform: Translate { y: root.bob }

        Arc { cx: 7; cy: 10; r: 5.5 }

        Arc {
            cx: 23
            cy: 10
            r: 5.5
            transform: Scale { origin.x: 23; origin.y: 8; yScale: root.wink }
        }

        Arc { cx: 15; cy: 14; r: 3.5; start: 25; sweep: 130; stroke: 3.2 }
    }
}
