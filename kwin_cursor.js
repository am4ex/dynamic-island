var last = 0;
var watched = [];

function send(method, a, b) {
    if (b === undefined)
        callDBus("org.dynamicisland.Cursor", "/Cursor", "org.dynamicisland.Cursor", method, a);
    else
        callDBus("org.dynamicisland.Cursor", "/Cursor", "org.dynamicisland.Cursor", method, a, b);
}

workspace.cursorPosChanged.connect(function () {
    var now = Date.now();
    if (now - last < 16)
        return;
    last = now;
    var p = workspace.cursorPos;
    send("Update", Math.round(p.x), Math.round(p.y));
});

function onDesktop(w) {
    if (w.onAllDesktops)
        return true;
    var ds = w.desktops;
    for (var i = 0; i < ds.length; i++) {
        if (ds[i] === workspace.currentDesktop)
            return true;
    }
    return false;
}

function coversOutput(w) {
    var f = w.frameGeometry;
    var o = w.output.geometry;
    return f.x <= o.x + 1 && f.y <= o.y + 1 && f.x + f.width >= o.x + o.width - 1 && f.y + f.height >= o.y + o.height - 1;
}

function report() {
    var seen = [];
    var names = [];
    var order = workspace.stackingOrder;
    for (var i = order.length - 1; i >= 0; i--) {
        var w = order[i];
        if (!w.output || w.minimized || w.layer > 6 || w.resourceClass === "quickshell" || !onDesktop(w) || !(w.normalWindow || w.fullScreen))
            continue;
        var name = w.output.name;
        if (seen.indexOf(name) >= 0)
            continue;
        seen.push(name);
        if (w.fullScreen || coversOutput(w))
            names.push(name);
    }
    send("Fullscreen", names.join(","));
}

function watch(w) {
    if (watched.indexOf(w) >= 0)
        return;
    watched.push(w);
    w.fullScreenChanged.connect(report);
    w.minimizedChanged.connect(report);
    w.outputChanged.connect(report);
    w.desktopsChanged.connect(report);
    w.frameGeometryChanged.connect(report);
}

var all = workspace.windowList();
for (var i = 0; i < all.length; i++)
    watch(all[i]);

workspace.windowAdded.connect(function (w) {
    watch(w);
    report();
});
workspace.windowRemoved.connect(function (w) {
    var i = watched.indexOf(w);
    if (i >= 0)
        watched.splice(i, 1);
    report();
});
workspace.currentDesktopChanged.connect(report);
workspace.windowActivated.connect(report);
report();
