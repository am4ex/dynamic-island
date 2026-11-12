import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        id: win

        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

        anchors.top: true
        margins.top: 0

        implicitWidth: 640
        implicitHeight: 360
        color: "transparent"

        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "dynamic-island"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Region {
            id: islandRegion
            item: island
        }

        Region {
            id: emptyRegion
        }

        mask: island.concealed ? emptyRegion : islandRegion

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
