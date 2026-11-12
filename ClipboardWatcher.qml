import QtQuick
import Quickshell.Io

Item {
    id: root

    signal copied(string text)

    Process {
        running: true
        command: ["dbus-monitor", "--session", "type='signal',interface='org.kde.klipper.klipper',member='clipboardHistoryUpdated'"]

        stdout: SplitParser {
            onRead: data => {
                if (data.indexOf("member=clipboardHistoryUpdated") >= 0)
                    debounce.restart();
            }
        }
    }

    Timer {
        id: debounce
        interval: 150
        onTriggered: reader.running = true
    }

    Process {
        id: reader
        command: ["qdbus6", "org.kde.klipper", "/klipper", "org.kde.klipper.klipper.getClipboardContents"]

        stdout: StdioCollector {
            id: collector
            onStreamFinished: root.copied(collector.text)
        }
    }
}
