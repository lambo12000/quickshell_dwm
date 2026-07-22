import Quickshell
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Bar {}
    }

    Launcher {}

    NotificationToasts {}
}
