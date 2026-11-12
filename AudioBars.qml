import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool active: false
    property var levels: []

    onActiveChanged: if (!active) levels = []

    Process {
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]
        running: root.active

        stdout: SplitParser {
            onRead: data => {
                const parts = data.split(";");
                const out = [];
                for (let i = 0; i < parts.length; i++) {
                    if (parts[i] !== "")
                        out.push(Math.min(1, parseInt(parts[i]) / 100));
                }
                if (out.length > 0 && root.active)
                    root.levels = out;
            }
        }
    }
}
