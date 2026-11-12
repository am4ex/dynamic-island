import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real lookX: 0
    property real lookY: 0
    property bool tracking: false
    property bool happy: false
    property bool alarmed: false
    property bool sleeping: false
    property bool pleased: false
    property real beat: 0
    property int winkTrigger: 0
    property int surpriseTrigger: 0
    property real fright: 1
    property real eyeWidth: 6
    property real eyeHeight: 12
    property real gap: 6

    property real glanceX: 0
    property real glanceY: 0
    property real lid: 1
    property real winkLid: 1
    readonly property real bob: Math.round(-beat * 2.2 * 2) / 2
    property real zLift: 0
    property real zOpacity: 0

    readonly property bool showHappy: happy || (pleased && !sleeping && !alarmed)
    property real sleepLid: sleeping ? 0.1 : 1

    Behavior on sleepLid {
        NumberAnimation { duration: 900; easing.type: Easing.InOutSine }
    }

    property real curX: sleeping ? 0 : tracking ? lookX : glanceX
    property real curY: sleeping ? 0.4 : tracking ? lookY : glanceY

    Behavior on curX {
        SmoothedAnimation { velocity: 8 }
    }
    Behavior on curY {
        SmoothedAnimation { velocity: 8 }
    }

    implicitWidth: eyeWidth * 2 + gap
    implicitHeight: eyeHeight

    onWinkTriggerChanged: if (!sleeping && !alarmed) winkAnim.restart()
    onSurpriseTriggerChanged: if (!alarmed) surpriseAnim.restart()

    Timer {
        interval: 3500
        repeat: true
        running: root.visible && !root.showHappy && !root.sleeping
        onTriggered: {
            interval = 2500 + Math.random() * 3500;
            if (Math.random() < 0.22)
                doubleBlink.restart();
            else
                blink.restart();
        }
    }

    SequentialAnimation {
        id: blink
        NumberAnimation { target: root; property: "lid"; to: 0.12; duration: 70; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "lid"; to: 1; duration: 120; easing.type: Easing.OutQuad }
    }

    SequentialAnimation {
        id: doubleBlink
        NumberAnimation { target: root; property: "lid"; to: 0.12; duration: 60; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "lid"; to: 1; duration: 90; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 90 }
        NumberAnimation { target: root; property: "lid"; to: 0.12; duration: 60; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "lid"; to: 1; duration: 110; easing.type: Easing.OutQuad }
    }

    SequentialAnimation {
        id: winkAnim
        NumberAnimation { target: root; property: "winkLid"; to: 0.1; duration: 90; easing.type: Easing.InQuad }
        PauseAnimation { duration: 180 }
        NumberAnimation { target: root; property: "winkLid"; to: 1; duration: 160; easing.type: Easing.OutBack }
    }

    SequentialAnimation {
        id: surpriseAnim
        NumberAnimation { target: root; property: "fright"; to: 1.45; duration: 110; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 260 }
        NumberAnimation { target: root; property: "fright"; to: 1; duration: 520; easing.type: Easing.OutElastic; easing.amplitude: 1.2; easing.period: 0.4 }
    }

    Timer {
        interval: 2200
        repeat: true
        running: root.visible && !root.tracking && !root.showHappy && !root.alarmed && !root.sleeping
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

    SequentialAnimation {
        running: root.sleeping && root.visible
        loops: Animation.Infinite
        onStopped: root.zOpacity = 0
        PauseAnimation { duration: 600 }
        PropertyAction { target: root; property: "zLift"; value: 0 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "zLift"; to: 1; duration: 1800; easing.type: Easing.OutSine }
            SequentialAnimation {
                NumberAnimation { target: root; property: "zOpacity"; to: 0.8; duration: 400 }
                PauseAnimation { duration: 900 }
                NumberAnimation { target: root; property: "zOpacity"; to: 0; duration: 500 }
            }
        }
    }

    Text {
        x: root.width + 2 + root.zLift * 4
        y: -4 - root.zLift * 10
        opacity: root.zOpacity
        scale: 0.7 + root.zLift * 0.5
        text: "z"
        color: Theme.accent
        font.family: Theme.fontFamily
        font.weight: Font.ExtraBold
        font.pixelSize: 9
    }

    Repeater {
        model: 2

        Item {
            id: eye
            required property int index

            x: index * (root.eyeWidth + root.gap) + root.curX * 3
            y: root.curY * 2.5 + root.bob
            scale: root.fright
            width: root.eyeWidth
            height: root.eyeHeight

            Rectangle {
                visible: !root.showHappy
                anchors.centerIn: parent
                width: parent.width
                height: Math.max(2, parent.height * root.lid * root.sleepLid * (eye.index === 1 ? root.winkLid : 1))
                radius: width / 2
                color: Theme.accent
            }

            Shape {
                visible: root.showHappy
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: Theme.accent
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

    SequentialAnimation {
        running: root.alarmed
        loops: Animation.Infinite
        onStopped: {
            root.fright = 1;
            root.glanceX = 0;
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "fright"; to: 1.35; duration: 120; easing.type: Easing.OutBack }
            PropertyAction { target: root; property: "glanceX"; value: -1 }
        }
        PauseAnimation { duration: 160 }
        PropertyAction { target: root; property: "glanceX"; value: 1 }
        PauseAnimation { duration: 160 }
        PropertyAction { target: root; property: "glanceX"; value: -1 }
        PauseAnimation { duration: 160 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "fright"; to: 1.1; duration: 200 }
            PropertyAction { target: root; property: "glanceX"; value: 0 }
        }
        PauseAnimation { duration: 400 }
    }
}
