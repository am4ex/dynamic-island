import QtQuick

Item {
    id: root

    property string title: ""

    Row {
        anchors.centerIn: parent
        spacing: 10

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 15

            Rectangle {
                anchors.fill: parent
                radius: 3.5
                color: "transparent"
                border.width: 1.8
                border.color: "white"
            }

            Grid {
                x: 4
                y: 3.5
                columns: 4
                spacing: 2
                Repeater {
                    model: 8
                    Rectangle { width: 2; height: 2; radius: 0.5; color: "white" }
                }
            }

            Rectangle {
                x: 6
                y: 10
                width: 10
                height: 1.8
                radius: 0.9
                color: "white"
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: "white"
            font.family: Theme.fontFamily
            font.weight: Font.ExtraBold
            font.pixelSize: 15
        }
    }
}
