pragma Singleton
import Quickshell
import QtQuick

// Maps an X11 WM_CLASS to an icon path. heuristicLookup scans every .desktop
// file, and both bars re-resolve every client on each dwm state change, so the
// results are memoised here rather than in the delegates.
Singleton {
    id: root

    property var cache: ({})

    // "" when nothing resolves — callers fall back to a monogram
    function iconFor(wmClass) {
        if (!wmClass)
            return "";
        if (wmClass in root.cache)
            return root.cache[wmClass];

        // prefer the desktop entry's declared Icon= (handles classes that differ
        // from the icon name, e.g. Firefox's instance "Navigator"), then try the
        // class as an icon name directly
        let path = "";
        const entry = DesktopEntries.heuristicLookup(wmClass);
        if (entry && entry.icon)
            path = Quickshell.iconPath(entry.icon, true);
        if (path === "")
            path = Quickshell.iconPath(wmClass, true);

        root.cache[wmClass] = path;
        return path;
    }

    function monogramFor(wmClass) {
        return wmClass ? wmClass.charAt(0).toUpperCase() : "?";
    }
}
