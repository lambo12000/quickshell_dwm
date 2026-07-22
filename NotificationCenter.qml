import Quickshell
import Quickshell.Widgets
import QtQuick

// Bar widget: hamburger button that opens the notification history panel.
// Each entry has a pin toggle that classifies its app: pinned apps get
// persistent toasts, unpinned apps auto-expire.
Item {
    id: nc

    required property var bar

    width: 26
    height: 22

    function resolveIcon(e) {
        let p = e.icon ? Quickshell.iconPath(e.icon, true) : "";
        if (p === "" && e.de) {
            const d = DesktopEntries.heuristicLookup(e.de);
            if (d)
                p = Quickshell.iconPath(d.icon, true);
        }
        if (p === "" && e.app) {
            const d = DesktopEntries.heuristicLookup(e.app);
            if (d)
                p = Quickshell.iconPath(d.icon, true);
        }
        return p;
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: ncMouse.containsMouse ? Theme.hover : "transparent"

        Column {
            anchors.centerIn: parent
            spacing: 3

            Repeater {
                model: 3
                delegate: Rectangle {
                    width: 13
                    height: 1.6
                    radius: 1
                    color: Theme.fg
                }
            }
        }

        MouseArea {
            id: ncMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (popup.visible) {
                    popup.visible = false;
                    return;
                }
                const p = nc.mapToItem(null, 0, 0);
                popup.anchor.rect.x = Math.max(8, p.x + nc.width - popup.implicitWidth);
                popup.anchor.rect.y = Theme.barHeight;
                PopupGuard.claim(popup);
                popup.visible = true;
            }
        }
    }

    PopupWindow {
        id: popup

        anchor.window: nc.bar
        implicitWidth: 380
        implicitHeight: Math.min(560, headerRow.height + list.contentHeight + 42)
        visible: false
        color: "transparent"

        HoverHandler {
            id: popupHover
        }

        Timer {
            interval: 4000
            running: popup.visible && !popupHover.hovered
            onTriggered: popup.visible = false
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Theme.popupBg
            border.color: Theme.popupBorder
            border.width: 1

            Item {
                id: headerRow
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                height: 24

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    color: Theme.fg
                    font.pixelSize: 14
                    font.bold: true
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: NotificationStore.history.length > 0
                    width: clearText.implicitWidth + 14
                    height: 22
                    radius: 6
                    color: clearMouse.containsMouse ? Theme.hover : "transparent"

                    Text {
                        id: clearText
                        anchors.centerIn: parent
                        text: "Clear All"
                        color: Theme.fgDim
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: NotificationStore.clearHistory()
                    }
                }
            }

            Text {
                visible: NotificationStore.history.length === 0
                anchors.top: headerRow.bottom
                anchors.topMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No notifications"
                color: Theme.fgDim
                font.pixelSize: 12
            }

            ListView {
                id: list
                anchors.top: headerRow.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.bottomMargin: 10
                clip: true
                spacing: 6
                model: NotificationStore.history

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    readonly property bool pinned: NotificationStore.modeFor(modelData.app) === "persist"

                    width: list.width
                    implicitHeight: entryCol.implicitHeight + 16
                    radius: 8
                    color: entryHover.hovered ? Theme.hover : "#1affffff"

                    HoverHandler {
                        id: entryHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onClicked: NotificationStore.removeHistoryAt(index)
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        anchors.rightMargin: 56
                        spacing: 10

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 26
                            visible: source != ""
                            source: nc.resolveIcon(parent.parent.modelData)
                        }

                        Column {
                            id: entryCol
                            width: parent.width - 36
                            spacing: 1

                            Row {
                                width: parent.width
                                spacing: 6

                                Text {
                                    text: modelData.app
                                    color: Theme.fgDim
                                    font.pixelSize: 10
                                }

                                Text {
                                    text: NotificationStore.timeAgo(modelData.time)
                                    color: Theme.fgDim
                                    font.pixelSize: 10
                                }
                            }

                            Text {
                                width: parent.width
                                text: modelData.summary
                                color: Theme.fg
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: modelData.body
                                color: Theme.fgDim
                                font.pixelSize: 11
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // pin toggle: classify this app persistent/timed
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 28
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: 6
                        color: pinMouse.containsMouse ? Theme.hover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                            text: "\u{f0403}" // 󰐃 pin
                            color: pinned ? Theme.accent : Theme.fgDim
                        }

                        MouseArea {
                            id: pinMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: NotificationStore.toggleMode(modelData.app)
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: 6
                        color: delMouse.containsMouse ? Theme.hover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: Theme.fgDim
                            font.pixelSize: 10
                        }

                        MouseArea {
                            id: delMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: NotificationStore.removeHistoryAt(index)
                        }
                    }
                }
            }
        }
    }
}
