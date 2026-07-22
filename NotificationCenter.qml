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
                model: NotificationStore.groupedHistory()

                // apps whose stacks are expanded to individual entries
                property var expandedApps: ({})

                function isExpanded(app) {
                    return expandedApps[app] === true;
                }

                function toggleExpanded(app) {
                    const e = Object.assign({}, expandedApps);
                    e[app] = !e[app];
                    expandedApps = e;
                }

                delegate: Column {
                    id: groupCol

                    required property var modelData
                    readonly property var group: modelData
                    readonly property bool multi: group.entries.length > 1
                    readonly property bool expanded: multi && list.isExpanded(group.app)

                    width: list.width
                    spacing: 4

                    Repeater {
                        model: groupCol.expanded ? groupCol.group.entries : [groupCol.group.entries[0]]

                        delegate: Item {
                            id: wrap

                            required property var modelData
                            required property int index
                            // collapsed stack header (multiple entries hidden behind it)
                            readonly property bool stackHead: groupCol.multi && !groupCol.expanded
                            readonly property bool pinned: NotificationStore.modeFor(modelData.app) === "persist"

                            width: groupCol.width
                            height: entryCard.height + (stackHead ? 8 : 0)

                            // stacked-card edges peeking below (same look as toasts)
                            Rectangle {
                                visible: wrap.stackHead && groupCol.group.entries.length > 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: entryCard.height - 2
                                width: parent.width - 44
                                height: 8
                                radius: 8
                                color: "#29292d"
                                border.color: Theme.popupBorder
                                border.width: 1
                            }

                            Rectangle {
                                visible: wrap.stackHead
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: entryCard.height - 6
                                width: parent.width - 22
                                height: 10
                                radius: 10
                                color: "#2e2e33"
                                border.color: Theme.popupBorder
                                border.width: 1
                            }

                            Rectangle {
                                id: entryCard
                                width: parent.width
                                implicitHeight: entryCol.implicitHeight + 16
                                radius: 8
                                // opaque equivalents of the old translucent overlays so the
                                // stacked edges tucked underneath don't show through
                                color: entryHover.hovered ? "#454549" : "#39393d"

                                HoverHandler {
                                    id: entryHover
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            // right-click: remove entry (whole stack if collapsed)
                                            if (wrap.stackHead)
                                                NotificationStore.removeApp(groupCol.group.app);
                                            else
                                                NotificationStore.removeEntry(wrap.modelData);
                                        } else if (groupCol.multi) {
                                            list.toggleExpanded(groupCol.group.app);
                                        }
                                    }
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
                                        source: nc.resolveIcon(wrap.modelData)
                                    }

                                    Column {
                                        id: entryCol
                                        width: parent.width - 36
                                        spacing: 1

                                        Row {
                                            width: parent.width
                                            spacing: 6

                                            Text {
                                                text: wrap.modelData.app
                                                color: Theme.fgDim
                                                font.pixelSize: 10
                                            }

                                            Text {
                                                text: NotificationStore.timeAgo(wrap.modelData.time)
                                                color: Theme.fgDim
                                                font.pixelSize: 10
                                            }

                                            // count badge on collapsed stacks
                                            Rectangle {
                                                visible: wrap.stackHead
                                                anchors.verticalCenter: parent.verticalCenter
                                                height: 14
                                                width: Math.max(14, stackBadge.implicitWidth + 8)
                                                radius: 7
                                                color: "#3dffffff"

                                                Text {
                                                    id: stackBadge
                                                    anchors.centerIn: parent
                                                    text: groupCol.group.entries.length
                                                    color: Theme.fg
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                }
                                            }
                                        }

                                        Text {
                                            width: parent.width
                                            text: wrap.modelData.summary
                                            color: Theme.fg
                                            font.pixelSize: 12
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            visible: text !== ""
                                            text: wrap.modelData.body
                                            color: Theme.fgDim
                                            font.pixelSize: 11
                                            maximumLineCount: 2
                                            wrapMode: Text.Wrap
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                // pin toggle on the first row of each app group
                                Rectangle {
                                    visible: wrap.index === 0
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
                                        color: wrap.pinned ? Theme.accent : Theme.fgDim
                                    }

                                    MouseArea {
                                        id: pinMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: NotificationStore.toggleMode(wrap.modelData.app)
                                    }
                                }

                                // remove entry (whole stack when collapsed)
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
                                        onClicked: {
                                            if (wrap.stackHead)
                                                NotificationStore.removeApp(groupCol.group.app);
                                            else
                                                NotificationStore.removeEntry(wrap.modelData);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
