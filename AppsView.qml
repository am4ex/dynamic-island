import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Item {
    id: root

    property bool active: false
    property string query: ""
    property int selected: 0
    property var usage: ({})
    property var kdeScores: ({})

    readonly property int columns: 6
    readonly property real cellWidth: (width - 44) / columns
    property bool showAll: false
    readonly property bool searching: query.trim() !== ""

    signal launched
    signal closeRequested

    function focusSearch() {
        search.forceActiveFocus();
    }

    function popularity(e) {
        return (kdeScores[e.id] || 0) + (usage[e.id] || 0) * 10;
    }

    function score(entry, q) {
        const name = (entry.name || "").toLowerCase();
        if (name.startsWith(q))
            return 100;
        const words = name.split(/[\s\-_.]+/);
        for (let i = 0; i < words.length; i++) {
            if (words[i].startsWith(q))
                return 80;
        }
        if (name.indexOf(q) >= 0)
            return 60;
        const extra = [(entry.genericName || ""), (entry.comment || "")].concat(entry.keywords || []).join(" ").toLowerCase();
        if (extra.indexOf(q) >= 0)
            return 30;
        return 0;
    }

    readonly property var visibleApps: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (q === "")
            return [];
        const out = [];
        for (let i = 0; i < visibleApps.length; i++) {
            const e = visibleApps[i];
            const s = score(e, q);
            if (s > 0)
                out.push({ entry: e, score: s + Math.min(25, popularity(e) / 10) });
        }
        out.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
        return out.map(x => x.entry);
    }

    readonly property var topApps: {
        const list = visibleApps.slice();
        list.sort((a, b) => popularity(b) - popularity(a) || a.name.localeCompare(b.name));
        return list.slice(0, columns * 2 - 1);
    }

    readonly property var groupDefs: [
        { key: "net", label: "Интернет", cats: ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging"] },
        { key: "games", label: "Игры", cats: ["Game"] },
        { key: "media", label: "Медиа и графика", cats: ["AudioVideo", "Audio", "Video", "Graphics", "Player"] },
        { key: "dev", label: "Разработка", cats: ["Development", "IDE"] },
        { key: "office", label: "Офис", cats: ["Office"] },
        { key: "system", label: "Система", cats: ["System", "Settings", "Monitor", "PackageManager"] },
        { key: "utils", label: "Утилиты", cats: [] }
    ]

    function groupOf(e) {
        const cats = e.categories || [];
        for (let g = 0; g < groupDefs.length - 1; g++) {
            for (let c = 0; c < groupDefs[g].cats.length; c++) {
                if (cats.indexOf(groupDefs[g].cats[c]) >= 0)
                    return groupDefs[g].key;
            }
        }
        return "utils";
    }

    readonly property var groups: {
        const buckets = {};
        for (let i = 0; i < visibleApps.length; i++) {
            const k = groupOf(visibleApps[i]);
            (buckets[k] = buckets[k] || []).push(visibleApps[i]);
        }
        const out = [];
        for (let g = 0; g < groupDefs.length; g++) {
            const list = buckets[groupDefs[g].key];
            if (!list)
                continue;
            list.sort((a, b) => a.name.localeCompare(b.name));
            out.push({ label: groupDefs[g].label, apps: list });
        }
        return out;
    }

    readonly property var allApps: {
        let out = [];
        for (let g = 0; g < groups.length; g++)
            out = out.concat(groups[g].apps);
        return out;
    }

    readonly property var navList: searching ? results : showAll ? allApps : topApps

    onQueryChanged: selected = 0
    onShowAllChanged: selected = 0
    onActiveChanged: {
        if (active) {
            query = "";
            showAll = false;
            selected = 0;
            kdeReader.running = true;
            focusSearch();
        }
    }

    function launch(entry) {
        if (!entry)
            return;
        const u = Object.assign({}, usage);
        u[entry.id] = (u[entry.id] || 0) + 1;
        usage = u;
        usageStore.setText(JSON.stringify(u));
        entry.execute();
        launched();
    }

    FileView {
        id: usageStore
        path: Quickshell.statePath("apps.json")
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.usage = JSON.parse(usageStore.text()) || {};
            } catch (e) {
                root.usage = {};
            }
        }
    }

    Process {
        id: kdeReader
        command: ["sqlite3", "-readonly", "-separator", "\t", Quickshell.env("HOME") + "/.local/share/kactivitymanagerd/resources/database",
            "SELECT targettedResource, cachedScore FROM ResourceScoreCache WHERE targettedResource LIKE 'applications:%' ORDER BY cachedScore DESC LIMIT 200"]

        stdout: StdioCollector {
            id: kdeOut
            onStreamFinished: {
                const map = {};
                const rows = kdeOut.text.split("\n");
                for (let i = 0; i < rows.length; i++) {
                    const parts = rows[i].split("\t");
                    if (parts.length !== 2)
                        continue;
                    const id = parts[0].replace(/^applications:/, "").replace(/\.desktop$/, "");
                    map[id] = (map[id] || 0) + (parseFloat(parts[1]) || 0);
                }
                root.kdeScores = map;
            }
        }
    }

    component AppCell: Item {
        id: cell
        property var entry
        property bool current: false
        property real iconSize: 40
        signal picked

        width: root.cellWidth
        height: iconSize + 42

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 18
            color: Theme.accent
            opacity: cell.current ? 0.1 : cellArea.containsMouse ? 0.06 : 0

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
        }

        IconImage {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            implicitSize: cell.iconSize
            source: cell.entry ? Quickshell.iconPath(cell.entry.icon, "application-x-executable") : ""
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: cell.iconSize + 18
            width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter
            text: cell.entry ? cell.entry.name : ""
            elide: Text.ElideRight
            color: cell.current ? Theme.accent : Theme.faint
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 12
        }

        MouseArea {
            id: cellArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cell.picked()
        }
    }

    component ModeButton: Item {
        id: mode
        property string label
        property bool chosen: false
        signal picked

        width: modeText.implicitWidth + 20
        height: 26

        Rectangle {
            anchors.fill: parent
            radius: 13
            color: Theme.accent
            opacity: mode.chosen ? 0.12 : modeArea.containsMouse ? 0.06 : 0
        }

        Text {
            id: modeText
            anchors.centerIn: parent
            text: mode.label
            color: mode.chosen ? Theme.accent : Theme.faint
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 12
        }

        MouseArea {
            id: modeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mode.picked()
        }
    }

    Item {
        id: searchBox
        x: 22
        y: 2
        width: root.width - 44
        height: 34

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14

            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: "transparent"
                border.width: 1.8
                border.color: Theme.faint
            }

            Rectangle {
                x: 8.5
                y: 8.5
                width: 6
                height: 1.8
                radius: 0.9
                rotation: 45
                transformOrigin: Item.Left
                color: Theme.faint
            }
        }

        TextInput {
            id: search
            x: 26
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 26 - modes.width - 10
            text: root.query
            onTextChanged: root.query = text
            color: Theme.accent
            selectionColor: Theme.faint
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 15
            clip: true

            Keys.onPressed: event => {
                const n = root.navList.length;
                if (event.key === Qt.Key_Escape) {
                    if (root.showAll && !root.searching)
                        root.showAll = false;
                    else
                        root.closeRequested();
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.launch(root.navList[root.selected]);
                } else if (event.key === Qt.Key_Tab && !root.searching) {
                    root.showAll = !root.showAll;
                } else if (event.key === Qt.Key_Right && n > 0) {
                    root.selected = Math.min(n - 1, root.selected + 1);
                } else if (event.key === Qt.Key_Left && n > 0) {
                    root.selected = Math.max(0, root.selected - 1);
                } else if (event.key === Qt.Key_Down && n > 0) {
                    root.selected = Math.min(n - 1, root.selected + root.columns);
                } else if (event.key === Qt.Key_Up && n > 0) {
                    root.selected = Math.max(0, root.selected - root.columns);
                } else {
                    return;
                }
                event.accepted = true;
            }
        }

        Text {
            x: search.x
            anchors.verticalCenter: parent.verticalCenter
            visible: root.query === ""
            text: "Поиск"
            color: Theme.faint
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 15
        }

        Row {
            id: modes
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: !root.searching

            ModeButton {
                label: "Частые"
                chosen: !root.showAll
                onPicked: root.showAll = false
            }

            ModeButton {
                label: "Все"
                chosen: root.showAll
                onPicked: root.showAll = true
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.1)
        }
    }

    Grid {
        id: topGrid
        x: 22
        y: searchBox.y + searchBox.height + 10
        columns: root.columns
        rowSpacing: 2
        visible: !root.searching && !root.showAll

        Repeater {
            model: root.active ? root.topApps : []

            AppCell {
                required property var modelData
                required property int index
                iconSize: Math.max(40, (root.height - topGrid.y - 8) / 2 - 44)
                entry: modelData
                current: root.selected === index
                onPicked: root.launch(modelData)
            }
        }

        Item {
            width: root.cellWidth
            height: Math.max(40, (root.height - topGrid.y - 8) / 2 - 44) + 42

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 18
                color: Theme.accent
                opacity: allArea.containsMouse ? 0.06 : 0
            }

            Row {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -8
                spacing: 5
                Repeater {
                    model: 3
                    Rectangle { width: 6; height: 6; radius: 3; color: Theme.dim }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                text: "Все"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.pixelSize: 12
            }

            MouseArea {
                id: allArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.showAll = true
            }
        }
    }

    Flickable {
        x: 22
        y: searchBox.y + searchBox.height + 8
        width: root.width - 44
        height: root.height - y - 6
        visible: root.showAll && !root.searching
        contentHeight: groupLoader.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Loader {
            id: groupLoader
            width: parent.width
            active: root.active && root.showAll && !root.searching
            sourceComponent: groupComponent
        }
    }

    Component {
        id: groupComponent

        Column {
            id: groupColumn
            width: groupLoader.width
            spacing: 6

            Repeater {
                model: root.groups

                Column {
                    required property var modelData
                    width: groupColumn.width

                    Text {
                        leftPadding: 8
                        topPadding: 6
                        bottomPadding: 2
                        text: parent.modelData.label
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.weight: Font.ExtraBold
                        font.pixelSize: 12
                    }

                    Grid {
                        columns: root.columns

                        Repeater {
                            model: parent.parent.modelData.apps

                            AppCell {
                                required property var modelData
                                iconSize: 44
                                entry: modelData
                                current: root.navList[root.selected] === modelData
                                onPicked: root.launch(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    Flickable {
        x: 22
        y: searchBox.y + searchBox.height + 10
        width: root.width - 44
        height: root.height - y - 6
        visible: root.searching
        contentHeight: root.searching ? resultGrid.height : 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Grid {
            id: resultGrid
            columns: root.columns

            Repeater {
                model: root.searching ? root.results : []

                AppCell {
                    required property var modelData
                    required property int index
                    iconSize: 44
                    entry: modelData
                    current: root.selected === index
                    onPicked: root.launch(modelData)
                }
            }
        }

        Text {
            x: (parent.width - width) / 2
            y: 40
            visible: root.results.length === 0
            text: "Ничего не найдено"
            color: Theme.faint
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 13
        }
    }
}
