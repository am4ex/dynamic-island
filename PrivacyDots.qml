import QtQuick

Row {
    id: root

    property bool mic: false
    property bool screen: false

    spacing: 5
    visible: width > 0.5
    width: (mic || screen) ? implicitWidth : 0
    clip: true

    Behavior on width {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }

    Repeater {
        model: [{ on: root.screen, color: "#30d158" }, { on: root.mic, color: "#ff9f0a" }]

        Rectangle {
            required property var modelData
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            visible: modelData.on
            width: 9
            height: 9
            radius: 4.5
            color: modelData.color
            scale: modelData.on ? 1 : 0

            Behavior on scale {
                NumberAnimation { duration: 320; easing.type: Easing.OutBack }
            }
        }
    }
}
