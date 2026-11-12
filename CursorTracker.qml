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
    property var strictFullscreenOutputs: []
    property string layoutCode: ""
    property string layoutName: ""
    property bool layoutKnown: false
    property string activeClass: ""
    property string activeTitle: ""

    signal moved
    signal appsRequested
    signal windowsChanged
    signal layoutSwitched
    signal activationResult(bool found)

    function activateApp(entry, word) {
        bridge.write("activate\t" + (entry || "").replace(/\s/g, "") + "\t" + (word || "").replace(/\s/g, "") + "\n");
    }

    Process {
        id: bridge
        stdinEnabled: true
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
                if (data.startsWith("W ")) {
                    const body = data.slice(2);
                    const tab = body.indexOf("\t");
                    root.activeClass = tab >= 0 ? body.slice(0, tab) : body;
                    root.activeTitle = tab >= 0 ? body.slice(tab + 1) : "";
                    return;
                }
                if (data.startsWith("R ")) {
                    root.activationResult(data === "R 1");
                    return;
                }
                if (data === "A") {
                    root.appsRequested();
                    return;
                }
                if (data.startsWith("F")) {
                    root.windowsChanged();
                    const rest = data.slice(1).trim();
                    const list = rest === "" ? [] : rest.split(",");
                    root.fullscreenOutputs = list.map(n => n.replace("!", ""));
                    root.strictFullscreenOutputs = list.filter(n => n.endsWith("!")).map(n => n.replace("!", ""));
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
