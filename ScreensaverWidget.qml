import Quickshell
import QtQuick

// Bar widget: shows whether the screen is being kept awake and by what.
// The coffee cup lights up while anything blocks blanking.
Item {
    id: ss

    required property var bar

    width: 26
    height: 22

    function sourceGlyph(source) {
        if (source === "mpris")
            return "\u{f040a}"; // 󰐊 play
        if (source === "manual")
            return "\u{f0176}"; // 󰅶 coffee
        return "\u{f02dc}";     // 󰋜 application
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: ssMouse.containsMouse ? Theme.hover : "transparent"

        Text {
            anchors.centerIn: parent
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
            text: "\u{f0176}" // 󰅶 coffee
            color: ScreensaverStore.inhibited ? Theme.accent : Theme.fgDim
        }

        MouseArea {
            id: ssMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (popup.visible) {
                    popup.visible = false;
                    return;
                }
                const p = ss.mapToItem(null, 0, 0);
                popup.anchor.rect.x = Math.max(8, p.x + ss.width - popup.implicitWidth);
                popup.anchor.rect.y = Theme.barHeight;
                PopupGuard.claim(popup);
                popup.visible = true;
            }
        }
    }

    PopupWindow {
        id: popup

        anchor.window: ss.bar
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

                Item {
                    width: parent.width
                    height: 20

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Screen"
                        color: Theme.fg
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: ScreensaverStore.inhibited ? "staying awake" : "will blank when idle"
                        color: Theme.fgDim
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 8
                    color: "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Keep screen awake"
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
                        color: ScreensaverStore.keepAwake ? Theme.accent : "#4a4a50"

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: ScreensaverStore.keepAwake ? parent.width - width - 2 : 2
                            Behavior on x { NumberAnimation { duration: 120 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: ScreensaverStore.setKeepAwake(!ScreensaverStore.keepAwake)
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#2effffff"
                }

                Repeater {
                    model: ScreensaverStore.blockers

                    delegate: Item {
                        required property var modelData

                        width: popupCol.width
                        height: 30

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: Theme.iconFont
                            font.pixelSize: 14
                            text: ss.sourceGlyph(modelData.source)
                            color: Theme.accent
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 32
                            anchors.right: blockerDetail.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: Theme.fg
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                        }

                        Text {
                            id: blockerDetail
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            // never squeeze the label out entirely
                            width: Math.min(implicitWidth, parent.width * 0.45)
                            horizontalAlignment: Text.AlignRight
                            text: modelData.detail
                            color: Theme.fgDim
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    visible: ScreensaverStore.blockers.length === 0
                    text: "Nothing is keeping the screen awake"
                    color: Theme.fgDim
                    font.pixelSize: 12
                }
            }
        }
    }
}
