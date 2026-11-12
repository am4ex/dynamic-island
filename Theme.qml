pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string fontFamily: Qt.application.font.family

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
