pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

// Keeps the screen awake while something is playing or an app asks us to.
//
// A small helper owns org.freedesktop.ScreenSaver (Firefox, mpv, Zoom … all
// speak it) and reports its live inhibitor list as one JSON line per change.
// MPRIS players and a manual toggle are folded into the same blocker list.
//
// While anything blocks, a timer pokes the X server with `xset s reset`. No
// screensaver or DPMS setting is ever modified, so a quickshell crash leaves
// blanking fully intact.
Singleton {
    id: root

    // parsed from the helper: [{cookie, app, reason}]
    property var dbusInhibitors: []
    // manual override; session-only, deliberately not persisted
    property bool keepAwake: false

    // reading isPlaying on each player registers a dependency on it, so this
    // re-evaluates on play/pause as well as on players appearing/leaving
    readonly property var mprisBlockers: {
        const out = [];
        const ps = Mpris.players.values;
        for (let i = 0; i < ps.length; i++) {
            if (ps[i].isPlaying)
                out.push({
                    source: "mpris",
                    label: ps[i].identity || ps[i].dbusName,
                    detail: "Playing media"
                });
        }
        return out;
    }

    // everything holding the screen awake: [{source, label, detail}]
    readonly property var blockers:
        dbusInhibitors.map(i => ({
            source: "dbus",
            label: i.app || "Unknown",
            detail: i.reason || ""
        }))
        .concat(mprisBlockers)
        .concat(keepAwake ? [{
            source: "manual",
            label: "Keep screen awake",
            detail: "Manual toggle"
        }] : [])

    readonly property bool inhibited: blockers.length > 0

    function setKeepAwake(v) {
        keepAwake = v;
    }

    // The helper always prints its full state, never deltas, so a dropped or
    // malformed line costs nothing — the next good one resyncs.
    function handleLine(line) {
        const s = line.trim();
        if (s === "")
            return;
        try {
            const d = JSON.parse(s);
            if (Array.isArray(d.inhibitors))
                root.dbusInhibitors = d.inhibitors;
        } catch (e) {
            console.warn("ScreensaverStore: bad helper output:", s);
        }
    }

    Process {
        id: helper

        command: [Quickshell.shellPath("screensaver/qs-screensaver-helper")]
        running: true

        stdout: SplitParser {
            onRead: data => root.handleLine(data)
        }

        // the helper's inhibitors died with it; a replacement starts empty
        onExited: {
            root.dbusInhibitors = [];
            restart.restart();
        }
    }

    // also covers a missing binary (fresh clone, no make): harmless retry loop
    Timer {
        id: restart
        interval: 2000
        onTriggered: helper.running = true
    }

    // `xset s reset` counts as user activity, resetting the screensaver and
    // DPMS idle counters alike; 50s beats any timeout of a minute or more
    Timer {
        interval: 50000
        repeat: true
        running: root.inhibited
        triggeredOnStart: true // the screen may be seconds from blanking
        onTriggered: Quickshell.execDetached(["xset", "s", "reset"])
    }
}
