import QtQuick

Item {
    id: root

    property string timeText: ""
    property string layoutBadge: ""
    property bool cursorKnown: false
    property point cursor: Qt.point(0, 0)
    property bool sleeping: false
    property bool pleased: false
    property int winkTrigger: 0
    property int surpriseTrigger: 0

    Eyes {
        id: eyes
        x: 22
        anchors.verticalCenter: parent.verticalCenter
        eyeWidth: 7
        eyeHeight: 15
        gap: 9
        tracking: root.cursorKnown
        sleeping: root.sleeping
        pleased: root.pleased
        winkTrigger: root.winkTrigger
        surpriseTrigger: root.surpriseTrigger
        lookX: Math.max(-1, Math.min(1, (root.cursor.x - (eyes.x + eyes.width / 2)) / 260))
        lookY: Math.max(-1, Math.min(1, (root.cursor.y - root.height / 2) / 140))
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        LayoutBadge {
            anchors.verticalCenter: parent.verticalCenter
            code: root.layoutBadge
        }

        Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.timeText
        color: Theme.accent
        font.family: Theme.fontFamily
        font.weight: Font.Bold
        font.pixelSize: 16
        font.features: { "tnum": 1 }
        }
    }
}
