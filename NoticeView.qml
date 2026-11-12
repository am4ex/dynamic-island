import QtQuick

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

    Column {
        x: root.hello ? root.helloLeft + 40 : 58
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - x - 16
        spacing: 1

        Text {
            font.family: Theme.fontFamily
            width: parent.width
            text: root.title.substring(0, root.typed)
            color: Theme.accent
            font.pixelSize: root.hello ? 15 : 14
            font.weight: Font.ExtraBold
            elide: Text.ElideRight
        }

        Text {
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
