import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real volume: 0
    property bool muted: false
    readonly property real level: Math.max(0, Math.min(1, volume))
    readonly property color accent: muted ? "#7a7a7a" : Theme.accent

    Shape {
        id: icon
        x: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 18
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor: root.accent
            startX: 1; startY: 6
            PathLine { x: 5; y: 6 }
            PathLine { x: 10; y: 1 }
            PathLine { x: 10; y: 17 }
            PathLine { x: 5; y: 12 }
            PathLine { x: 1; y: 12 }
            PathLine { x: 1; y: 6 }
        }

        ShapePath {
            strokeWidth: 1.8
            strokeColor: !root.muted && root.level > 0 ? root.accent : "transparent"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                moveToStart: true
                centerX: 10; centerY: 9
                radiusX: 4; radiusY: 4
                startAngle: -45; sweepAngle: 90
            }
        }

        ShapePath {
            strokeWidth: 1.8
            strokeColor: !root.muted && root.level > 0.5 ? root.accent : "transparent"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                moveToStart: true
                centerX: 10; centerY: 9
                radiusX: 8; radiusY: 8
                startAngle: -45; sweepAngle: 90
            }
        }

        ShapePath {
            strokeWidth: 1.8
            strokeColor: root.muted ? root.accent : "transparent"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 14; startY: 6
            PathLine { x: 20; y: 12 }
            PathMove { x: 20; y: 6 }
            PathLine { x: 14; y: 12 }
        }
    }

    Rectangle {
        id: track
        x: 50
        width: root.width - x - 56
        height: 6
        radius: 3
        anchors.verticalCenter: parent.verticalCenter
        color: "#40ffffff"

        Rectangle {
            width: parent.width * root.level
            height: parent.height
            radius: parent.radius
            color: root.accent

            Behavior on width {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }
    }

    Text {
        font.family: Theme.fontFamily
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.volume * 100)
        color: root.accent
        font.pixelSize: 13
        font.weight: Font.ExtraBold
        font.features: { "tnum": 1 }
    }
}
