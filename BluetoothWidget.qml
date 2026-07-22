import Quickshell
import Quickshell.Bluetooth
import QtQuick

Item {
    id: btw

    required property var bar

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter !== null && adapter.enabled

    function knownDevices() {
        const ds = Bluetooth.devices.values;
        return ds.filter(d => d.paired || d.bonded || d.connected)
            .sort((a, b) => (b.connected - a.connected) || (a.name < b.name ? -1 : 1));
    }

    function anyConnected() {
        const ds = Bluetooth.devices.values;
        for (let i = 0; i < ds.length; i++) {
            if (ds[i].connected)
                return true;
        }
        return false;
    }

    visible: adapter !== null
    width: 26
    height: 22

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: btMouse.containsMouse ? Theme.hover : "transparent"

        Text {
            anchors.centerIn: parent
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
            color: btw.on ? (btw.anyConnected() ? Theme.accent : Theme.fg) : Theme.fgDim
            text: !btw.on ? "\u{f00b2}" // 󰂲 bluetooth off
                : btw.anyConnected() ? "\u{f00b1}" // 󰂱 connected
                : "\u{f00af}" // 󰂯 on
        }

        MouseArea {
            id: btMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (popup.visible) {
                    popup.visible = false;
                    return;
                }
                const p = btw.mapToItem(null, 0, 0);
                popup.anchor.rect.x = Math.max(8, p.x + btw.width - popup.implicitWidth);
                popup.anchor.rect.y = Theme.barHeight;
                PopupGuard.claim(popup);
                popup.visible = true;
            }
        }
    }

    PopupWindow {
        id: popup

        anchor.window: btw.bar
        implicitWidth: 300
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

                Rectangle {
                    width: parent.width
                    height: 26
                    color: "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Bluetooth"
                        color: Theme.fg
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 22
                        radius: 11
                        color: btw.on ? Theme.accent : "#4a4a50"

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: btw.on ? parent.width - width - 2 : 2
                            Behavior on x { NumberAnimation { duration: 120 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (btw.adapter)
                                    btw.adapter.enabled = !btw.adapter.enabled;
                            }
                        }
                    }
                }

                Repeater {
                    model: btw.on ? btw.knownDevices() : []

                    delegate: Rectangle {
                        required property var modelData

                        width: popupCol.width
                        height: 32
                        radius: 8
                        color: devMouse.containsMouse ? Theme.hover : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 110
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name || modelData.deviceName || modelData.address
                            color: modelData.connected ? Theme.accent : Theme.fg
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: (modelData.batteryAvailable
                                    ? Math.round(modelData.battery * 100) + "%  " : "")
                                + (modelData.connected ? "Connected"
                                    : modelData.pairing ? "Pairing…" : "")
                            color: modelData.connected ? "#7dc87d" : Theme.fgDim
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: devMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (modelData.connected)
                                    modelData.disconnect();
                                else
                                    modelData.connect();
                            }
                        }
                    }
                }

                Text {
                    visible: btw.on && btw.knownDevices().length === 0
                    text: "No paired devices"
                    color: Theme.fgDim
                    font.pixelSize: 12
                }

                Rectangle {
                    width: parent.width
                    height: 30
                    radius: 8
                    color: manageMouse.containsMouse ? Theme.hover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "Manage devices…"
                        color: Theme.fgDim
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: manageMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            Quickshell.execDetached(["ghostty", "-e", "bluetoothctl"]);
                            popup.visible = false;
                        }
                    }
                }
            }
        }
    }
}
