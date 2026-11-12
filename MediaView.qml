import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Mpris

Item {
    id: root

    property MprisPlayer player: null
    property real progress: 0
    property bool expanded: false
    property string timeText: ""
    property string layoutBadge: ""
    property var levels: []
    property color accent: "#4cd964"
    property var players: []
    property real playerVolume: 0
    property bool hasPlayerVolume: false

    signal choosePlayer(var chosen)
    signal changePlayerVolume(real value)

    readonly property bool playing: player !== null && player.isPlaying
    property real topOffset: 36
    readonly property string artUrl: player ? player.trackArtUrl : ""
    readonly property real position: player ? player.position : 0
    readonly property int lyricIndex: Math.max(0, lyrics.indexAt(position))

    function lerp(a, b) {
        return a + (b - a) * progress;
    }

    function formatTime(sec) {
        if (!isFinite(sec) || sec < 0)
            sec = 0;
        const s = Math.floor(sec);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    component Triangle: Shape {
        id: tri
        property bool pointRight: true
        width: 12
        height: 14
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 2
            strokeColor: Theme.accent
            joinStyle: ShapePath.RoundJoin
            fillColor: Theme.accent
            startX: tri.pointRight ? 0 : tri.width
            startY: 0
            PathLine { x: tri.pointRight ? tri.width : 0; y: tri.height / 2 }
            PathLine { x: tri.pointRight ? 0 : tri.width; y: tri.height }
            PathLine { x: tri.pointRight ? 0 : tri.width; y: 0 }
        }
    }

    component ControlButton: Item {
        id: btn
        property bool active: true
        default property alias content: holder.data
        signal activated

        width: 40
        height: 40
        opacity: active ? 1 : 0.35

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.accent
            opacity: area.pressed ? 0.2 : area.containsMouse ? 0.1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
        }

        Item {
            id: holder
            anchors.centerIn: parent
            width: childrenRect.width
            height: childrenRect.height
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.active
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.activated()
        }
    }

    Lyrics {
        id: lyrics
        wanted: root.expanded
        title: root.player ? root.player.trackTitle : ""
        artist: root.player ? root.player.trackArtist : ""
        duration: root.player && root.player.lengthSupported ? root.player.length : 0
    }

    Timer {
        interval: 250
        repeat: true
        triggeredOnStart: true
        running: root.expanded && root.playing
        onTriggered: root.player.positionChanged()
    }

    onExpandedChanged: if (expanded && player) player.positionChanged()

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: (38 - height) / 2
        spacing: 8
        opacity: Math.max(0, 1 - root.progress * 3)
        visible: opacity > 0

        LayoutBadge {
            anchors.verticalCenter: parent.verticalCenter
            code: root.layoutBadge
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            text: root.timeText
            color: Theme.accent
            font.pixelSize: 17
            font.features: { "tnum": 1 }
        }
    }

    Item {
        id: full
        width: 560
        height: 200
        x: (root.width - width) / 2
        y: root.topOffset
        opacity: Math.max(0, Math.min(1, (root.progress - 0.5) * 2))
        visible: opacity > 0

        Column {
            x: 96
            y: 24
            width: 160
            spacing: 3

            Text {
                font.family: Theme.fontFamily
                width: parent.width
                text: root.player ? (root.player.trackTitle || "Неизвестный трек") : ""
                color: Theme.accent
                font.pixelSize: 15
                font.weight: Font.ExtraBold
                elide: Text.ElideRight
            }

            Text {
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                width: parent.width
                text: root.player ? (root.player.trackArtist || "Неизвестный исполнитель") : ""
                color: Theme.dim
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }

        Text {
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            id: elapsed
            x: 18
            y: 90
            width: 36
            text: root.formatTime(root.position)
            color: Theme.dim
            font.pixelSize: 11
            font.features: { "tnum": 1 }
        }

        Rectangle {
            x: 58
            width: 184
            height: 4
            radius: 2
            anchors.verticalCenter: elapsed.verticalCenter
            color: "#40ffffff"

            Rectangle {
                readonly property real ratio: {
                    if (!root.player || !root.player.lengthSupported || root.player.length <= 0)
                        return 0;
                    return Math.max(0, Math.min(1, root.position / root.player.length));
                }
                width: parent.width * ratio
                height: parent.height
                radius: parent.radius
                color: Theme.accent

                Behavior on width {
                    NumberAnimation { duration: 250; easing.type: Easing.Linear }
                }
            }
        }

        Text {
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            x: 246
            y: elapsed.y
            width: 36
            horizontalAlignment: Text.AlignRight
            text: root.player && root.player.lengthSupported ? root.formatTime(root.player.length) : "--:--"
            color: Theme.dim
            font.pixelSize: 11
            font.features: { "tnum": 1 }
        }

        Row {
            id: controls
            x: 150 - width / 2
            y: 108
            spacing: 26

            ControlButton {
                anchors.verticalCenter: parent.verticalCenter
                active: root.player !== null && root.player.canGoPrevious
                onActivated: root.player.previous()

                Row {
                    spacing: 1
                    Rectangle { width: 3; height: 14; radius: 1; color: Theme.accent }
                    Triangle { pointRight: false }
                }
            }

            ControlButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 46
                height: 46
                active: root.player !== null && root.player.canTogglePlaying
                onActivated: root.player.togglePlaying()

                Item {
                    width: 16
                    height: 18

                    Triangle {
                        x: 2
                        width: 15
                        height: 18
                        visible: !root.playing
                    }

                    Row {
                        visible: root.playing
                        spacing: 5
                        x: 1
                        Rectangle { width: 5; height: 18; radius: 1.5; color: Theme.accent }
                        Rectangle { width: 5; height: 18; radius: 1.5; color: Theme.accent }
                    }
                }
            }

            ControlButton {
                anchors.verticalCenter: parent.verticalCenter
                active: root.player !== null && root.player.canGoNext
                onActivated: root.player.next()

                Row {
                    spacing: 1
                    Triangle { pointRight: true }
                    Rectangle { width: 3; height: 14; radius: 1; color: Theme.accent }
                }
            }
        }

        Item {
            x: 18
            y: 160
            width: 264
            height: 20
            visible: root.hasPlayerVolume

            Shape {
                width: 12
                height: 12
                anchors.verticalCenter: parent.verticalCenter
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: -1
                    fillColor: Theme.dim
                    startX: 0; startY: 4
                    PathLine { x: 3; y: 4 }
                    PathLine { x: 7; y: 0 }
                    PathLine { x: 7; y: 12 }
                    PathLine { x: 3; y: 8 }
                    PathLine { x: 0; y: 8 }
                    PathLine { x: 0; y: 4 }
                }
            }

            Rectangle {
                id: volTrack
                x: 22
                width: parent.width - x
                height: 4
                radius: 2
                anchors.verticalCenter: parent.verticalCenter
                color: "#40ffffff"

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.playerVolume))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                }
            }

            MouseArea {
                x: volTrack.x - 6
                width: volTrack.width + 12
                height: parent.height
                cursorShape: Qt.PointingHandCursor

                function apply(mx) {
                    root.changePlayerVolume(Math.max(0, Math.min(1, (mx - 6) / volTrack.width)));
                }

                onPressed: mouse => apply(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        apply(mouse.x);
                }
            }
        }

        Item {
            id: lyricBox
            x: 312
            y: 14
            width: 232
            height: root.players.length > 1 ? 138 : 168
            clip: true

            Column {
                id: lyricColumn
                width: parent.width
                spacing: 7
                y: {
                    const lines = lyrics.lines;
                    const it = lines.length > 0 ? lyricRepeater.itemAt(root.lyricIndex) : null;
                    return it ? lyricBox.height / 2 - (it.y + it.height / 2) : 0;
                }

                Behavior on y {
                    NumberAnimation { duration: 450; easing.type: Easing.OutCubic }
                }

                Repeater {
                    id: lyricRepeater
                    model: lyrics.lines

                    Text {
                        font.family: Theme.fontFamily
                        required property var modelData
                        required property int index
                        readonly property bool current: index === root.lyricIndex

                        width: lyricColumn.width
                        text: modelData.text || "♪"
                        wrapMode: Text.WordWrap
                        color: current ? Theme.accent : Theme.faint
                        opacity: Math.max(0.25, 1 - Math.abs(index - root.lyricIndex) * 0.28)
                        font.pixelSize: current ? 14 : 12
                        font.weight: current ? Font.ExtraBold : Font.Bold

                        Behavior on color {
                            ColorAnimation { duration: 250 }
                        }
                    }
                }
            }

            Text {
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                anchors.centerIn: parent
                visible: lyrics.lines.length === 0
                text: lyrics.status === "loading" ? "Ищу текст…" : "Текст не найден"
                color: Theme.faint
                font.pixelSize: 12
            }
        }

        Row {
            x: 312
            y: 162
            spacing: 6
            visible: root.players.length > 1

            Repeater {
                model: root.players

                Rectangle {
                    required property var modelData
                    readonly property bool selected: modelData === root.player

                    width: chipText.implicitWidth + 18
                    height: 22
                    radius: 11
                    color: selected ? "#40ffffff" : chipArea.containsMouse ? "#26ffffff" : "#14ffffff"

                    Text {
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                        id: chipText
                        anchors.centerIn: parent
                        text: parent.modelData.identity || "Плеер"
                        color: parent.selected ? Theme.accent : Theme.dim
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.choosePlayer(parent.modelData)
                    }
                }
            }
        }
    }

    ClippingRectangle {
        id: cover
        x: root.lerp(8, full.x + 20)
        y: root.lerp(7, root.topOffset + 20)
        width: root.lerp(24, 64)
        height: width
        radius: root.lerp(12, 14)
        color: "#2a2a2a"

        Image {
            anchors.fill: parent
            source: root.artUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 128
            sourceSize.height: 128
            asynchronous: true
            visible: status === Image.Ready
        }

        Text {
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            anchors.centerIn: parent
            text: "♪"
            color: Theme.faint
            font.pixelSize: cover.width * 0.55
            visible: root.artUrl === ""
        }
    }

    Row {
        id: equalizer
        x: root.lerp(root.width - width - 16, full.x + 282 - width)
        y: root.lerp(8, root.topOffset + 24)
        spacing: 3
        height: 22

        Repeater {
            model: 4

            Rectangle {
                id: bar
                required property int index

                property real fake: 4
                readonly property real level: {
                    const l = root.levels;
                    if (!l || l.length === 0)
                        return -1;
                    const per = Math.max(1, Math.floor(l.length / 4));
                    let s = 0;
                    for (let k = 0; k < per; k++)
                        s += l[Math.min(l.length - 1, index * per + k)];
                    return s / per;
                }
                readonly property int pace: [520, 380, 610, 450][index]
                readonly property real high: equalizer.height * (0.75 + 0.1 * (index % 3))

                anchors.verticalCenter: parent.verticalCenter
                width: 5
                radius: 2.5
                color: root.accent
                height: level >= 0 ? 4 + Math.min(1, level * 1.3) * (equalizer.height - 4) : fake

                SequentialAnimation on fake {
                    running: root.playing && bar.level < 0
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { to: bar.high; duration: bar.pace; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 7; duration: bar.pace * 0.8; easing.type: Easing.InOutSine }
                    NumberAnimation { to: bar.high * 0.7; duration: bar.pace * 0.6; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 4; duration: bar.pace * 0.9; easing.type: Easing.InOutSine }
                }
            }
        }
    }
}
