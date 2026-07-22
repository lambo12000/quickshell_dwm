pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Small persisted user preferences (survives logout/login).
Singleton {
    id: root

    property bool tipsEnabled: true

    function setTipsEnabled(v) {
        tipsEnabled = v;
        save();
    }

    function save() {
        store.setText(JSON.stringify({ tipsEnabled: tipsEnabled }, null, 2));
    }

    FileView {
        id: store
        path: Quickshell.shellPath("settings.json")
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (d.tipsEnabled !== undefined)
                    root.tipsEnabled = d.tipsEnabled;
            } catch (e) {}
        }
        onLoadFailed: root.save() // first run: create with defaults
    }
}
