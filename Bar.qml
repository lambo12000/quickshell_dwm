import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: bar

    required property var modelData
    readonly property var mon: DwmState.monitorFor(bar.screen)

    screen: modelData
    aboveWindows: true
    color: Theme.barBg

    readonly property int maxSubIcons: 3

    // One app icon: the real icon when the WM_CLASS resolves, otherwise a
    // monogram chip so two unresolved apps stay distinguishable. Left-click
    // jumps to that window; other buttons fall through to the tag pill below.
    component AppIcon: Item {
        id: appIcon

        required property var client
        required property int size

        readonly property string wmClass: client ? client.class : ""
        readonly property string iconPath: AppIcons.iconFor(appIcon.wmClass)

        implicitWidth: size
        implicitHeight: size

        IconImage {
            anchors.fill: parent
            visible: appIcon.iconPath !== ""
            source: appIcon.iconPath
        }

        Rectangle {
            anchors.fill: parent
            visible: appIcon.iconPath === ""
            radius: Math.max(2, Math.round(appIcon.size / 6))
            color: Theme.hover
            border.width: 1
            border.color: Theme.fgDim

            Text {
                anchors.centerIn: parent
                text: AppIcons.monogramFor(appIcon.wmClass)
                color: Theme.fg
                font.pixelSize: Math.round(appIcon.size * 0.62)
                font.bold: true
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: DwmState.activate(appIcon.client.win)
        }
    }

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight

    function nextLayoutKey() {
        const l = bar.mon ? bar.mon.layout : "[]=";
        if (l === "[]=")
            return "super+f";
        if (l === "><>")
            return "super+m";
        return "super+t";
    }

    // ---- left: tags, layout, focused window title ----
    Row {
        id: leftRow
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        // A tag pill shows the apps living on that tag: dwm's master at full
        // size, then smaller icons for the rest, capped with a "+N". Empty tags
        // keep their number, so all nine positions stay countable.
        Repeater {
            model: 9

            delegate: Item {
                id: tagPill
                required property int index

                readonly property var tagClients: {
                    const all = bar.mon && bar.mon.clients ? bar.mon.clients : [];
                    const mask = 1 << tagPill.index;
                    const out = [];
                    for (let i = 0; i < all.length; i++)
                        if ((all[i].tags & mask) !== 0)
                            out.push(all[i]);
                    return out;
                }

                // dwm's master is the first non-floating client in m->clients
                // order — what tile() would put in the big pane. A tag holding
                // only floating windows falls back to its first client, so the
                // pill never regresses to a bare digit while windows are open.
                readonly property var ordered: {
                    const cs = tagPill.tagClients;
                    if (cs.length === 0)
                        return [];
                    let master = 0;
                    for (let i = 0; i < cs.length; i++) {
                        if (!cs[i].floating) {
                            master = i;
                            break;
                        }
                    }
                    const out = [cs[master]];
                    for (let i = 0; i < cs.length; i++)
                        if (i !== master)
                            out.push(cs[i]);
                    return out;
                }

                readonly property var shownIcons: tagPill.ordered.slice(0, bar.maxSubIcons + 1)
                readonly property int overflow: tagPill.ordered.length - tagPill.shownIcons.length
                readonly property bool occupied: tagPill.ordered.length > 0
                readonly property bool tagSelected: bar.mon ? (bar.mon.tags & (1 << tagPill.index)) !== 0 : tagPill.index === 0
                readonly property bool tagUrgent: bar.mon ? (bar.mon.urg & (1 << tagPill.index)) !== 0 : false

                width: Math.max(24, pillRow.implicitWidth + 12)
                height: 22

                Behavior on width {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: tagPill.tagUrgent
                             ? Qt.rgba(Theme.urgent.r, Theme.urgent.g, Theme.urgent.b, 0.22)
                         : tagMouse.containsMouse ? Theme.hover
                         : "transparent"
                }

                // selected/urgent marker, in the gap between pill and bar edge
                Rectangle {
                    visible: tagPill.tagSelected || tagPill.tagUrgent
                    width: Math.max(12, parent.width - 8)
                    height: 2
                    radius: 1
                    color: tagPill.tagUrgent ? Theme.urgent : Theme.accent
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -3
                }

                Text {
                    visible: !tagPill.occupied
                    anchors.centerIn: parent
                    text: tagPill.index + 1
                    color: tagPill.tagSelected ? Theme.fg : Theme.fgDim
                    font.pixelSize: Theme.fontSize
                }

                Row {
                    id: pillRow
                    visible: tagPill.occupied
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: tagPill.shownIcons

                        delegate: AppIcon {
                            required property int index
                            required property var modelData

                            anchors.verticalCenter: parent.verticalCenter
                            client: modelData
                            size: index === 0 ? 18 : 11
                        }
                    }

                    Text {
                        visible: tagPill.overflow > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+" + tagPill.overflow
                        color: Theme.fgDim
                        font.pixelSize: 9
                    }
                }

                // below the icons in stacking order, so an icon's own click wins
                // and only its unhandled buttons reach the pill
                MouseArea {
                    id: tagMouse
                    z: -1
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => DwmState.key(
                        (mouse.button === Qt.RightButton ? "super+ctrl+" : "super+") + (tagPill.index + 1))
                }
            }
        }

        Item { width: 8; height: 1 }

        Rectangle {
            width: layoutText.implicitWidth + 12
            height: 22
            radius: 6
            color: layoutMouse.containsMouse ? Theme.hover : "transparent"

            Text {
                id: layoutText
                anchors.centerIn: parent
                text: bar.mon ? bar.mon.layout : "[]="
                color: Theme.fgDim
                font.pixelSize: Theme.fontSize
            }

            MouseArea {
                id: layoutMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: DwmState.key(bar.nextLayoutKey())
            }
        }

        Item { width: 10; height: 1 }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            // truncate before reaching the centered tip text
            width: Math.max(0, Math.min(implicitWidth, tipsWidget.x - (leftRow.x + x) - 16))
            text: bar.mon ? bar.mon.title : ""
            color: bar.mon && bar.mon.selected ? Theme.fg : Theme.fgDim
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }
    }

    Tips {
        id: tipsWidget
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        maxWidth: bar.width * 0.30
    }

    // ---- right: tray, network, bluetooth, clock ----
    Row {
        id: rightRow
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: SystemTray.items

            delegate: Rectangle {
                required property var modelData

                width: 26
                height: 22
                radius: 6
                color: trayMouse.containsMouse ? Theme.hover : "transparent"

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 18
                    source: modelData.icon
                }

                function openMenu() {
                    const p = mapToItem(null, 0, 0);
                    trayMenu.openFor(modelData, p.x);
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            if (modelData.onlyMenu && modelData.hasMenu)
                                parent.openMenu();
                            else
                                modelData.activate();
                        } else if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate();
                        } else if (modelData.hasMenu) {
                            parent.openMenu();
                        }
                    }
                }
            }
        }

        Item { width: 4; height: 1 }

        NetworkWidget { bar: bar }
        SoundWidget { bar: bar }
        BluetoothWidget { bar: bar }
        WallpaperWidget { bar: bar }

        Item { width: 4; height: 1 }

        NotificationCenter {
            anchors.verticalCenter: parent.verticalCenter
            bar: bar
        }

        CalendarWidget {
            anchors.verticalCenter: parent.verticalCenter
            bar: bar
        }
    }

    TrayMenu {
        id: trayMenu
        bar: bar
    }
}
