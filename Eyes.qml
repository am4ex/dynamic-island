import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real lookX: 0
    property real lookY: 0
    property bool tracking: false
    property bool happy: false
    property real eyeWidth: 6
    property real eyeHeight: 12
    property real gap: 6

    property real glanceX: 0
    property real glanceY: 0
    property real lid: 1

    property real curX: tracking ? lookX : glanceX
    property real curY: tracking ? lookY : glanceY

    Behavior on curX {
        SmoothedAnimation { velocity: 8 }
    }
    Behavior on curY {
        SmoothedAnimation { velocity: 8 }
    }

    implicitWidth: eyeWidth * 2 + gap
    implicitHeight: eyeHeight

    Timer {
        interval: 3500
        repeat: true
        running: root.visible && !root.happy
        onTriggered: {
            interval = 2500 + Math.random() * 3500;
            blink.restart();
        }
    }

    SequentialAnimation {
        id: blink
        NumberAnimation { target: root; property: "lid"; to: 0.12; duration: 70; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "lid"; to: 1; duration: 120; easing.type: Easing.OutQuad }
    }

    Timer {
        interval: 2200
        repeat: true
        running: root.visible && !root.tracking && !root.happy
        onTriggered: {
            interval = 1800 + Math.random() * 3000;
            if (Math.random() < 0.45) {
                root.glanceX = 0;
                root.glanceY = 0;
            } else {
                root.glanceX = Math.random() * 2 - 1;
                root.glanceY = (Math.random() * 2 - 1) * 0.5;
            }
        }
    }

    Repeater {
        model: 2

        Item {
            required property int index

            x: index * (root.eyeWidth + root.gap) + root.curX * 3
            y: root.curY * 2.5
            width: root.eyeWidth
            height: root.eyeHeight

            Rectangle {
                visible: !root.happy
                anchors.centerIn: parent
                width: parent.width
                height: Math.max(2, parent.height * root.lid)
                radius: width / 2
                color: "white"
            }

            Shape {
                visible: root.happy
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "white"
                    strokeWidth: 2.2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        moveToStart: true
                        centerX: root.eyeWidth / 2
                        centerY: root.eyeHeight * 0.65
                        radiusX: root.eyeWidth * 0.75
                        radiusY: root.eyeWidth * 0.75
                        startAngle: 200
                        sweepAngle: 140
                    }
                }
            }
        }
    }
}
