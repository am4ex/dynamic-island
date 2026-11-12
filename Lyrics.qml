import QtQuick

Item {
    id: root

    property string title: ""
    property string artist: ""
    property real duration: 0
    property bool wanted: false

    property var lines: []
    property string status: "idle"
    property string requestKey: ""

    function indexAt(pos) {
        const l = lines;
        if (!l || l.length === 0)
            return -1;
        let lo = 0;
        let hi = l.length - 1;
        let ans = 0;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (l[mid].time <= pos + 0.25) {
                ans = mid;
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        return ans;
    }

    function parse(text) {
        const out = [];
        const rows = text.split("\n");
        const re = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
        for (let r = 0; r < rows.length; r++) {
            const row = rows[r];
            const stamps = [];
            re.lastIndex = 0;
            let m;
            while ((m = re.exec(row)) !== null)
                stamps.push(parseInt(m[1]) * 60 + parseFloat(m[2]));
            if (stamps.length === 0)
                continue;
            const body = row.replace(re, "").trim();
            for (let s = 0; s < stamps.length; s++)
                out.push({ time: stamps[s], text: body });
        }
        out.sort((a, b) => a.time - b.time);
        return out;
    }

    function request(url, done) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let data = null;
            if (xhr.status === 200) {
                try {
                    data = JSON.parse(xhr.responseText);
                } catch (e) {
                    data = null;
                }
            }
            done(data);
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function apply(text) {
        lines = parse(text);
        status = lines.length > 0 ? "ready" : "none";
    }

    function load() {
        if (!wanted)
            return;
        const key = artist + "\u0001" + title;
        if (key === requestKey)
            return;
        requestKey = key;
        lines = [];
        if (title === "") {
            status = "idle";
            return;
        }
        status = "loading";
        const q = "artist_name=" + encodeURIComponent(artist) + "&track_name=" + encodeURIComponent(title);
        const len = duration > 0 ? "&duration=" + Math.round(duration) : "";
        request("https://lrclib.net/api/get?" + q + len, data => {
            if (key !== requestKey)
                return;
            if (data && data.syncedLyrics) {
                apply(data.syncedLyrics);
                return;
            }
            request("https://lrclib.net/api/search?" + q, list => {
                if (key !== requestKey)
                    return;
                const hit = Array.isArray(list) ? list.find(x => x.syncedLyrics) : null;
                if (hit)
                    apply(hit.syncedLyrics);
                else
                    status = "none";
            });
        });
    }

    onTitleChanged: debounce.restart()
    onArtistChanged: debounce.restart()
    onWantedChanged: if (wanted) debounce.restart()

    Timer {
        id: debounce
        interval: 500
        onTriggered: root.load()
    }
}
