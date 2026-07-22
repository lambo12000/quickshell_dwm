import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick

// macOS-style toast stack, top-right of the primary screen.
// Toasts from the same app stack into one card with a count badge;
// the newest is shown on top with stacked-card edges peeking below.
PanelWindow {
    id: win

    screen: Quickshell.screens[0]
    visible: NotificationStore.toasts.length > 0
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.barHeight + 10
        right: 10
    }

    implicitWidth: 360
    implicitHeight: Math.max(1, col.implicitHeight)

    // group live toasts (newest first) by app
    readonly property var groups: {
        const out = [];
        for (let i = 0; i < NotificationStore.toasts.length; i++) {
            const n = NotificationStore.toasts[i];
            const app = n.appName || "Unknown";
            let g = null;
            for (let j = 0; j < out.length; j++) {
                if (out[j].app === app) {
                    g = out[j];
                    break;
                }
            }
            if (!g) {
                g = { app: app, items: [] };
                out.push(g);
            }
            g.items.push(n);
        }
        return out;
    }

    function dismissAll(items) {
        for (let i = 0; i < items.length; i++)
            items[i].dismiss();
    }

    Column {
        id: col
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        Repeater {
            model: win.groups.slice(0, 5)

            delegate: Item {
                id: stack

                required property var modelData
                readonly property var head: modelData.items[0]
                readonly property int count: modelData.items.length
                readonly property bool persist:
                    head.urgency === NotificationUrgency.Critical
                    || NotificationStore.modeFor(head.appName) === "persist"

                width: col.width
                height: card.height + (count > 1 ? 8 : 0)

                onHeadChanged: expireTimer.restart()

                HoverHandler {
                    id: cardHover
                }

                Timer {
                    id: expireTimer
                    interval: stack.head.expireTimeout > 0
                        ? stack.head.expireTimeout
                        : NotificationStore.defaultTimeoutMs
                    running: !stack.persist && !cardHover.hovered
                    onTriggered: stack.head.expire()
                }

                // stacked-card edges peeking below
                Rectangle {
                    visible: stack.count > 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: card.height - 2
                    width: parent.width - 44
                    height: 8
                    radius: 8
                    color: "#1a1a1e"
                    border.color: Theme.popupBorder
                    border.width: 1
                }

                Rectangle {
                    visible: stack.count > 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: card.height - 6
                    width: parent.width - 22
                    height: 10
                    radius: 10
                    color: "#1e1e22"
                    border.color: Theme.popupBorder
                    border.width: 1
                }

                Rectangle {
                    id: card
                    width: parent.width
                    height: Math.max(60, cardRow.implicitHeight + 20)
                    radius: 12
                    color: "#242428"
                    border.color: Theme.popupBorder
                    border.width: 1

                    opacity: 0
                    Component.onCompleted: opacity = 1
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    Row {
                        id: cardRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        anchors.rightMargin: 30
                        spacing: 10

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 32
                            visible: source != ""
                            source: stack.head.image !== ""
                                ? stack.head.image
                                : Quickshell.iconPath(stack.head.appIcon, true)
                        }

                        Column {
                            width: parent.width - 42
                            spacing: 2

                            Text {
                                width: parent.width
                                text: stack.head.summary || stack.head.appName
                                color: Theme.fg
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: stack.head.body
                                color: Theme.fgDim
                                font.pixelSize: 12
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                // right-click clears the whole stack
                                win.dismissAll(stack.modelData.items);
                                return;
                            }
                            const acts = stack.head.actions;
                            if (acts && acts.length > 0)
                                acts[0].invoke();
                            stack.head.dismiss();
                        }
                    }

                    // count badge
                    Rectangle {
                        visible: stack.count > 1
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        height: 16
                        width: Math.max(16, badgeText.implicitWidth + 10)
                        radius: 8
                        color: "#3dffffff"

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: stack.count
                            color: Theme.fg
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    // close button clears the whole stack
                    Rectangle {
                        visible: cardHover.hovered
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: 18
                        height: 18
                        radius: 9
                        color: closeMouse.containsMouse ? Theme.hover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: Theme.fgDim
                            font.pixelSize: 10
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: win.dismissAll(stack.modelData.items)
                        }
                    }
                }
            }
        }
    }
}
