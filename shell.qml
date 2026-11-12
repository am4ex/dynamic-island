import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        id: win

        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

        anchors.top: true
        margins.top: 0

        implicitWidth: 1240
        implicitHeight: 420
        color: "transparent"

        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "dynamic-island"
        WlrLayershell.keyboardFocus: island.wantsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        mask: Region {
            x: island.x
            y: island.y
            width: island.concealed ? 0 : island.width
            height: island.concealed ? 0 : island.height

            Region {
                readonly property Item card: island.leftCard
                x: island.x + (card ? card.x : 0)
                y: island.y + (card ? card.y : 0)
                width: card && card.visible && !island.concealed ? card.width : 0
                height: card && card.visible && !island.concealed ? card.height : 0
            }

            Region {
                readonly property Item card: island.rightCard
                x: island.x + (card ? card.x : 0)
                y: island.y + (card ? card.y : 0)
                width: card && card.visible && !island.concealed ? card.width : 0
                height: card && card.visible && !island.concealed ? card.height : 0
            }
        }

        Island {
            id: island
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            screenName: win.screen ? win.screen.name : ""
            screenTop: win.screen ? win.screen.y : 0
            globalOrigin: win.screen
                ? Qt.point(win.screen.x + (win.screen.width - win.width) / 2 + island.x, win.screen.y + island.y)
                : Qt.point(0, 0)
        }
    }
}
