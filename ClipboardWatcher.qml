import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    signal copied(string text)
    signal screenshot(string path)

    readonly property string klipperDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/klipper"

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
        onTriggered: latest.running = true
    }

    Process {
        id: latest
        command: ["sqlite3", "-readonly", root.klipperDir + "/history3.sqlite", "select m.uuid, m.mimetypes, ifnull(a.data_uuid, '') from main m left join aux a on a.uuid = m.uuid and a.mimetype = 'image/png' order by m.added_time desc limit 1"]

        stdout: StdioCollector {
            id: latestOut
            onStreamFinished: {
                const parts = latestOut.text.trim().split("|");
                if (parts.length === 3 && parts[2] !== "" && parts[1].indexOf("x-kde-suggestedfilename") >= 0)
                    root.screenshot(root.klipperDir + "/data/" + parts[0] + "/" + parts[2]);
                else
                    reader.running = true;
            }
        }
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
