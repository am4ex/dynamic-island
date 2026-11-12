import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool active: true
    property bool known: false
    property real globalX: 0
    property real globalY: 0
    property var fullscreenOutputs: []
    property string layoutCode: ""
    property string layoutName: ""
    property bool layoutKnown: false

    signal moved
    signal layoutSwitched

    Process {
        command: ["python3", "-I", Quickshell.shellPath("cursor_bridge.py")]
        running: root.active

        stdout: SplitParser {
            onRead: data => {
                if (data.startsWith("L ")) {
                    const body = data.slice(2);
                    const sep = body.indexOf("|");
                    const code = sep >= 0 ? body.slice(0, sep) : body;
                    const name = sep >= 0 ? body.slice(sep + 1) : body;
                    const changed = root.layoutKnown && code !== root.layoutCode;
                    root.layoutCode = code;
                    root.layoutName = name;
                    root.layoutKnown = true;
                    if (changed)
                        root.layoutSwitched();
                    return;
                }
                if (data.startsWith("F")) {
                    const rest = data.slice(1).trim();
                    root.fullscreenOutputs = rest === "" ? [] : rest.split(",");
                    return;
                }
                const parts = data.split(" ");
                if (parts.length !== 2)
                    return;
                root.globalX = parseInt(parts[0]);
                root.globalY = parseInt(parts[1]);
                root.known = true;
                root.moved();
            }
        }
    }
}
