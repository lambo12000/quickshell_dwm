pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Small persisted user preferences (survives logout/login).
Singleton {
    id: root

    property bool tipsEnabled: true
    // per-monitor wallpaper: output name -> absolute image path
    property var wallpapers: ({})

    function setTipsEnabled(v) {
        tipsEnabled = v;
        save();
    }

    function setWallpapers(w) {
        wallpapers = w;
        save();
    }

    function save() {
        store.setText(JSON.stringify({
            tipsEnabled: tipsEnabled,
            wallpapers: wallpapers
        }, null, 2));
    }

    FileView {
        id: store
        path: Quickshell.shellPath("settings.json")
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (d.tipsEnabled !== undefined)
                    root.tipsEnabled = d.tipsEnabled;
                if (d.wallpapers !== undefined)
                    root.wallpapers = d.wallpapers;
            } catch (e) {}
        }
        onLoadFailed: root.save() // first run: create with defaults
    }
}
