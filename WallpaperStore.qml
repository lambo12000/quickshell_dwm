pragma Singleton
import Quickshell
import QtQuick

// Applies per-monitor wallpapers with xwallpaper. Selections persist in
// Settings (settings.json) and are re-applied whenever they change —
// including once at startup when Settings finishes loading.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    function wallpaperFor(screenName) {
        return Settings.wallpapers[screenName] || "";
    }

    function setWallpaper(screenName, path) {
        const w = Object.assign({}, Settings.wallpapers);
        w[screenName] = path;
        Settings.setWallpapers(w);
    }

    // xwallpaper repaints the entire root pixmap on every call, so each
    // invocation must cover every output; a monitor without its own pick
    // borrows another's image rather than going black.
    function apply() {
        const w = Settings.wallpapers;
        const set = Object.keys(w).filter(n => w[n] !== "");
        if (set.length === 0)
            return;
        const args = ["xwallpaper"];
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            const name = screens[i].name;
            args.push("--output", name, "--zoom", w[name] || w[set[0]]);
        }
        Quickshell.execDetached(args);
    }

    Connections {
        target: Settings
        function onWallpapersChanged() {
            root.apply();
        }
    }

    // covers the case where Settings finished loading before this (lazy)
    // singleton was instantiated; a no-op when nothing is saved yet
    Component.onCompleted: apply()
}
