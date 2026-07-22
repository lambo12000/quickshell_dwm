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

        Repeater {
            model: 9

            delegate: Rectangle {
                required property int index
                readonly property bool tagSelected: bar.mon ? (bar.mon.tags & (1 << index)) !== 0 : index === 0
                readonly property bool occupied: bar.mon ? (bar.mon.occ & (1 << index)) !== 0 : false
                readonly property bool tagUrgent: bar.mon ? (bar.mon.urg & (1 << index)) !== 0 : false

                width: 24
                height: 22
                radius: 6
                color: tagSelected ? Theme.accent
                     : tagUrgent ? Theme.urgent
                     : tagMouse.containsMouse ? Theme.hover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: index + 1
                    color: parent.tagSelected || parent.tagUrgent ? "#ffffff"
                         : parent.occupied ? Theme.fg : Theme.fgDim
                    font.pixelSize: Theme.fontSize
                }

                Rectangle {
                    visible: parent.occupied && !parent.tagSelected
                    width: 4
                    height: 4
                    radius: 2
                    color: Theme.fg
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                }

                MouseArea {
                    id: tagMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => DwmState.key(
                        (mouse.button === Qt.RightButton ? "super+ctrl+" : "super+") + (parent.index + 1))
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
