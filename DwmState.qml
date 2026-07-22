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
