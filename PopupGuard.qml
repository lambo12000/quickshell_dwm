pragma Singleton
import Quickshell
import QtQuick

// Only one bar popup may be open at a time. The previous popup is hidden
// shortly AFTER the new one maps (new windows stack on top), so the swap
// is a single visual change instead of an unmap/map flicker.
Singleton {
    id: root

    property var current: null
    property var pending: null

    function claim(p) {
        if (current === p)
            return;
        if (pending && pending !== p)
            pending.visible = false;
        pending = current;
        current = p;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 80
        onTriggered: {
            if (root.pending && root.pending !== root.current)
                root.pending.visible = false;
            root.pending = null;
        }
    }
}
