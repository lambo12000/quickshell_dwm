import Quickshell
import Quickshell.Networking
import QtQuick

Item {
    id: netw

    required property var bar

    readonly property var wiredDev: firstDevice(DeviceType.Wired)
    readonly property var wifiDev: firstDevice(DeviceType.Wifi)
    readonly property var activeDev: (wiredDev && wiredDev.connected) ? wiredDev
        : (wifiDev && wifiDev.connected) ? wifiDev
        : (wiredDev || wifiDev)
    readonly property bool online: activeDev ? activeDev.connected : false

    width: 26
    height: 22

    function firstDevice(t) {
        const ds = Networking.devices.values;
        for (let i = 0; i < ds.length; i++) {
            if (ds[i].type === t)
                return ds[i];
        }
        return null;
    }

    function wifiGlyph(strength) {
        const s = strength > 1 ? strength / 100 : strength;
        if (s > 0.8) return "\u{f0928}"; // 󰤨
        if (s > 0.6) return "\u{f0925}"; // 󰤥
        if (s > 0.4) return "\u{f0922}"; // 󰤢
        if (s > 0.2) return "\u{f091f}"; // 󰤟
        return "\u{f092f}";              // 󰤯
    }

    function connectedWifiStrength() {
        if (!wifiDev)
            return 0;
        const ns = wifiDev.networks.values;
        for (let i = 0; i < ns.length; i++) {
            if (ns[i].connected)
                return ns[i].signalStrength;
        }
        return 0;
    }

    function sortedWifiNetworks() {
        if (!wifiDev)
            return [];
        return [...wifiDev.networks.values]
            .sort((a, b) => b.signalStrength - a.signalStrength)
            .slice(0, 10);
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: netMouse.containsMouse ? Theme.hover : "transparent"

        Text {
            anchors.centerIn: parent
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
            color: netw.online ? Theme.fg : Theme.fgDim
            text: !netw.online ? "\u{f0318}" // 󰌘 disconnected
                : netw.activeDev.type === DeviceType.Wired ? "\u{f0200}" // 󰈀 ethernet
                : netw.wifiGlyph(netw.connectedWifiStrength())
        }

        MouseArea {
            id: netMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (popup.visible) {
                    popup.visible = false;
                    return;
                }
                const p = netw.mapToItem(null, 0, 0);
                popup.anchor.rect.x = Math.max(8, p.x + netw.width - popup.implicitWidth);
                popup.anchor.rect.y = Theme.barHeight;
                PopupGuard.claim(popup);
                popup.visible = true;
            }
        }
    }

    PopupWindow {
        id: popup

        anchor.window: netw.bar
        implicitWidth: 320
        implicitHeight: popupBox.implicitHeight
        visible: false
        color: "transparent"

        HoverHandler {
            id: popupHover
        }

        Timer {
            interval: 2500
            running: popup.visible && !popupHover.hovered
            onTriggered: popup.visible = false
        }

        Rectangle {
            id: popupBox
            anchors.fill: parent
            implicitHeight: popupCol.implicitHeight + 24
            radius: 12
            color: Theme.popupBg
            border.color: Theme.popupBorder
            border.width: 1

            Column {
                id: popupCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 6

                Text {
                    text: "Network"
                    color: Theme.fg
                    font.pixelSize: 14
                    font.bold: true
                }

                // Wired
                Rectangle {
                    visible: netw.wiredDev !== null
                    width: parent.width
                    height: 34
                    radius: 8
                    color: wiredMouse.containsMouse ? Theme.hover : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize
                        text: "\u{f0200}" // 󰈀
                        color: netw.wiredDev && netw.wiredDev.connected ? Theme.fg : Theme.fgDim
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 34
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Wired" + (netw.wiredDev ? "  (" + netw.wiredDev.name + ")" : "")
                        color: Theme.fg
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: !netw.wiredDev ? ""
                            : netw.wiredDev.connected
                                ? "Connected" + (netw.wiredDev.linkSpeed > 0 ? " · " + netw.wiredDev.linkSpeed + " Mb/s" : "")
                                : "Disconnected"
                        color: netw.wiredDev && netw.wiredDev.connected ? "#7dc87d" : Theme.fgDim
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: wiredMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (!netw.wiredDev)
                                return;
                            if (netw.wiredDev.connected)
                                netw.wiredDev.disconnect();
                            else if (netw.wiredDev.network)
                                netw.wiredDev.network.connect();
                        }
                    }
                }

                // Wi-Fi toggle header
                Rectangle {
                    visible: netw.wifiDev !== null
                    width: parent.width
                    height: 34
                    radius: 8
                    color: "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Wi-Fi"
                        color: Theme.fg
                        font.pixelSize: Theme.fontSize
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 22
                        radius: 11
                        color: Networking.wifiEnabled ? Theme.accent : "#4a4a50"

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: Networking.wifiEnabled ? parent.width - width - 2 : 2
                            Behavior on x { NumberAnimation { duration: 120 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                        }
                    }
                }

                // Wi-Fi networks
                Repeater {
                    model: netw.wifiDev && Networking.wifiEnabled ? netw.sortedWifiNetworks() : []

                    delegate: Rectangle {
                        required property var modelData

                        width: popupCol.width
                        height: 30
                        radius: 8
                        color: wnMouse.containsMouse ? Theme.hover : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: Theme.iconFont
                            font.pixelSize: 14
                            text: netw.wifiGlyph(modelData.signalStrength)
                            color: modelData.connected ? Theme.accent : Theme.fg
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 32
                            anchors.right: parent.right
                            anchors.rightMargin: 40
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            color: modelData.connected ? Theme.accent : Theme.fg
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                            text: modelData.connected ? "\u{f012c}" // 󰄬 check
                                : modelData.security ? "\u{f033e}" // 󰌾 lock
                                : ""
                            color: Theme.fgDim
                        }

                        MouseArea {
                            id: wnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (modelData.connected) {
                                    modelData.disconnect();
                                } else if (modelData.known || !modelData.security) {
                                    modelData.connect();
                                } else {
                                    // needs a passphrase; hand off to nmtui
                                    Quickshell.execDetached(["ghostty", "-e", "nmtui"]);
                                    popup.visible = false;
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 30
                    radius: 8
                    color: editMouse.containsMouse ? Theme.hover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "Edit connections…"
                        color: Theme.fgDim
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: editMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            Quickshell.execDetached(["ghostty", "-e", "nmtui"]);
                            popup.visible = false;
                        }
                    }
                }
            }
        }
    }
}
