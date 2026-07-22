import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick

// macOS-style toast stack, top-right of the primary screen.
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

    Column {
        id: col
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Repeater {
            model: NotificationStore.toasts.slice(0, 5)

            delegate: Rectangle {
                id: card

                required property var modelData
                readonly property bool persist:
                    modelData.urgency === NotificationUrgency.Critical
                    || NotificationStore.modeFor(modelData.appName) === "persist"

                width: col.width
                implicitHeight: Math.max(60, cardRow.implicitHeight + 20)
                radius: 12
                color: "#242428"
                border.color: Theme.popupBorder
                border.width: 1

                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: 160 } }

                HoverHandler {
                    id: cardHover
                }

                Timer {
                    interval: card.modelData.expireTimeout > 0
                        ? card.modelData.expireTimeout
                        : NotificationStore.defaultTimeoutMs
                    running: !card.persist && !cardHover.hovered
                    onTriggered: card.modelData.expire()
                }

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
                        source: card.modelData.image !== ""
                            ? card.modelData.image
                            : Quickshell.iconPath(card.modelData.appIcon, true)
                    }

                    Column {
                        width: parent.width - 42
                        spacing: 2

                        Text {
                            width: parent.width
                            text: card.modelData.summary || card.modelData.appName
                            color: Theme.fg
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: card.modelData.body
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
                        if (mouse.button === Qt.LeftButton) {
                            const acts = card.modelData.actions;
                            if (acts && acts.length > 0)
                                acts[0].invoke();
                        }
                        card.modelData.dismiss();
                    }
                }

                // close button
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
                        onClicked: card.modelData.dismiss()
                    }
                }
            }
        }
    }
}
