import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Volume control + output device picker (pipewire).
// Scroll on the bar icon adjusts volume; click opens the popup.
Item {
    id: snd

    required property var bar

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)

    width: 26
    height: 22

    // keep the default sink and all output devices bound so their
    // properties (volume, mute, names) stay live
    PwObjectTracker {
        objects: snd.sinks
    }

    function setVolume(v) {
        if (sink && sink.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1, v));
        }
    }

    function icon() {
        if (muted || vol === 0)
            return "\u{f0581}"; // 󰖁 volume off
        if (vol > 0.66)
            return "\u{f057e}"; // 󰕾 high
        if (vol > 0.33)
            return "\u{f0580}"; // 󰖀 medium
        return "\u{f057f}";     // 󰕿 low
    }

    function sinkLabel(n) {
        return n.nickname || n.description || n.name;
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: sndMouse.containsMouse ? Theme.hover : "transparent"

        Text {
            anchors.centerIn: parent
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
            color: snd.muted ? Theme.fgDim : Theme.fg
            text: snd.icon()
        }

        MouseArea {
            id: sndMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (popup.visible) {
                    popup.visible = false;
                    return;
                }
                const p = snd.mapToItem(null, 0, 0);
                popup.anchor.rect.x = Math.max(8, p.x + snd.width - popup.implicitWidth);
                popup.anchor.rect.y = Theme.barHeight;
                PopupGuard.claim(popup);
                popup.visible = true;
            }
            onWheel: wheel => snd.setVolume(snd.vol + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
        }
    }

    PopupWindow {
        id: popup

        anchor.window: snd.bar
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
                spacing: 8

                Item {
                    width: parent.width
                    height: 20

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Sound"
                        color: Theme.fg
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(snd.vol * 100) + "%"
                        color: Theme.fgDim
                        font.pixelSize: 12
                    }
                }

                // mute button + volume slider
                Row {
                    width: parent.width
                    height: 24
                    spacing: 10

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 6
                        anchors.verticalCenter: parent.verticalCenter
                        color: muteMouse.containsMouse ? Theme.hover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            font.family: Theme.iconFont
                            font.pixelSize: 15
                            text: snd.icon()
                            color: snd.muted ? Theme.fgDim : Theme.fg
                        }

                        MouseArea {
                            id: muteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (snd.sink && snd.sink.audio)
                                    snd.sink.audio.muted = !snd.sink.audio.muted;
                            }
                        }
                    }

                    Item {
                        width: parent.width - 34
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            id: track
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
                            color: "#3dffffff"

                            Rectangle {
                                width: parent.width * snd.vol
                                height: parent.height
                                radius: 2
                                color: snd.muted ? Theme.fgDim : Theme.accent
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, track.width * snd.vol - width / 2))
                            width: 14
                            height: 14
                            radius: 7
                            color: "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: mouse => snd.setVolume(mouse.x / width)
                            onPositionChanged: mouse => {
                                if (pressed)
                                    snd.setVolume(mouse.x / width);
                            }
                            onWheel: wheel => snd.setVolume(snd.vol + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#2effffff"
                }

                Text {
                    text: "Output"
                    color: Theme.fgDim
                    font.pixelSize: 11
                }

                Repeater {
                    model: snd.sinks

                    delegate: Rectangle {
                        required property var modelData

                        readonly property bool current: Pipewire.defaultAudioSink === modelData

                        width: popupCol.width
                        height: 30
                        radius: 8
                        color: outMouse.containsMouse ? Theme.hover : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 30
                            anchors.verticalCenter: parent.verticalCenter
                            text: snd.sinkLabel(modelData)
                            color: current ? Theme.accent : Theme.fg
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: current
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                            text: "\u{f012c}" // 󰄬 check
                            color: Theme.accent
                        }

                        MouseArea {
                            id: outMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Pipewire.preferredDefaultAudioSink = modelData
                        }
                    }
                }
            }
        }
    }
}
