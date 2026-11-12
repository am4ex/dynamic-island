import QtQuick

Rectangle {
    id: root

    property string code: ""

    visible: code !== ""
    width: label.implicitWidth + 10
    height: 18
    radius: 5
    color: "transparent"
    border.width: 1.4
    border.color: "#6a6a6a"

    Text {
        id: label
        anchors.centerIn: parent
        text: root.code
        color: Theme.dim
        font.family: Theme.fontFamily
        font.weight: Font.ExtraBold
        font.pixelSize: 11
    }
}
