import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property var handle: null
    property string title: ""
    property var stack: []
    readonly property var current: stack.length > 0 ? stack[stack.length - 1] : handle
    readonly property real naturalHeight: header.y + header.height + 4 + entries.height + 14

    signal done

    function show(menu, name) {
        stack = [];
        handle = menu;
        title = name;
    }

    function clean(text) {
        return (text || "").replace(/&&/g, "\u0001").replace(/&/g, "").replace(/\u0001/g, "&");
    }

    QsMenuOpener {
        id: opener
        menu: root.current
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        radius: 22
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

    Item {
        id: header
        x: 16
        y: 14
        width: root.width - 32
        height: 26

        Item {
            id: back
            visible: root.stack.length > 0
            width: visible ? 26 : 0
            height: 26

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: Theme.accent
                opacity: backArea.containsMouse ? 0.1 : 0
            }

            Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: "‹"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.pixelSize: 18
            }

            MouseArea {
                id: backArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.stack = root.stack.slice(0, -1)
            }
        }

        Text {
            textFormat: Text.PlainText
            x: back.width + 6
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 32
            text: root.stack.length > 0 ? root.clean(root.stack[root.stack.length - 1].text) : root.title
            color: Theme.dim
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 12
        }

        Item {
            anchors.right: parent.right
            width: 26
            height: 26

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: Theme.accent
                opacity: closeArea.containsMouse ? 0.1 : 0
            }

            Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: "×"
                color: Theme.dim
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.pixelSize: 16
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.done()
            }
        }
    }

    Flickable {
        x: 12
        y: header.y + header.height + 4
        width: root.width - 24
        height: root.height - y - 14
        clip: true
        contentHeight: entries.height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: entries
            width: parent.width

            Repeater {
                model: opener.children ? opener.children.values : []

                Item {
                    id: row
                    required property var modelData

                    width: entries.width
                    height: modelData.isSeparator ? 9 : 30

                    Rectangle {
                        visible: row.modelData.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        width: parent.width - 16
                        height: 1
                        color: "#1affffff"
                    }

                    Rectangle {
                        visible: !row.modelData.isSeparator
                        anchors.fill: parent
                        radius: 14
                        color: Theme.accent
                        opacity: rowArea.pressed ? 0.16 : rowArea.containsMouse ? 0.09 : 0
                    }

                    Row {
                        visible: !row.modelData.isSeparator
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        opacity: row.modelData.enabled ? 1 : 0.4

                        Item {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter

                            IconImage {
                                anchors.fill: parent
                                visible: row.modelData.icon !== ""
                                source: row.modelData.icon
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                visible: row.modelData.icon === "" && row.modelData.buttonType !== 0
                                width: 14
                                height: 14
                                radius: row.modelData.buttonType === 2 ? 7 : 4
                                color: row.modelData.checkState === Qt.Checked ? "#76a043" : "transparent"
                                border.width: 1.6
                                border.color: row.modelData.checkState === Qt.Checked ? "#76a043" : Theme.faint
                            }
                        }

                        Text {
                            textFormat: Text.PlainText
                            anchors.verticalCenter: parent.verticalCenter
                            width: row.width - 70
                            text: root.clean(row.modelData.text)
                            color: Theme.accent
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: 13
                        }
                    }

                    Text {
                        textFormat: Text.PlainText
                        visible: row.modelData.hasChildren
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: 16
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        enabled: !row.modelData.isSeparator && row.modelData.enabled
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (row.modelData.hasChildren) {
                                root.stack = root.stack.concat([row.modelData]);
                            } else {
                                row.modelData.triggered();
                                root.done();
                            }
                        }
                    }
                }
            }
        }
    }
}
