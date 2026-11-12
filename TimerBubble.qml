import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Item {
    id: root

    property bool wanted: false
    property real fraction: 0
    property real gap: 8
    property real anchorWidth: 0
    signal clicked

    property real out: wanted ? 1 : 0

    Behavior on out {
        NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
    }

    width: height
    x: anchorWidth - width + (width + gap) * out
    visible: out > 0.01
    opacity: Math.min(1, out * 1.6)
    scale: 0.3 + 0.7 * Math.min(1, out)

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.background

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#90000000"
            shadowBlur: 0.6
            shadowVerticalOffset: 3
            blurMax: 20
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
            strokeWidth: 3.4
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - 8
                radiusY: root.width / 2 - 8
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.accent
            strokeWidth: 3.4
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - 8
                radiusY: root.width / 2 - 8
                startAngle: -90
                sweepAngle: 360 * Math.max(0.001, Math.min(1, root.fraction))
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
