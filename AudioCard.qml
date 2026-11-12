import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire

Column {
    id: root

    property bool active: false
    property string page: "devices"
    readonly property var apps: Pipewire.nodes.values.filter(n => n.audio !== null && n.isStream && n.type === PwNodeType.AudioOutStream)

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio !== null && n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio !== null && !n.isSink && !n.isStream && n.type === PwNodeType.AudioSource)

    spacing: 4

    PwObjectTracker {
        objects: root.active ? root.sinks.concat(root.sources).concat(root.apps) : []
    }

    component Section: Text {
        textFormat: Text.PlainText
        color: Theme.faint
        font.family: Theme.fontFamily
        font.weight: Font.Bold
        font.pixelSize: 11
        topPadding: 6
        bottomPadding: 2
    }

    component DeviceRow: Item {
        id: row

        property PwNode node: null
        property bool current: false
        property bool input: false
        property bool app: false
        signal choose

        readonly property var props: node && node.properties ? node.properties : ({})
        readonly property string label: !node ? "" : app ? (props["application.name"] || node.description || node.name) : (node.nickname || node.description || node.name)
        readonly property string appIcon: {
            if (!app)
                return "";
            const names = [props["application.icon-name"], props["application.process.binary"], (props["application.name"] || "").toLowerCase()];
            for (let i = 0; i < names.length; i++) {
                const p = names[i] ? Quickshell.iconPath(names[i], true) : "";
                if (p)
                    return p;
            }
            return Quickshell.iconPath("audio-x-generic");
        }

        readonly property bool ready: node !== null && node.audio !== null
        readonly property real volume: ready ? node.audio.volume : 0
        readonly property bool muted: ready && node.audio.muted

        width: root.width
        height: 50

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -8
            anchors.rightMargin: -8
            radius: 12
            color: Theme.accent
            opacity: nameArea.containsMouse && !row.current ? 0.06 : 0
        }

        IconImage {
            visible: row.app
            x: -2
            y: 3
            implicitSize: 16
            source: row.appIcon
        }

        Rectangle {
            visible: !row.app
            x: 0
            y: 7
            width: 12
            height: 12
            radius: 6
            color: "transparent"
            border.width: 1.6
            border.color: row.current ? Theme.accent : Theme.faint

            Rectangle {
                anchors.centerIn: parent
                width: 6
                height: 6
                radius: 3
                color: Theme.accent
                visible: row.current
            }
        }

        Text {
            textFormat: Text.PlainText
            x: 20
            y: 4
            width: parent.width - 20
            elide: Text.ElideRight
            text: row.label
            color: row.current || row.app ? Theme.accent : Theme.dim
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 12
        }

        MouseArea {
            id: nameArea
            x: 0
            y: 0
            width: parent.width
            height: 24
            enabled: !row.app
            hoverEnabled: true
            cursorShape: row.current ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: row.choose()
        }

        Item {
            id: muteButton
            x: 0
            y: 28
            width: 16
            height: 16

            Rectangle {
                visible: !row.input
                x: 1
                y: 5
                width: 4
                height: 6
                radius: 1
                color: row.muted ? Theme.faint : Theme.dim
            }

            Rectangle {
                visible: !row.input
                x: 4
                y: 2
                width: 6
                height: 12
                radius: 2
                color: row.muted ? Theme.faint : Theme.dim
            }

            Rectangle {
                visible: row.input
                x: 5
                y: 1
                width: 6
                height: 10
                radius: 3
                color: row.muted ? Theme.faint : Theme.dim
            }

            Rectangle {
                visible: row.input
                x: 7
                y: 11
                width: 2
                height: 4
                radius: 1
                color: row.muted ? Theme.faint : Theme.dim
            }

            Rectangle {
                visible: row.muted
                anchors.centerIn: parent
                width: 18
                height: 2
                radius: 1
                rotation: -45
                color: Theme.accent
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: if (row.ready) row.node.audio.muted = !row.node.audio.muted
            }
        }

        Item {
            id: track
            x: 26
            y: 28
            width: parent.width - x - 44
            height: 16

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * Math.min(1, row.volume / Theme.maxVolume)
                height: 4
                radius: 2
                color: row.muted ? Theme.faint : Theme.accent
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width * Math.min(1, row.volume / Theme.maxVolume) - width / 2
                width: 12
                height: 12
                radius: 6
                color: Theme.accent
                visible: slideArea.containsMouse || slideArea.pressed
            }

            MouseArea {
                id: slideArea
                anchors.fill: parent
                anchors.topMargin: -6
                anchors.bottomMargin: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function apply(x) {
                    if (row.ready)
                        row.node.audio.volume = Math.max(0, Math.min(1, x / track.width)) * Theme.maxVolume;
                }
                onPressed: mouse => apply(mouse.x)
                onPositionChanged: mouse => { if (pressed) apply(mouse.x); }
                onWheel: wheel => {
                    if (row.ready)
                        row.node.audio.volume = Math.max(0, Math.min(Theme.maxVolume, row.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
                }
            }
        }

        Text {
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.verticalCenter: track.verticalCenter
            text: Math.round(row.volume * 100) + "%"
            color: Theme.dim
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 12
            font.features: { "tnum": 1 }
        }
    }

    Row {
        spacing: 4
        bottomPadding: 2

        Repeater {
            model: [{ key: "devices", label: Tr.t("Устройства") }, { key: "apps", label: Tr.t("Приложения") }]

            Rectangle {
                required property var modelData
                width: tabText.implicitWidth + 22
                height: 26
                radius: 13
                color: root.page === modelData.key ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : "transparent"

                Text {
                    id: tabText
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    color: root.page === parent.modelData.key ? Theme.accent : Theme.faint
                    font.family: Theme.fontFamily
                    font.weight: Font.ExtraBold
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.page = parent.modelData.key
                }
            }
        }
    }

    Section {
        text: Tr.t("Вывод")
        visible: root.page === "devices"
    }

    Repeater {
        model: root.active && root.page === "devices" ? root.sinks : []

        DeviceRow {
            required property var modelData
            node: modelData
            current: Pipewire.defaultAudioSink === modelData
            onChoose: Pipewire.preferredDefaultAudioSink = modelData
        }
    }

    Section {
        text: Tr.t("Ввод")
        visible: root.page === "devices" && root.sources.length > 0
    }

    Repeater {
        model: root.active && root.page === "devices" ? root.sources : []

        DeviceRow {
            required property var modelData
            node: modelData
            input: true
            current: Pipewire.defaultAudioSource === modelData
            onChoose: Pipewire.preferredDefaultAudioSource = modelData
        }
    }

    Repeater {
        model: root.active && root.page === "apps" ? root.apps : []

        DeviceRow {
            required property var modelData
            node: modelData
            app: true
        }
    }

    Section {
        visible: root.page === "apps" && root.apps.length === 0
        text: Tr.t("Сейчас ничего не играет")
        topPadding: 10
        bottomPadding: 8
    }

    function setRaise(on) {
        Theme.setRaiseVolume(on);
        if (on)
            return;
        const all = sinks.concat(sources).concat(apps);
        for (let i = 0; i < all.length; i++) {
            if (all[i].audio && all[i].audio.volume > 1)
                all[i].audio.volume = 1;
        }
    }

    Item {
        visible: root.page === "devices"
        width: root.width
        height: 38

        Rectangle {
            x: 0
            y: 6
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
        }

        Rectangle {
            id: raiseSwitch
            x: 0
            y: 16
            width: 32
            height: 18
            radius: 9
            color: Theme.raiseVolume ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)

            Rectangle {
                x: Theme.raiseVolume ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                radius: 6
                color: Theme.raiseVolume ? Theme.background : Theme.accent

                Behavior on x {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }
        }

        Text {
            textFormat: Text.PlainText
            x: raiseSwitch.width + 10
            anchors.verticalCenter: raiseSwitch.verticalCenter
            width: parent.width - x
            elide: Text.ElideRight
            text: Tr.t("Повысить максимальную громкость")
            color: Theme.dim
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 12
        }

        MouseArea {
            x: 0
            y: 10
            width: parent.width
            height: 30
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setRaise(!Theme.raiseVolume)
        }
    }
}
