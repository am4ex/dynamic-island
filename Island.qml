import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

Item {
    id: root

    readonly property var players: Mpris.players.values
    property MprisPlayer chosenPlayer: null
    readonly property MprisPlayer player: {
        const list = players;
        if (chosenPlayer && list.indexOf(chosenPlayer) >= 0)
            return chosenPlayer;
        return list.find(p => p.isPlaying) ?? list[0] ?? null;
    }
    readonly property bool hasMedia: player !== null
    readonly property bool playing: hasMedia && player.isPlaying

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool sinkReady: sink !== null && sink.ready && sink.audio !== null
    property bool volumeArmed: false
    property bool volumeShown: false
    property bool layoutShown: false
    readonly property string layoutBadge: {
        const c = cursor.layoutCode;
        if (c === "")
            return "";
        if (c === "us" || c === "gb")
            return "EN";
        return c.toUpperCase().slice(0, 2);
    }
    readonly property string layoutTitle: {
        const c = cursor.layoutCode;
        const names = { "ru": "Русский", "us": "English", "gb": "English", "ua": "Українська", "by": "Беларуская", "de": "Deutsch", "fr": "Français", "es": "Español" };
        return names[c] || cursor.layoutName;
    }

    property var notice: null
    property var shownNotice: null

    property string tab: "home"
    property bool pinned: false
    property bool trayMenuOpen: false
    property bool cardHovered: false
    property Item leftCard: null
    property Item rightCard: null
    readonly property bool pointerIn: hover.hovered || cardHovered
    property bool hoverHeld: false
    onPointerInChanged: {
        if (pointerIn) {
            leaveTimer.stop();
            hoverHeld = true;
        } else {
            leaveTimer.restart();
        }
    }
    readonly property bool expanded: notice === null && !volumeShown && !layoutShown && (hoverHeld || pinned)
    readonly property string compactMode: notice !== null ? "notice" : layoutShown ? "layout" : volumeShown ? "volume" : playing ? "media" : "idle"
    readonly property string mode: expanded ? "expanded" : compactMode
    readonly property bool playerOpen: expanded && tab === "player" && hasMedia
    readonly property bool showPlayer: hasMedia && (mode === "media" || playerOpen)
    readonly property bool showApps: expanded && tab === "apps"
    readonly property bool showHome: expanded && !playerOpen && !showApps
    property bool homeWantsKeyboard: false
    readonly property bool wantsKeyboard: showApps || (showHome && homeWantsKeyboard)
    property real appsOpenedAt: 0

    function openApps() {
        pinned = true;
        tab = "apps";
        appsOpenedAt = Date.now();
    }

    function closeApps() {
        pinned = false;
        if (tab === "apps")
            tab = "home";
    }

    property real fullWidth: playerOpen ? 560 : 640
    property real fullHeight: playerOpen ? 236 : showApps ? 290 : 312
    Behavior on fullWidth {
        NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
    }
    Behavior on fullHeight {
        NumberAnimation { duration: 480; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
    }
    readonly property real fullRadius: 28

    property real compactWidth: !born ? 44 : compactMode === "notice" ? (helloShown ? 190 : 340) : compactMode === "volume" ? 280 : compactMode === "layout" ? 200 : compactMode === "media" ? 270 : 200
    property real compactHeight: !born ? 24 : compactMode === "notice" && !helloShown ? 50 : 38
    readonly property real compactRadius: compactHeight / 2

    Behavior on compactWidth {
        NumberAnimation { duration: 480; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
    }
    Behavior on compactHeight {
        NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    }

    property real progress: expanded ? 1 : 0
    Behavior on progress {
        NumberAnimation {
            duration: root.expanded ? 500 : 360
            easing.type: root.expanded ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: 0.7
        }
    }

    property real progressHeight: expanded ? 1 : 0
    Behavior on progressHeight {
        NumberAnimation {
            duration: root.expanded ? 640 : 420
            easing.type: root.expanded ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: 1.2
        }
    }

    property real radius: compactRadius + (fullRadius - compactRadius) * Math.min(1, Math.max(0, progress))
    implicitWidth: compactWidth + (fullWidth - compactWidth) * progress
    implicitHeight: compactHeight + (fullHeight - compactHeight) * progressHeight

    property real waveAmount: playing ? 1 : 0
    Behavior on waveAmount {
        NumberAnimation { duration: 500 }
    }

    property real phase: 0

    property real gradientAmount: playerOpen ? waveAmount : 0
    Behavior on gradientAmount {
        NumberAnimation { duration: 450 }
    }

    property point globalOrigin: Qt.point(0, 0)
    property string screenName: ""
    property real screenTop: 0
    readonly property bool fullscreenHere: screenName !== "" && cursor.fullscreenOutputs.indexOf(screenName) >= 0
    property bool revealed: false
    readonly property bool peeking: notice !== null || layoutShown || volumeShown || trayMenuOpen || pinned
    readonly property bool concealed: fullscreenHere && !revealed && !peeking

    property real slide: 0
    property real stretchX: 1
    property real stretchY: 1

    transform: [
        Scale {
            origin.x: root.width / 2
            origin.y: 0
            xScale: root.stretchX
            yScale: root.stretchY
        },
        Translate { y: -(root.height + 40) * root.slide }
    ]

    onConcealedChanged: {
        if (concealed) {
            revealAnim.stop();
            hideAnim.restart();
        } else {
            hideAnim.stop();
            revealAnim.restart();
        }
    }

    SequentialAnimation {
        id: revealAnim
        PropertyAction { target: root; property: "stretchX"; value: 0.22 }
        PropertyAction { target: root; property: "stretchY"; value: 1.35 }
        NumberAnimation { target: root; property: "slide"; to: 0; duration: 240; easing.type: Easing.OutQuad }
        ScriptAction { script: rippleAnim.restart() }
        ParallelAnimation {
            NumberAnimation { target: root; property: "stretchX"; to: 1; duration: 620; easing.type: Easing.OutBack; easing.overshoot: 1.7 }
            NumberAnimation { target: root; property: "stretchY"; to: 1; duration: 750; easing.type: Easing.OutElastic; easing.amplitude: 1.1; easing.period: 0.4 }
        }
    }

    SequentialAnimation {
        id: hideAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "stretchX"; to: 0.35; duration: 260; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "stretchY"; to: 1.2; duration: 260; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "slide"; to: 1; duration: 300; easing.type: Easing.InCubic }
        }
        PropertyAction { target: root; property: "stretchX"; value: 1 }
        PropertyAction { target: root; property: "stretchY"; value: 1 }
    }

    SequentialAnimation {
        id: rippleAnim
        NumberAnimation { target: root; property: "splash"; to: 0.75; duration: 140; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "splash"; to: 0; duration: 900; easing.type: Easing.InOutSine }
    }

    onCompactModeChanged: if (!expanded && !concealed) rippleAnim.restart()

    onFullscreenHereChanged: revealed = false

    function updateReveal() {
        if (!fullscreenHere) {
            revealed = false;
            return;
        }
        const cx = globalOrigin.x + width / 2;
        const dx = Math.abs(cursor.globalX - cx);
        if (!revealed) {
            if (cursor.globalY <= screenTop + 4 && dx < Math.max(170, width / 2 + 40))
                revealed = true;
            return;
        }
        if (trayMenuOpen)
            return;
        const below = cursor.globalY - (screenTop + 10 + height);
        if (!pointerIn && (below > 50 || dx > width / 2 + 120))
            revealed = false;
    }

    Connections {
        target: cursor
        function onMoved() { root.updateReveal(); }
    }
    readonly property point cursorLocal: Qt.point(cursor.globalX - globalOrigin.x, cursor.globalY - globalOrigin.y)
    readonly property bool pulling: mode === "idle" && cursor.known
    property real pullX: pulling ? Math.max(radius, Math.min(width - radius, cursorLocal.x)) : width / 2
    property real pull: {
        if (!pulling)
            return 0;
        const dx = cursorLocal.x - width / 2;
        const dy = cursorLocal.y - height;
        const dist = Math.sqrt(dx * dx + dy * dy);
        return 2.5 + 6 * Math.max(0, 1 - dist / 900);
    }

    Behavior on pullX {
        SpringAnimation { spring: 2.2; damping: 0.22; epsilon: 0.1 }
    }
    Behavior on pull {
        SpringAnimation { spring: 2.5; damping: 0.25; epsilon: 0.05 }
    }

    readonly property color accent: {
        const cs = quantizer.colors;
        let best = null;
        let score = -1;
        for (let i = 0; i < cs.length; i++) {
            const s = cs[i].hsvSaturation * cs[i].hsvValue;
            if (s > score) {
                score = s;
                best = cs[i];
            }
        }
        if (!best || score < 0.08)
            return "#5f9a4a";
        return Qt.hsva(best.hsvHue, Math.min(0.72, best.hsvSaturation * 0.9 + 0.08), Math.min(0.82, Math.max(0.62, best.hsvValue * 0.9)), 1);
    }
    readonly property bool helloShown: notice !== null && notice.kind === "hello"
    readonly property color edgeColor: compactMode === "notice" ? (notice && notice.kind === "timer" ? "#e8913a" : Theme.accent) : accent

    property real glow: Math.max(waveAmount, compactMode === "notice" && !helloShown ? 1 : 0)
    Behavior on glow {
        NumberAnimation { duration: 300 }
    }

    readonly property string timeText: Qt.formatDateTime(clock.date, "h:mm AP")

    readonly property var streamNodes: Pipewire.nodes.values.filter(n => n.isStream && n.audio !== null && !n.isSink)

    function norm(s) {
        return (s || "").toLowerCase().replace(/[^a-z0-9а-яё]/g, "");
    }

    readonly property var playerStreams: {
        if (!player)
            return [];
        const keys = [norm(player.identity), norm(player.desktopEntry), norm((player.dbusName || "").split(".")[3])].filter(k => k.length >= 3);
        return streamNodes.filter(n => {
            const p = n.properties || {};
            const names = [norm(p["application.name"]), norm(p["application.process.binary"]), norm(n.name)].filter(k => k.length >= 3);
            return names.some(a => keys.some(b => a.indexOf(b) >= 0 || b.indexOf(a) >= 0));
        });
    }
    readonly property bool hasPlayerVolume: playerStreams.length > 0 || (player !== null && player.volumeSupported)
    readonly property real playerVolume: {
        if (playerStreams.length > 0)
            return playerStreams[0].audio.volume;
        if (player && player.volumeSupported)
            return player.volume;
        return 0;
    }

    function setPlayerVolume(v) {
        if (playerStreams.length > 0) {
            for (let i = 0; i < playerStreams.length; i++)
                playerStreams[i].audio.volume = v;
        } else if (player && player.volumeSupported) {
            player.volume = v;
        }
    }

    function showNotice(n, duration) {
        if (notice !== null && !concealed)
            rippleAnim.restart();
        notice = n;
        shownNotice = n;
        noticeTimer.interval = duration;
        noticeTimer.restart();
    }

    function showVolume() {
        if (!volumeArmed || expanded)
            return;
        volumeShown = true;
        volumeTimer.restart();
    }

    onExpandedChanged: if (expanded && tab !== "apps") tab = playing ? "player" : "home"

    Connections {
        target: cursor
        function onAppsRequested() {
            if (root.showApps)
                root.closeApps();
            else
                root.openApps();
        }
        function onWindowsChanged() {
            if (root.pinned && root.tab === "apps" && Date.now() - root.appsOpenedAt > 500)
                root.closeApps();
        }
    }
    onHasMediaChanged: if (!hasMedia) pinned = false
    onSinkChanged: volumeArmed = false
    onSinkReadyChanged: {
        volumeArmed = false;
        if (sinkReady)
            armTimer.restart();
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    ColorQuantizer {
        id: quantizer
        source: root.player ? root.player.trackArtUrl : ""
        depth: 2
        rescaleSize: 32
    }

    AudioBars {
        id: audio
        active: root.playing
    }

    CursorTracker {
        id: cursor
    }

    ClipboardWatcher {
        onCopied: text => {
            const clean = text.replace(/\s+/g, " ").trim();
            root.showNotice({ kind: "clip", title: "Скопировано", subtitle: clean || "Изображение или файл" }, 2500);
        }
    }

    PwObjectTracker {
        objects: [root.sink].concat(root.streamNodes)
    }

    FrameAnimation {
        running: root.splash > 0.01
        onTriggered: root.phase += frameTime * 1.6
    }

    property bool born: false
    property real splash: 0

    Component.onCompleted: showNotice({ kind: "hello", title: "Привет", subtitle: "", color: Theme.accent }, 2600)

    Timer {
        running: true
        interval: 120
        onTriggered: {
            root.born = true;
            splashAnim.restart();
        }
    }

    SequentialAnimation {
        id: splashAnim
        PauseAnimation { duration: 250 }
        NumberAnimation { target: root; property: "splash"; from: 0; to: 1; duration: 250; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "splash"; to: 0; duration: 1600; easing.type: Easing.InOutSine }
    }

    Timer {
        id: noticeTimer
        onTriggered: root.notice = null
    }

    Timer {
        id: armTimer
        interval: 500
        onTriggered: root.volumeArmed = root.sinkReady
    }

    Connections {
        target: cursor
        function onLayoutSwitched() {
            if (root.expanded)
                return;
            root.layoutShown = true;
            layoutTimer.restart();
        }
    }

    Timer {
        id: leaveTimer
        interval: 350
        onTriggered: root.hoverHeld = false
    }

    Timer {
        id: layoutTimer
        interval: 1500
        onTriggered: root.layoutShown = false
    }

    Timer {
        id: volumeTimer
        interval: 2000
        onTriggered: root.volumeShown = false
    }

    Connections {
        target: root.sinkReady ? root.sink.audio : null
        function onVolumeChanged() { root.showVolume(); }
        function onMutedChanged() { root.showVolume(); }
    }


    HoverHandler {
        id: hover
    }

    LiquidBody {
        bodyWidth: root.width
        bodyHeight: root.height
        radius: root.radius
        levels: audio.levels
        waveAmount: Math.max(root.waveAmount, root.splash * 0.45)
        phase: root.phase
        gradient: root.gradientAmount
        pull: root.pull
        pullX: root.pullX
        edgeColor: root.edgeColor
        glow: root.glow
    }


    Item {
        anchors.fill: parent
        clip: true
        opacity: Math.max(0, Math.min(1, (root.stretchX - 0.55) / 0.35))

        MouseArea {
            anchors.fill: parent
            onClicked: root.pinned = !root.pinned
        }

        Morph {
            anchors.fill: parent
            shown: root.mode === "idle"

            IdleView {
                anchors.fill: parent
                timeText: root.timeText
                layoutBadge: root.layoutBadge
                cursorKnown: cursor.known
                cursor: root.cursorLocal
            }
        }

        Morph {
            anchors.fill: parent
            shown: root.showPlayer

            MediaView {
                anchors.fill: parent
                player: root.player
                progress: root.progress
                expanded: root.playerOpen
                timeText: root.timeText
                layoutBadge: root.layoutBadge
                levels: audio.levels
                accent: root.accent
                players: root.players
                playerVolume: root.playerVolume
                hasPlayerVolume: root.hasPlayerVolume
                onChoosePlayer: chosen => root.chosenPlayer = chosen
                onChangePlayerVolume: value => root.setPlayerVolume(value)
            }
        }

        Morph {
            anchors.fill: parent
            shown: root.showApps

            AppsView {
                anchors.fill: parent
                anchors.topMargin: 44
                active: root.showApps
                onLaunched: root.closeApps()
                onCloseRequested: root.closeApps()
            }
        }

        Morph {
            anchors.fill: parent
            shown: root.showHome

            HomeView {
                anchors.fill: parent
                anchors.topMargin: 44
                active: root.showHome
                overlay: root
                activeClass: cursor.activeClass
                activeTitle: cursor.activeTitle
                onWantsKeyboardChanged: root.homeWantsKeyboard = wantsKeyboard
                onTimerFinished: minutes => root.showNotice({ kind: "timer", title: "Время вышло", subtitle: "Таймер · " + minutes + " мин" }, 9000)
                onMenuOpenChanged: root.trayMenuOpen = menuOpen
                onCardHoveredChanged: root.cardHovered = cardHovered
            }
        }

        Row {
            x: 16
            y: 10
            spacing: 6
            opacity: Math.max(0, Math.min(1, (root.progress - 0.5) * 2))
            visible: opacity > 0

            Repeater {
                model: root.hasMedia ? [{ key: "home", label: "Главная" }, { key: "apps", label: "Приложения" }, { key: "player", label: "Плеер" }] : [{ key: "home", label: "Главная" }, { key: "apps", label: "Приложения" }]

                Rectangle {
                    required property var modelData
                    readonly property bool selected: modelData.key === (root.playerOpen ? "player" : root.showApps ? "apps" : "home")

                    width: tabText.implicitWidth + 24
                    height: 26
                    radius: 13
                    color: selected ? "#26ffffff" : tabArea.containsMouse ? "#14ffffff" : "transparent"

                    Text {
                        id: tabText
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: parent.selected ? Theme.accent : Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.ExtraBold
                    }

                    MouseArea {
                        id: tabArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tab = parent.modelData.key
                    }
                }
            }
        }

        Morph {
            anchors.fill: parent
            shown: root.mode === "layout"

            LayoutView {
                anchors.fill: parent
                title: root.layoutTitle
            }
        }

        Morph {
            anchors.fill: parent
            shown: root.mode === "volume"

            VolumeView {
                anchors.fill: parent
                volume: root.sinkReady ? root.sink.audio.volume : 0
                muted: root.sinkReady ? root.sink.audio.muted : false
            }
        }

        Morph {
            anchors.fill: parent
            shown: root.mode === "notice"

            NoticeView {
                anchors.fill: parent
                notice: root.shownNotice
            }
        }
    }
}
