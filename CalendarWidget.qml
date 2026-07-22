import Quickshell
import QtQuick

// Clock in the bar; clicking it opens a month calendar popup.
Item {
    id: cal

    required property var bar

    implicitWidth: clockBg.width
    height: 22

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        id: clockBg
        width: clockText.implicitWidth + 14
        height: parent.height
        radius: 6
        color: clockMouse.containsMouse ? Theme.hover : "transparent"

        Text {
            id: clockText
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, "ddd MMM d  h:mm AP")
            color: Theme.fg
            font.pixelSize: Theme.fontSize
        }

        MouseArea {
            id: clockMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (popup.visible) {
                    popup.visible = false;
                    return;
                }
                popup.viewYear = clock.date.getFullYear();
                popup.viewMonth = clock.date.getMonth();
                const p = cal.mapToItem(null, 0, 0);
                popup.anchor.rect.x = Math.max(8, p.x + cal.width - popup.implicitWidth);
                popup.anchor.rect.y = Theme.barHeight;
                PopupGuard.claim(popup);
                popup.visible = true;
            }
        }
    }

    PopupWindow {
        id: popup

        property int viewYear: 2026
        property int viewMonth: 0 // 0-based

        readonly property int firstDow: Qt.locale().firstDayOfWeek % 7
        readonly property var gridStart: {
            const first = new Date(viewYear, viewMonth, 1);
            const off = (first.getDay() - firstDow + 7) % 7;
            return new Date(viewYear, viewMonth, 1 - off);
        }

        function shiftMonth(d) {
            let m = viewMonth + d;
            let y = viewYear;
            if (m < 0) { m = 11; y--; }
            if (m > 11) { m = 0; y++; }
            viewMonth = m;
            viewYear = y;
        }

        anchor.window: cal.bar
        implicitWidth: 300
        implicitHeight: calCol.implicitHeight + 28
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

            Column {
                id: calCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 14
                spacing: 8

                // header: month name + nav
                Item {
                    width: parent.width
                    height: 24

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDate(new Date(popup.viewYear, popup.viewMonth, 1), "MMMM yyyy")
                        color: Theme.fg
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Repeater {
                            model: [
                                { label: "‹", act: () => popup.shiftMonth(-1) },
                                { label: "•", act: () => {
                                    popup.viewYear = clock.date.getFullYear();
                                    popup.viewMonth = clock.date.getMonth();
                                } },
                                { label: "›", act: () => popup.shiftMonth(1) }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                width: 24
                                height: 22
                                radius: 6
                                color: navMouse.containsMouse ? Theme.hover : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData.label
                                    color: Theme.fg
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    id: navMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: parent.modelData.act()
                                }
                            }
                        }
                    }
                }

                // day-of-week header
                Grid {
                    columns: 7
                    width: parent.width

                    Repeater {
                        model: 7

                        delegate: Item {
                            required property int index
                            width: calCol.width / 7
                            height: 18

                            Text {
                                anchors.centerIn: parent
                                text: Qt.locale().dayName((popup.firstDow + index) % 7, Locale.ShortFormat)
                                color: Theme.fgDim
                                font.pixelSize: 10
                            }
                        }
                    }
                }

                // day grid
                Grid {
                    columns: 7
                    width: parent.width

                    Repeater {
                        model: 42

                        delegate: Item {
                            id: dayCell

                            required property int index
                            readonly property date cellDate: new Date(
                                popup.gridStart.getFullYear(),
                                popup.gridStart.getMonth(),
                                popup.gridStart.getDate() + index)
                            readonly property bool inMonth: cellDate.getMonth() === popup.viewMonth
                            readonly property bool isToday:
                                cellDate.getFullYear() === clock.date.getFullYear()
                                && cellDate.getMonth() === clock.date.getMonth()
                                && cellDate.getDate() === clock.date.getDate()

                            width: calCol.width / 7
                            height: 30

                            Rectangle {
                                anchors.centerIn: parent
                                width: 26
                                height: 26
                                radius: 13
                                color: dayCell.isToday ? Theme.accent : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: dayCell.cellDate.getDate()
                                    color: dayCell.isToday ? "#ffffff"
                                         : dayCell.inMonth ? Theme.fg : "#55ffffff"
                                    font.pixelSize: 12
                                    font.bold: dayCell.isToday
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
