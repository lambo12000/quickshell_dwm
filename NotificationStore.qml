pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

// Owns org.freedesktop.Notifications (replaces dunst), keeps history,
// and holds per-app rules: "timed" toasts auto-expire, "persist" toasts
// stay until dismissed.
Singleton {
    id: root

    readonly property int defaultTimeoutMs: 6000
    readonly property int historyLimit: 50
    readonly property string storePath: Quickshell.shellPath("notification-data.json")

    property var toasts: []   // live Notification objects
    property var history: []  // plain {app, summary, body, icon, de, time}
    property var rules: ({})  // lowercased app name -> "timed" | "persist"

    // minute tick so "Xm ago" labels re-evaluate
    readonly property date now: clock.date

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Empty app names (e.g. Signal) fall back to "Unknown" everywhere else,
    // so rule lookups must resolve the same key.
    function modeFor(appName) {
        return rules[(appName || "Unknown").toLowerCase()] || "timed";
    }

    function toggleMode(appName) {
        const r = JSON.parse(JSON.stringify(rules));
        const k = (appName || "Unknown").toLowerCase();
        r[k] = (r[k] === "persist") ? "timed" : "persist";
        rules = r;
        save();
    }

    function removeEntry(e) {
        history = history.filter(x => x !== e);
        save();
    }

    function removeApp(app) {
        history = history.filter(x => x.app !== app);
        save();
    }

    // newest-first history grouped by app: [{app, entries: [...]}]
    function groupedHistory() {
        const out = [];
        for (let i = 0; i < history.length; i++) {
            const e = history[i];
            let g = null;
            for (let j = 0; j < out.length; j++) {
                if (out[j].app === e.app) {
                    g = out[j];
                    break;
                }
            }
            if (!g) {
                g = { app: e.app, entries: [] };
                out.push(g);
            }
            g.entries.push(e);
        }
        return out;
    }

    function clearHistory() {
        history = [];
        save();
    }

    function timeAgo(t) {
        const mins = Math.floor((now.getTime() - t) / 60000);
        if (mins < 1)
            return "now";
        if (mins < 60)
            return mins + "m ago";
        if (mins < 1440)
            return Math.floor(mins / 60) + "h ago";
        return Qt.formatDateTime(new Date(t), "MMM d");
    }

    function save() {
        store.setText(JSON.stringify({ rules: rules, history: history }, null, 2));
    }

    NotificationServer {
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;

            const h = root.history.slice();
            h.unshift({
                app: n.appName || "Unknown",
                summary: n.summary,
                body: n.body,
                icon: n.appIcon || "",
                de: n.desktopEntry || "",
                time: Date.now()
            });
            root.history = h.slice(0, root.historyLimit);
            root.save();

            root.toasts = [n].concat(root.toasts);
            n.closed.connect(() => {
                root.toasts = root.toasts.filter(t => t !== n);
            });
        }
    }

    FileView {
        id: store
        path: root.storePath
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (d.rules)
                    root.rules = d.rules;
                if (d.history)
                    root.history = d.history;
            } catch (e) {}
        }
        onLoadFailed: root.save() // first run: create the file
    }
}
