pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Reads dwm's exported state (written by the patched dwm on every bar redraw)
// and sends commands back by injecting the bound keys via xdotool.
Singleton {
    id: root

    property var monitors: []

    function monitorFor(screen) {
        if (!screen)
            return null;
        for (let i = 0; i < monitors.length; i++) {
            const m = monitors[i];
            if (m.x === screen.x && m.y === screen.y)
                return m;
        }
        return null;
    }

    function key(combo) {
        Quickshell.execDetached(["xdotool", "key", "--clearmodifiers", combo]);
    }

    // set_desktop maps to a monitor in the patched dwm; chaining both commands
    // in one xdotool process guarantees the monitor switch reaches the X server
    // before the synthetic key events.
    // Deployment: requires a dwm that advertises _NET_CURRENT_DESKTOP. Install
    // the rebuilt binary (make install, i.e. /usr/local/bin/dwm) and restart
    // dwm before or together with reloading quickshell — against an older dwm,
    // xdotool's support check aborts the whole chain, so no key is ever sent
    // and every tag/layout click becomes a silent no-op
    function keyOnMonitor(num, combo) {
        Quickshell.execDetached(["xdotool", "set_desktop", String(num), "key", "--clearmodifiers", combo]);
    }

    // xdotool sends _NET_ACTIVE_WINDOW, which the local dwm patch handles by
    // switching to the window's monitor and tag before focusing it
    function activate(win) {
        Quickshell.execDetached(["xdotool", "windowactivate", String(win)]);
    }

    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/dwm-state.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.monitors = JSON.parse(text());
            } catch (e) {
                // partial write; the next change event re-parses
            }
        }
    }
}
