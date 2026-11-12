import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Pipewire

Item {
    id: root

    property bool active: false
    property string activeClass: ""
    property string activeTitle: ""

    property var clipItems: []
    property real cpu: 0
    property real ram: 0
    property real ramUsed: 0
    property real ramTotal: 0
    property bool clipPanel: false
    property real cpuTemp: 0
    property real gpu: 0
    property real gpuTemp: 0
    property var lastCpu: null
    property bool wifiOn: false
    property string wifiName: ""
    property int updates: -1
    property bool choosingTimer: false
    property int timerTotal: 0
    property int timerLeft: 0
    readonly property bool timerRunning: timerLeft > 0

    signal timerFinished(int minutes)

    property var notifHistory: []
    property int notifUnread: 0
    signal historyViewed
    signal historyCleared
    property bool historyPanel: false

    onHistoryPanelChanged: {
        if (historyPanel) {
            wifiPanel = false;
            clipPanel = false;
            historyViewed();
        }
    }

    property bool wifiPanel: false
    property var networks: []
    property var savedNets: []
    property bool scanning: false
    property string wifiStatus: ""
    property string passwordFor: ""
    property bool customTimer: false
    readonly property bool wantsKeyboard: passwordFor !== "" || customTimer

    onClipPanelChanged: {
        if (clipPanel) {
            wifiPanel = false;
            historyPanel = false;
            clipReader.running = true;
        }
    }

    onChoosingTimerChanged: if (!choosingTimer) customTimer = false

    function startTimer(seconds) {
        if (seconds > 0) {
            timerTotal = seconds;
            timerLeft = seconds;
        }
        choosingTimer = false;
    }

    onWifiPanelChanged: {
        if (wifiPanel) {
            historyPanel = false;
            clipPanel = false;
        }
        passwordFor = "";
        wifiStatus = "";
        if (wifiPanel) {
            scanning = true;
            netScanner.running = true;
            savedReader.running = true;
        }
    }

    function splitEscaped(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) {
                cur += line[i + 1];
                i++;
            } else if (c === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }
        out.push(cur);
        return out;
    }

    function connectTo(net, password) {
        wifiStatus = "Подключение к " + net.ssid + "…";
        let cmd;
        if (savedNets.indexOf(net.ssid) >= 0 && !password)
            cmd = ["nmcli", "con", "up", "id", net.ssid];
        else if (password)
            cmd = ["nmcli", "dev", "wifi", "connect", net.ssid, "password", password];
        else
            cmd = ["nmcli", "dev", "wifi", "connect", net.ssid];
        netAction.command = cmd;
        netAction.running = true;
        passwordFor = "";
    }

    function pick(net) {
        if (net.inUse) {
            wifiStatus = "Отключение…";
            netAction.command = ["nmcli", "con", "down", "id", net.ssid];
            netAction.running = true;
        } else if (net.secure && savedNets.indexOf(net.ssid) < 0) {
            passwordFor = net.ssid;
        } else {
            connectTo(net, "");
        }
    }

    Process {
        id: netScanner
        command: ["nmcli", "-t", "-e", "yes", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "yes"]
        stdout: StdioCollector {
            id: netOut
            onStreamFinished: {
                const best = {};
                const lines = netOut.text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].trim() === "")
                        continue;
                    const f = root.splitEscaped(lines[i]);
                    const ssid = f[1] || "";
                    if (ssid === "")
                        continue;
                    const net = { ssid: ssid, inUse: f[0] === "*", signal: parseInt(f[2]) || 0, secure: (f[3] || "") !== "" && f[3] !== "--" };
                    if (!best[ssid] || net.inUse || net.signal > best[ssid].signal)
                        best[ssid] = net;
                }
                const list = Object.keys(best).map(k => best[k]);
                list.sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal));
                root.networks = list;
                root.scanning = false;
            }
        }
    }

    Process {
        id: savedReader
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "con", "show"]
        stdout: StdioCollector {
            id: savedOut
            onStreamFinished: {
                const names = [];
                const lines = savedOut.text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const f = root.splitEscaped(lines[i]);
                    if (f[1] === "802-11-wireless")
                        names.push(f[0]);
                }
                root.savedNets = names;
            }
        }
    }

    Process {
        id: netAction
        stderr: StdioCollector {
            id: netErr
        }
        onExited: code => {
            root.wifiStatus = code === 0 ? "" : "Не получилось подключиться";
            wifiReader.running = true;
            netScanner.running = true;
            savedReader.running = true;
        }
    }

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool sinkReady: sink !== null && sink.ready && sink.audio !== null
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio !== null)

    function tint(a) {
        return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, a);
    }

    function fmt(sec) {
        const m = Math.floor(sec / 60);
        return m + ":" + String(sec % 60).padStart(2, "0");
    }

    Component.onCompleted: wifiReader.running = true

    onActiveChanged: {
        if (active) {
            clipReader.running = true;
            wifiReader.running = true;
            loadReader.running = true;
        } else {
            choosingTimer = false;
            wifiPanel = false;
            historyPanel = false;
            clipPanel = false;
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Process {
        id: clipReader
        command: ["busctl", "--user", "--json=short", "call", "org.kde.klipper", "/klipper", "org.kde.klipper.klipper", "getClipboardHistoryMenu"]
        stdout: StdioCollector {
            id: clipOut
            onStreamFinished: {
                try {
                    const list = JSON.parse(clipOut.text).data[0] || [];
                    root.clipItems = list.filter(t => t.trim() !== "").slice(0, 4);
                } catch (e) {
                    root.clipItems = [];
                }
            }
        }
    }

    Process {
        id: clipWriter
        property string value: ""
        command: ["qdbus6", "org.kde.klipper", "/klipper", "org.kde.klipper.klipper.setClipboardContents", value]
    }

    Process {
        id: wifiReader
        command: ["sh", "-c", "nmcli radio wifi; nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes' | head -1 | cut -d: -f2-"]
        stdout: StdioCollector {
            id: wifiOut
            onStreamFinished: {
                const lines = wifiOut.text.split("\n");
                root.wifiOn = (lines[0] || "").trim() === "enabled";
                root.wifiName = (lines[1] || "").trim();
            }
        }
    }

    Process {
        id: wifiToggle
        command: ["nmcli", "radio", "wifi", root.wifiOn ? "off" : "on"]
        onExited: wifiDelay.restart()
    }

    Timer {
        id: wifiDelay
        interval: 1500
        onTriggered: wifiReader.running = true
    }

    Process {
        id: loadReader
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name); case $n in k10temp|coretemp|zenpower) echo C $(cat $h/temp1_input);; amdgpu|radeon|nouveau) echo G $(cat $h/temp1_input);; esac; done; echo B $(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)"]
        stdout: StdioCollector {
            id: loadOut
            onStreamFinished: {
                let memTotal = 0, memAvail = 0, cpuTempSet = false, gpuTempSet = false;
                const lines = loadOut.text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const p = lines[i].trim().split(/\s+/);
                    if (p[0] === "cpu") {
                        const v = p.slice(1).map(Number);
                        const idle = v[3] + (v[4] || 0);
                        const total = v.reduce((a, b) => a + b, 0);
                        if (root.lastCpu) {
                            const dt = total - root.lastCpu.total;
                            const di = idle - root.lastCpu.idle;
                            if (dt > 0)
                                root.cpu = Math.round(100 * (1 - di / dt));
                        }
                        root.lastCpu = { total: total, idle: idle };
                    } else if (p[0] === "MemTotal:") {
                        memTotal = Number(p[1]);
                    } else if (p[0] === "MemAvailable:") {
                        memAvail = Number(p[1]);
                    } else if (p[0] === "C" && !cpuTempSet && p[1]) {
                        root.cpuTemp = Math.round(Number(p[1]) / 1000);
                        cpuTempSet = true;
                    } else if (p[0] === "G" && !gpuTempSet && p[1]) {
                        root.gpuTemp = Math.round(Number(p[1]) / 1000);
                        gpuTempSet = true;
                    } else if (p[0] === "B" && p[1]) {
                        root.gpu = Number(p[1]);
                    }
                }
                if (memTotal > 0) {
                    root.ram = Math.round(100 * (1 - memAvail / memTotal));
                    root.ramUsed = (memTotal - memAvail) / 1048576;
                    root.ramTotal = memTotal / 1048576;
                }
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        onTriggered: loadReader.running = true
    }

    Process {
        id: updateReader
        running: true
        command: ["sh", "-c", "a=$(checkupdates 2>/dev/null | wc -l); b=$(yay -Qua 2>/dev/null | wc -l); echo $((a + b))"]
        stdout: StdioCollector {
            id: updateOut
            onStreamFinished: root.updates = parseInt(updateOut.text) || 0
        }
    }

    Timer {
        interval: 2 * 60 * 60 * 1000
        repeat: true
        running: true
        onTriggered: updateReader.running = true
    }

    Process {
        id: updateRunner
        command: ["konsole", "-e", "sh", "-c", "yay; echo; read -p 'Enter, чтобы закрыть' x"]
        onExited: updateReader.running = true
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.timerRunning
        onTriggered: {
            root.timerLeft -= 1;
            if (root.timerLeft <= 0)
                root.timerFinished(Math.round(root.timerTotal / 60));
        }
    }

    component RoundButton: Item {
        id: btn
        property bool on: false
        property string badge: ""
        default property alias icon: iconBox.data
        signal clicked

        width: 40
        height: 40

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: btn.on ? Theme.accent : root.tint(btnArea.containsMouse ? 0.14 : 0.08)

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }

        Item {
            id: iconBox
            anchors.centerIn: parent
            width: 18
            height: 18
        }

        Rectangle {
            visible: btn.badge !== ""
            x: parent.width - width + 4
            y: -4
            width: Math.max(18, badgeText.implicitWidth + 10)
            height: 16
            radius: 8
            color: Theme.accent

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: btn.badge
                color: Theme.background
                font.family: Theme.fontFamily
                font.weight: Font.ExtraBold
                font.pixelSize: 10
            }
        }

        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 22
        y: -33
        spacing: 6
        visible: root.activeTitle !== "" || root.activeClass !== ""

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 260)
            text: root.activeTitle || root.activeClass
            elide: Text.ElideRight
            color: Theme.faint
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 12
        }
    }

    Item {
        x: 22
        y: 6
        width: 210
        height: 90

        Row {
            id: timeRow
            spacing: 6

            Text {
                id: bigTime
                text: Qt.formatDateTime(clock.date, "h:mm AP").split(" ")[0]
                color: Theme.accent
                font.family: Theme.fontFamily
                font.weight: Font.ExtraBold
                font.pixelSize: 52
                font.features: { "tnum": 1 }
            }

            Text {
                anchors.baseline: bigTime.baseline
                text: Qt.formatDateTime(clock.date, "AP")
                color: Theme.faint
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.pixelSize: 16
            }
        }

        Text {
            y: timeRow.height + 2
            text: {
                const s = clock.date.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM");
                return s.charAt(0).toUpperCase() + s.slice(1);
            }
            color: Theme.dim
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 13
        }
    }

    Row {
        x: 292
        y: 14
        width: root.width - x - 22
        visible: !root.wifiPanel && !root.historyPanel && !root.clipPanel

        Repeater {
            model: [
                { label: "CPU", value: root.cpu + "%", sub: root.cpuTemp + "°" },
                { label: "GPU", value: Math.round(root.gpu) + "%", sub: root.gpuTemp + "°" },
                { label: "ОЗУ", value: root.ram + "%", sub: root.ramUsed.toFixed(1) + " / " + Math.round(root.ramTotal) + " ГБ" }
            ]

            Column {
                required property var modelData
                width: parent.width / 3
                spacing: 1

                Text {
                    text: modelData.label
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: 11
                }

                Text {
                    text: modelData.value
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.weight: Font.ExtraBold
                    font.pixelSize: 26
                    font.features: { "tnum": 1 }
                }

                Text {
                    text: modelData.sub
                    color: Theme.dim
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: 12
                    font.features: { "tnum": 1 }
                }
            }
        }
    }

    Column {
        x: 292
        y: 10
        width: root.width - x - 22
        spacing: 2
        visible: root.clipPanel

        Text {
            text: "Скопировано"
            color: Theme.faint
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 11
            bottomPadding: 4
        }

        Repeater {
            model: root.clipItems.slice(0, 3)

            Item {
                id: clipRow
                required property var modelData
                required property int index
                width: parent.width
                height: 24

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: -8
                    radius: 8
                    color: Theme.accent
                    opacity: clipArea.containsMouse ? 0.08 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 8
                    text: clipRow.modelData.replace(/\s+/g, " ").trim()
                    elide: Text.ElideRight
                    color: clipRow.index === 0 ? Theme.accent : Theme.dim
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: 13
                }

                MouseArea {
                    id: clipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        clipWriter.value = clipRow.modelData;
                        clipWriter.running = true;
                    }
                }
            }
        }

        Text {
            visible: root.clipItems.length === 0
            text: "Пока пусто"
            color: Theme.faint
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 13
        }
    }

    Item {
        x: 292
        y: 4
        width: root.width - x - 22
        height: 172
        visible: root.wifiPanel

        Text {
            y: 4
            text: "Wi-Fi"
            color: Theme.accent
            font.family: Theme.fontFamily
            font.weight: Font.ExtraBold
            font.pixelSize: 14
        }

        Text {
            x: 52
            y: 6
            text: root.scanning ? "Поиск сетей…" : root.wifiStatus
            color: Theme.faint
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 11
        }

        Rectangle {
            id: wifiSwitch
            anchors.right: parent.right
            y: 2
            width: 40
            height: 22
            radius: 11
            color: root.wifiOn ? Theme.accent : root.tint(0.16)

            Rectangle {
                x: root.wifiOn ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: 8
                color: root.wifiOn ? Theme.background : Theme.accent

                Behavior on x {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: wifiToggle.running = true
            }
        }

        Flickable {
            y: 32
            width: parent.width
            height: parent.height - 32
            contentHeight: netColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: netColumn
                width: parent.width

                Repeater {
                    model: root.wifiOn ? root.networks : []

                    Column {
                        id: netRow
                        required property var modelData
                        width: netColumn.width

                        Item {
                            width: parent.width
                            height: 30

                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: -8
                                radius: 9
                                color: Theme.accent
                                opacity: netArea.containsMouse ? 0.08 : 0
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Repeater {
                                    model: 4
                                    Rectangle {
                                        required property int index
                                        anchors.bottom: parent.bottom
                                        width: 3
                                        height: 4 + index * 3
                                        radius: 1.5
                                        color: netRow.modelData.signal > index * 25 ? Theme.accent : root.tint(0.2)
                                    }
                                }
                            }

                            Text {
                                x: 24
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 24 - 90
                                text: netRow.modelData.ssid
                                elide: Text.ElideRight
                                color: netRow.modelData.inUse ? Theme.accent : Theme.dim
                                font.family: Theme.fontFamily
                                font.weight: netRow.modelData.inUse ? Font.ExtraBold : Font.Bold
                                font.pixelSize: 13
                            }

                            Item {
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                visible: netRow.modelData.secure && !netRow.modelData.inUse
                                width: 10
                                height: 12

                                Rectangle {
                                    x: 1.5
                                    width: 7
                                    height: 8
                                    radius: 3.5
                                    color: "transparent"
                                    border.width: 1.5
                                    border.color: Theme.faint
                                }

                                Rectangle {
                                    y: 5
                                    width: 10
                                    height: 7
                                    radius: 2
                                    color: Theme.faint
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: netRow.modelData.inUse
                                text: "отключить"
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.weight: Font.Bold
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: netArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pick(netRow.modelData)
                            }
                        }

                        Item {
                            visible: root.passwordFor === netRow.modelData.ssid
                            width: parent.width
                            height: visible ? 34 : 0

                            Rectangle {
                                anchors.fill: parent
                                anchors.topMargin: 2
                                anchors.bottomMargin: 4
                                radius: 10
                                color: root.tint(0.08)
                            }

                            TextInput {
                                id: passInput
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 24
                                echoMode: TextInput.Password
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.weight: Font.Bold
                                font.pixelSize: 13
                                onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                                Keys.onReturnPressed: root.connectTo(netRow.modelData, text)
                                Keys.onEnterPressed: root.connectTo(netRow.modelData, text)
                                Keys.onEscapePressed: root.passwordFor = ""
                            }

                            Text {
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                visible: passInput.text === ""
                                text: "Пароль и Enter"
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.weight: Font.Bold
                                font.pixelSize: 13
                            }
                        }
                    }
                }

                Text {
                    visible: !root.wifiOn
                    topPadding: 20
                    text: "Wi-Fi выключен"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: 13
                }
            }
        }
    }

    Item {
        x: 292
        y: 4
        width: root.width - x - 22
        height: 172
        visible: root.historyPanel

        Text {
            y: 4
            text: "Уведомления"
            color: Theme.accent
            font.family: Theme.fontFamily
            font.weight: Font.ExtraBold
            font.pixelSize: 14
        }

        Text {
            anchors.right: parent.right
            y: 5
            visible: root.notifHistory.length > 0
            text: "Очистить"
            color: clearArea.containsMouse ? Theme.dim : Theme.faint
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 12

            MouseArea {
                id: clearArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.historyCleared()
            }
        }

        Flickable {
            y: 30
            width: parent.width
            height: parent.height - 30
            contentHeight: historyColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: historyColumn
                width: parent.width

                Repeater {
                    model: root.historyPanel ? root.notifHistory : []

                    Item {
                        id: historyRow
                        required property var modelData
                        width: historyColumn.width
                        height: 40

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: -8
                            radius: 10
                            color: Theme.accent
                            opacity: historyArea.containsMouse ? 0.08 : 0
                        }

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 22
                            source: historyRow.modelData.icon || Quickshell.iconPath("dialog-information")
                        }

                        Text {
                            x: 32
                            y: 4
                            width: parent.width - 32 - 64
                            text: historyRow.modelData.title
                            elide: Text.ElideRight
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.weight: Font.ExtraBold
                            font.pixelSize: 13
                        }

                        Text {
                            x: 32
                            y: 21
                            width: parent.width - 32
                            text: historyRow.modelData.body || historyRow.modelData.app
                            elide: Text.ElideRight
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: 12
                        }

                        Text {
                            anchors.right: parent.right
                            y: 5
                            text: historyRow.modelData.time
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: historyArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const d = historyRow.modelData;
                                const entry = (d.entry ? DesktopEntries.byId(d.entry) : null) || DesktopEntries.heuristicLookup(d.app);
                                if (entry)
                                    entry.execute();
                            }
                        }
                    }
                }

                Text {
                    visible: root.notifHistory.length === 0
                    topPadding: 24
                    text: "Новых уведомлений нет"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: 13
                }
            }
        }
    }

    Row {
        id: actions
        x: 22
        y: 120
        spacing: 12

        RoundButton {
            on: root.wifiOn
            onClicked: root.wifiPanel = !root.wifiPanel

            Shape {
                x: -2
                y: -4
                width: 22
                height: 22
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: root.wifiOn ? Theme.background : Theme.accent
                    strokeWidth: 2.4
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc { moveToStart: true; centerX: 11; centerY: 17; radiusX: 10; radiusY: 10; startAngle: 225; sweepAngle: 90 }
                    PathAngleArc { moveToStart: true; centerX: 11; centerY: 17; radiusX: 5.5; radiusY: 5.5; startAngle: 225; sweepAngle: 90 }
                }
                ShapePath {
                    strokeWidth: -1
                    fillColor: root.wifiOn ? Theme.background : Theme.accent
                    PathAngleArc { centerX: 11; centerY: 17; radiusX: 2; radiusY: 2; startAngle: 0; sweepAngle: 360 }
                }
            }
        }

        RoundButton {
            id: timerButton
            on: root.timerRunning || root.choosingTimer
            onClicked: {
                if (root.timerRunning)
                    root.timerLeft = 0;
                else
                    root.choosingTimer = !root.choosingTimer;
            }

            Rectangle {
                x: 1
                y: 1
                width: 16
                height: 16
                radius: 8
                color: "transparent"
                border.width: 2
                border.color: timerButton.on ? Theme.background : Theme.accent

                Rectangle { x: 7; y: 3.5; width: 2; height: 5; radius: 1; color: parent.border.color }
                Rectangle { x: 7; y: 7; width: 4; height: 2; radius: 1; color: parent.border.color }
            }
        }

        RoundButton {
            badge: root.updates > 0 ? String(root.updates) : ""
            onClicked: updateRunner.running = true

            Item {
                width: 18
                height: 18
                Rectangle { x: 8; y: 1; width: 2; height: 11; radius: 1; color: Theme.accent }
                Rectangle { x: 4.6; y: 5.4; width: 2; height: 6.5; radius: 1; rotation: -45; color: Theme.accent }
                Rectangle { x: 11.4; y: 5.4; width: 2; height: 6.5; radius: 1; rotation: 45; color: Theme.accent }
                Rectangle { x: 2; y: 15; width: 14; height: 2; radius: 1; color: Theme.accent }
            }
        }

        RoundButton {
            id: bellButton
            on: root.historyPanel
            badge: root.notifUnread > 0 ? String(root.notifUnread) : ""
            onClicked: root.historyPanel = !root.historyPanel

            Item {
                width: 18
                height: 18
                readonly property color ink: bellButton.on ? Theme.background : Theme.accent

                Rectangle {
                    x: 3.5
                    y: 2
                    width: 11
                    height: 11
                    radius: 5.5
                    color: parent.ink
                }

                Rectangle {
                    x: 3.5
                    y: 7.5
                    width: 11
                    height: 6
                    color: parent.ink
                }

                Rectangle {
                    x: 1.5
                    y: 12
                    width: 15
                    height: 2.2
                    radius: 1.1
                    color: parent.ink
                }

                Rectangle {
                    x: 7
                    y: 15
                    width: 4
                    height: 2.5
                    radius: 1.25
                    color: parent.ink
                }
            }
        }

        RoundButton {
            id: clipButton
            on: root.clipPanel
            onClicked: root.clipPanel = !root.clipPanel

            Item {
                width: 18
                height: 18
                readonly property color ink: clipButton.on ? Theme.background : Theme.accent

                Rectangle {
                    x: 2.5
                    y: 2.5
                    width: 13
                    height: 15
                    radius: 3
                    color: "transparent"
                    border.color: parent.ink
                    border.width: 2
                }

                Rectangle {
                    x: 5.5
                    y: 0.5
                    width: 7
                    height: 4.5
                    radius: 1.5
                    color: parent.ink
                }

                Rectangle { x: 6; y: 9; width: 6; height: 2; radius: 1; color: parent.ink }
                Rectangle { x: 6; y: 12.5; width: 4; height: 2; radius: 1; color: parent.ink }
            }
        }
    }

    Item {
        x: actions.x + actions.width + 18
        y: actions.y
        width: root.width - x - 22
        height: 40

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            visible: !root.choosingTimer

            Text {
                visible: root.timerRunning
                text: root.fmt(root.timerLeft)
                color: Theme.accent
                font.family: Theme.fontFamily
                font.weight: Font.ExtraBold
                font.pixelSize: 13
                font.features: { "tnum": 1 }
            }

        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            visible: !root.choosingTimer && !root.wifiPanel && !root.historyPanel

            Text {
                id: deviceName
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 160)
                elide: Text.ElideRight
                text: root.sink ? (root.sink.nickname || root.sink.description || root.sink.name) : ""
                color: deviceArea.containsMouse ? Theme.dim : Theme.faint
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.pixelSize: 12

                MouseArea {
                    id: deviceArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const list = root.sinks;
                        if (list.length < 2)
                            return;
                        const i = list.indexOf(root.sink);
                        Pipewire.preferredDefaultAudioSink = list[(i + 1) % list.length];
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.sinkReady ? Math.round(root.sink.audio.volume * 100) + "%" : ""
                color: Theme.dim
                font.family: Theme.fontFamily
                font.weight: Font.ExtraBold
                font.pixelSize: 12
                font.features: { "tnum": 1 }
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            visible: root.customTimer

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 104
                height: 30
                radius: 15
                color: root.tint(0.1)

                TextInput {
                    id: customInput
                    anchors.centerIn: parent
                    width: parent.width - 20
                    horizontalAlignment: TextInput.AlignHCenter
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.weight: Font.ExtraBold
                    font.pixelSize: 14
                    validator: RegularExpressionValidator { regularExpression: /^[0-9]{0,3}(:[0-9]{0,2})?$/ }
                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                    function submit() {
                        const parts = text.split(":");
                        const seconds = (parseInt(parts[0]) || 0) * 60 + (parseInt(parts[1]) || 0);
                        root.startTimer(seconds);
                    }
                    Keys.onReturnPressed: submit()
                    Keys.onEnterPressed: submit()
                    Keys.onEscapePressed: root.choosingTimer = false
                }

                Text {
                    anchors.centerIn: parent
                    visible: customInput.text === ""
                    text: "мин : сек"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: 13
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: startText.implicitWidth + 24
                height: 30
                radius: 15
                color: Theme.accent
                opacity: customInput.text.replace(":", "") === "" ? 0.35 : startArea.containsMouse ? 0.85 : 1

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                Text {
                    id: startText
                    anchors.centerIn: parent
                    text: "Старт"
                    color: Theme.background
                    font.family: Theme.fontFamily
                    font.weight: Font.ExtraBold
                    font.pixelSize: 13
                }

                MouseArea {
                    id: startArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: customInput.submit()
                }
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: root.choosingTimer && !root.customTimer

            Repeater {
                model: [5, 10, 30, 0]

                Item {
                    required property var modelData
                    width: chooseText.implicitWidth + 18
                    height: 30

                    Rectangle {
                        anchors.fill: parent
                        radius: 15
                        color: Theme.accent
                        opacity: chooseArea.containsMouse ? 0.12 : 0
                    }

                    Text {
                        id: chooseText
                        anchors.centerIn: parent
                        text: parent.modelData > 0 ? parent.modelData + " мин" : "Своё"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: chooseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (parent.modelData > 0)
                                root.startTimer(parent.modelData * 60);
                            else
                                root.customTimer = true;
                        }
                    }
                }
            }
        }

    }

    Item {
        x: 22
        y: 186
        width: root.width - 44
        height: 20

        Shape {
            width: 12
            height: 12
            anchors.verticalCenter: parent.verticalCenter
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: Theme.faint
                startX: 0; startY: 4
                PathLine { x: 3; y: 4 }
                PathLine { x: 7; y: 0 }
                PathLine { x: 7; y: 12 }
                PathLine { x: 3; y: 8 }
                PathLine { x: 0; y: 8 }
                PathLine { x: 0; y: 4 }
            }
        }

        Rectangle {
            id: volTrack
            x: 22
            width: parent.width - x
            height: 3
            radius: 1.5
            anchors.verticalCenter: parent.verticalCenter
            color: root.tint(0.16)

            Rectangle {
                width: parent.width * (root.sinkReady ? Math.min(1, root.sink.audio.volume) : 0)
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -9
                cursorShape: Qt.PointingHandCursor
                function apply(mx) {
                    if (root.sinkReady)
                        root.sink.audio.volume = Math.max(0, Math.min(1, (mx - 9) / volTrack.width));
                }
                onPressed: mouse => apply(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        apply(mouse.x);
                }
                onWheel: wheel => {
                    if (root.sinkReady)
                        root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
                }
            }
        }

    }
}
