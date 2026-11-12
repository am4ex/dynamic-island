import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.SystemTray

Item {
    id: root

    property bool menuOpen: menuPopup.visible || palettePopup.visible
    property bool active: false
    property Item overlay: null
    property string activeClass: ""
    property string activeTitle: ""
    signal timerFinished(int minutes)
    readonly property int timerLeft: dashboard.timerLeft
    readonly property int timerTotal: dashboard.timerTotal
    signal historyViewed
    signal historyCleared
    property var notifHistory: []
    property int notifUnread: 0
    readonly property bool wantsKeyboard: dashboard.wantsKeyboard
    readonly property bool cardHovered: menuHover.hovered || paletteHover.hovered

    Component.onCompleted: {
        if (overlay) {
            overlay.leftCard = menuPopup;
            overlay.rightCard = palettePopup;
        }
    }

    onActiveChanged: {
        if (!active) {
            menuPopup.visible = false;
            palettePopup.visible = false;
        }
    }

    HomeDashboard {
        id: dashboard
        width: root.width
        height: trayRow.y - 14
        active: root.active
        activeClass: root.activeClass
        activeTitle: root.activeTitle
        onTimerFinished: minutes => root.timerFinished(minutes)
        notifHistory: root.notifHistory
        notifUnread: root.notifUnread
        onHistoryViewed: root.historyViewed()
        onHistoryCleared: root.historyCleared()
    }

    Rectangle {
        x: 16
        y: trayRow.y - 9
        width: root.width - 32
        height: 1
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.07)
    }

    Row {
        id: trayRow
        x: 12
        y: root.height - 38
        height: 30
        spacing: 2

        Repeater {
            model: SystemTray.items.values

            Item {
                id: trayButton
                required property SystemTrayItem modelData

                width: 30
                height: 30

                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: Theme.accent
                    opacity: trayArea.pressed ? 0.2 : trayArea.containsMouse ? 0.1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 18
                    source: trayButton.modelData.icon
                }

                MouseArea {
                    id: trayArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: mouse => {
                        const item = trayButton.modelData;
                        if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                            if (item.hasMenu)
                                root.openMenu(trayButton, item);
                        } else {
                            item.activate();
                        }
                    }

                    onWheel: wheel => trayButton.modelData.scroll(wheel.angleDelta.y, false)
                }
            }
        }
    }

    readonly property bool paletteOpen: palettePopup.visible


    component Swatch: Rectangle {
        id: swatch
        property color value
        property bool selected: false
        signal picked

        width: 20
        height: 20
        radius: 10
        color: value
        border.width: selected ? 2.5 : 1
        border.color: selected ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
        scale: swatchArea.containsMouse ? 1.15 : 1

        Behavior on scale {
            NumberAnimation { duration: 120 }
        }

        MouseArea {
            id: swatchArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: swatch.picked()
        }
    }

    Item {
        id: palettePopup
        parent: root.overlay
        visible: false
        x: (root.overlay ? root.overlay.width : 0) - 2
        y: -6
        width: 268
        height: 102
        onVisibleChanged: if (visible) palettePop.restart()

        HoverHandler {
            id: paletteHover
        }

        Item {
            id: paletteCard
            anchors.fill: parent
            property real pourX: 1
            property real pourY: 1
            transform: Scale {
                origin.x: 0
                origin.y: 24
                xScale: paletteCard.pourX
                yScale: paletteCard.pourY
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

            Column {
                id: paletteColumn
                x: 22
                y: 20
                spacing: 10

                Row {
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        text: "Текст"
                        color: Theme.dim
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: 12
                    }

                    Repeater {
                        model: Theme.palette

                        Swatch {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            value: modelData
                            selected: Qt.colorEqual(Theme.accent, modelData)
                            onPicked: Theme.setAccent(modelData)
                        }
                    }
                }

                Row {
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        text: "Фон"
                        color: Theme.dim
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: 12
                    }

                    Repeater {
                        model: Theme.backgrounds

                        Swatch {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            value: modelData
                            selected: Qt.colorEqual(Theme.background, modelData)
                            onPicked: Theme.setBackground(modelData)
                        }
                    }
                }
            }
        }

        ParallelAnimation {
            id: palettePop
            NumberAnimation { target: paletteCard; property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: paletteCard; property: "pourX"; from: 0.08; to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
            SequentialAnimation {
                PropertyAction { target: paletteCard; property: "pourY"; value: 0.18 }
                PauseAnimation { duration: 120 }
                NumberAnimation { target: paletteCard; property: "pourY"; to: 1; duration: 620; easing.type: Easing.OutElastic; easing.amplitude: 1.05; easing.period: 0.45 }
            }
        }
    }

    Item {
        id: themeButton
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: trayRow.y
        width: 30
        height: 30

        Rectangle {
            anchors.fill: parent
            radius: 9
            color: Theme.accent
            opacity: themeArea.pressed ? 0.2 : themeArea.containsMouse || root.paletteOpen ? 0.1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 16
            height: 16
            radius: 8
            color: "transparent"
            border.width: 1.8
            border.color: Theme.dim

            Item {
                x: 3
                y: 3
                width: 5
                height: 10
                clip: true

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: Theme.accent
                }
            }
        }

        MouseArea {
            id: themeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: palettePopup.visible = !palettePopup.visible
        }
    }

    function openMenu(button, item) {
        trayMenu.show(item.menu, item.tooltipTitle || item.title || item.id);
        if (menuPopup.visible)
            swapAnim.restart();
        if (!menuPopup.visible)
            menuPopup.visible = true;
    }

    Item {
        id: menuPopup
        parent: root.overlay
        visible: false
        x: -width + 2
        y: -6
        width: 262
        height: Math.min(440, Math.max(60, trayMenu.naturalHeight))
        onVisibleChanged: if (visible) popAnim.restart()

        HoverHandler {
            id: menuHover
        }

        TrayMenu {
            id: trayMenu
            anchors.fill: parent
            onDone: menuPopup.visible = false
            property real pourX: 1
            property real pourY: 1
            transform: Scale {
                origin.x: trayMenu.width
                origin.y: 24
                xScale: trayMenu.pourX
                yScale: trayMenu.pourY
            }
        }

        ParallelAnimation {
            id: popAnim
            NumberAnimation { target: trayMenu; property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: trayMenu; property: "pourX"; from: 0.08; to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
            SequentialAnimation {
                PropertyAction { target: trayMenu; property: "pourY"; value: 0.18 }
                PauseAnimation { duration: 120 }
                NumberAnimation { target: trayMenu; property: "pourY"; to: 1; duration: 620; easing.type: Easing.OutElastic; easing.amplitude: 1.05; easing.period: 0.45 }
            }
        }

        NumberAnimation {
            id: swapAnim
            target: trayMenu
            property: "opacity"
            from: 0.3
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }
    }
}
