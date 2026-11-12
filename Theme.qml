pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string fontFamily: Qt.application.font.family
    property color accent: "white"
    property color background: "black"
    property bool raiseVolume: false
    readonly property real maxVolume: raiseVolume ? 1.5 : 1
    readonly property color dim: Qt.rgba(accent.r, accent.g, accent.b, 0.7)
    readonly property color faint: Qt.rgba(accent.r, accent.g, accent.b, 0.48)
    readonly property var palette: ["#ffffff", "#e5484d", "#f5a524", "#76a043", "#4c8ef7", "#a07cf0"]
    readonly property var backgrounds: ["#000000", "#1c1c1e", "#0f1a2e", "#22090f", "#0b1a10", "#f2f2f2"]

    function setAccent(c) {
        accent = c;
        save();
    }

    function setBackground(c) {
        background = c;
        save();
    }

    function setRaiseVolume(on) {
        raiseVolume = on;
        save();
    }

    function save() {
        store.setText(JSON.stringify({ accent: accent.toString(), background: background.toString(), raiseVolume: raiseVolume }));
    }

    FileView {
        id: store
        path: Quickshell.statePath("theme.json")
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(store.text());
                if (saved.accent)
                    root.accent = saved.accent;
                if (saved.background)
                    root.background = saved.background;
                root.raiseVolume = saved.raiseVolume === true;
            } catch (e) {
                return;
            }
        }
    }

    Process {
        running: true
        command: ["kreadconfig6", "--group", "General", "--key", "font"]

        stdout: StdioCollector {
            id: collector
            onStreamFinished: {
                const family = collector.text.split(",")[0].trim();
                if (family !== "")
                    root.fontFamily = family;
            }
        }
    }
}
