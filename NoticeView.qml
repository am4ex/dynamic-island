import QtQuick
import Quickshell.Widgets

Item {
    id: root

    property var notice: null
    readonly property string kind: notice ? notice.kind : ""
    readonly property string title: notice ? notice.title : ""
    property int typed: 0
    property real subtitleIn: 1

    onNoticeChanged: {
        const full = notice ? notice.title : "";
        if (notice && notice.kind === "hello") {
            typed = 0;
            subtitleIn = 0;
            typeStep.to = full.length;
            typeStep.duration = full.length * 45;
            typing.restart();
        } else {
            typing.stop();
            typed = full.length;
            subtitleIn = 1;
        }
    }

    SequentialAnimation {
        id: typing
        PauseAnimation { duration: 280 }
        NumberAnimation { id: typeStep; target: root; property: "typed"; from: 0 }
        NumberAnimation { target: root; property: "subtitleIn"; to: 1; duration: 350; easing.type: Easing.OutCubic }
    }

    TextMetrics {
        id: titleMetrics
        font.family: Theme.fontFamily
        font.weight: Font.ExtraBold
        font.pixelSize: 15
        text: root.title
    }

    readonly property bool hello: kind === "hello"
    readonly property real helloLeft: Math.max(14, (width - (30 + 10 + titleMetrics.advanceWidth)) / 2)

    Item {
        id: icon
        x: root.hello ? root.helloLeft : 18
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28

        Face {
            anchors.centerIn: parent
            visible: root.kind === "hello"
            playing: root.kind === "hello"
            color: Theme.accent
        }

        ClippingRectangle {
            anchors.centerIn: parent
            visible: root.kind === "app"
            width: 30
            height: 30
            radius: 9
            color: "transparent"

            IconImage {
                anchors.fill: parent
                source: root.kind === "app" && root.notice.icon ? root.notice.icon : ""
            }
        }

        Eyes {
            anchors.centerIn: parent
            visible: root.kind === "timer"
            alarmed: root.kind === "timer"
            eyeWidth: 8
            eyeHeight: 17
            gap: 6
        }

        Item {
            anchors.centerIn: parent
            visible: root.kind === "clip"
            width: 16
            height: 19

            Rectangle {
                y: 2
                width: 16
                height: 17
                radius: 3
                color: "transparent"
                border.color: Theme.accent
                border.width: 1.6
            }

            Rectangle {
                x: 4
                width: 8
                height: 5
                radius: 1.5
                color: Theme.accent
            }
        }
    }

    ClippingRectangle {
        id: shot
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: root.kind === "shot"
        width: Math.min(64, Math.max(24, height * (thumb.implicitWidth > 0 ? thumb.implicitWidth / thumb.implicitHeight : 1.6)))
        height: 36
        radius: 7
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
        border.width: 1

        Image {
            id: thumb
            anchors.fill: parent
            source: root.kind === "shot" && root.notice.image ? root.notice.image : ""
            sourceSize.height: 72
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            opacity: status === Image.Ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
        }
    }

    Column {
        x: root.hello ? root.helloLeft + 40 : root.kind === "shot" ? shot.x + shot.width + 12 : 58
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - x - 16
        spacing: 1

        Text {
            textFormat: Text.PlainText
            font.family: Theme.fontFamily
            width: parent.width
            text: root.title.substring(0, root.typed)
            color: Theme.accent
            font.pixelSize: root.hello ? 15 : 14
            font.weight: Font.ExtraBold
            elide: Text.ElideRight
        }

        Text {
            textFormat: Text.PlainText
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            width: parent.width
            visible: text !== ""
            text: root.notice ? root.notice.subtitle : ""
            opacity: root.subtitleIn
            transform: Translate { y: (1 - root.subtitleIn) * 4 }
            color: Theme.dim
            font.pixelSize: 12
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
