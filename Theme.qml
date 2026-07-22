pragma Singleton
import Quickshell
import QtQuick

Singleton {
    readonly property int barHeight: 30

    readonly property color barBg: "#1d1d22"
    readonly property color popupBg: "#232327"
    readonly property color popupBorder: "#3dffffff"
    readonly property color fg: "#e8e8ec"
    readonly property color fgDim: "#8a8a92"
    readonly property color accent: "#2f6bd8"
    readonly property color urgent: "#e05555"
    readonly property color hover: "#2affffff"

    readonly property string iconFont: "JetBrainsMono Nerd Font Propo"
    readonly property int fontSize: 13
    readonly property int iconSize: 16
}
