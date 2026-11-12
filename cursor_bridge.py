import json
import os
import signal
import sys
import tempfile

from gi.repository import Gio, GLib

NAME = "org.dynamicisland.Cursor"
PLUGIN = "dynamic-island-cursor"
SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kwin_cursor.js")

XML = """
<node>
  <interface name="org.dynamicisland.Cursor">
    <method name="Update">
      <arg type="i" name="x" direction="in"/>
      <arg type="i" name="y" direction="in"/>
    </method>
    <method name="OpenApps"/>
    <method name="Window">
      <arg type="s" name="cls" direction="in"/>
      <arg type="s" name="caption" direction="in"/>
    </method>
    <method name="Fullscreen">
      <arg type="s" name="outputs" direction="in"/>
    </method>
    <method name="Activated">
      <arg type="b" name="found" direction="in"/>
    </method>
  </interface>
</node>
"""

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
loop = GLib.MainLoop()


def scripting(method, args, reply):
    return bus.call_sync("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", method,
                         args, reply, Gio.DBusCallFlags.NONE, -1, None)


def unload():
    try:
        scripting("unloadScript", GLib.Variant("(s)", (PLUGIN,)), GLib.VariantType("(b)"))
    except GLib.Error:
        pass


def on_call(connection, sender, path, interface, method, params, invocation):
    if method == "Window":
        cls, caption = params.unpack()
        clean = caption.replace("\n", " ").replace("\t", " ")
        sys.stdout.write(f"W {cls}\t{clean}\n")
    elif method == "OpenApps":
        sys.stdout.write("A\n")
    elif method == "Fullscreen":
        (outputs,) = params.unpack()
        sys.stdout.write(f"F {outputs}\n")
    elif method == "Activated":
        (found,) = params.unpack()
        sys.stdout.write(f"R {1 if found else 0}\n")
    else:
        x, y = params.unpack()
        sys.stdout.write(f"{x} {y}\n")
    sys.stdout.flush()
    invocation.return_value(None)


def on_bus_acquired(connection, name):
    node = Gio.DBusNodeInfo.new_for_xml(XML)
    connection.register_object("/Cursor", node.interfaces[0], on_call, None, None)


def on_name_acquired(connection, name):
    unload()
    scripting("loadScript", GLib.Variant("(ss)", (SCRIPT, PLUGIN)), GLib.VariantType("(i)"))
    scripting("start", None, None)


def emit_layout(*_):
    try:
        idx = bus.call_sync("org.kde.keyboard", "/Layouts", "org.kde.KeyboardLayouts", "getLayout",
                            None, GLib.VariantType("(u)"), Gio.DBusCallFlags.NONE, -1, None).unpack()[0]
        layouts = bus.call_sync("org.kde.keyboard", "/Layouts", "org.kde.KeyboardLayouts", "getLayoutsList",
                                None, GLib.VariantType("(a(sss))"), Gio.DBusCallFlags.NONE, -1, None).unpack()[0]
    except GLib.Error:
        return
    if 0 <= idx < len(layouts):
        short, variant, name = layouts[idx]
        sys.stdout.write(f"L {short}|{name}\n")
        sys.stdout.flush()


ACTIVATE = """
(function () {
    var entry = %s;
    var word = %s;
    var list = workspace.windowList();
    var best = null;
    for (var i = 0; i < list.length && !best; i++) {
        var w = list[i];
        if (!w.normalWindow)
            continue;
        var d = (w.desktopFileName || "").toLowerCase();
        var c = (w.resourceClass || "").toLowerCase();
        if (entry && (d === entry || c === entry))
            best = w;
    }
    for (var j = 0; j < list.length && !best && word; j++) {
        var v = list[j];
        if (!v.normalWindow)
            continue;
        var keys = [(v.desktopFileName || "").toLowerCase(), (v.resourceClass || "").toLowerCase(), (v.resourceName || "").toLowerCase()];
        for (var k = 0; k < keys.length; k++) {
            if (keys[k] && (keys[k] === word || keys[k].split(".").pop() === word))
                best = v;
        }
    }
    if (best) {
        if (best.minimized)
            best.minimized = false;
        workspace.activeWindow = best;
    }
    callDBus("org.dynamicisland.Cursor", "/Cursor", "org.dynamicisland.Cursor", "Activated", best !== null);
})();
"""
ACTIVATE_PLUGIN = "dynamic-island-activate"
script_file = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir(), "dynamic-island-activate.js")


def unload_activate():
    try:
        scripting("unloadScript", GLib.Variant("(s)", (ACTIVATE_PLUGIN,)), GLib.VariantType("(b)"))
    except GLib.Error:
        pass
    return False


def activate(entry, word):
    unload_activate()
    with open(script_file, "w") as f:
        f.write(ACTIVATE % (json.dumps(entry.lower()), json.dumps(word.lower())))
    try:
        scripting("loadScript", GLib.Variant("(ss)", (script_file, ACTIVATE_PLUGIN)), GLib.VariantType("(i)"))
        scripting("start", None, None)
    except GLib.Error:
        sys.stdout.write("R 0\n")
        sys.stdout.flush()
    GLib.timeout_add(1500, unload_activate)


def on_stdin(channel, condition):
    if condition & (GLib.IO_HUP | GLib.IO_ERR):
        return False
    line = channel.readline()
    if not line:
        return False
    parts = line.rstrip("\n").split("\t")
    if parts[0] == "activate" and len(parts) == 3:
        activate(parts[1], parts[2])
    return True


def stop(*_):
    unload()
    unload_activate()
    loop.quit()


Gio.bus_own_name_on_connection(bus, NAME, Gio.BusNameOwnerFlags.REPLACE | Gio.BusNameOwnerFlags.ALLOW_REPLACEMENT,
                               on_name_acquired, lambda *_: stop())
on_bus_acquired(bus, NAME)
for member in ("layoutChanged", "layoutListChanged"):
    bus.signal_subscribe("org.kde.keyboard", "org.kde.KeyboardLayouts", member, "/Layouts", None,
                         Gio.DBusSignalFlags.NONE, emit_layout)
emit_layout()
stdin = GLib.IOChannel.unix_new(sys.stdin.fileno())
GLib.io_add_watch(stdin, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, on_stdin)
signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
GLib.timeout_add(500, lambda: True)
loop.run()
