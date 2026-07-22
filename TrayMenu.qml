import Quickshell
import Quickshell.Widgets
import QtQuick

// Custom-rendered DBus menu for tray items (native display() does not
// work on X11). Submenus navigate in place with a Back row.
PopupWindow {
    id: menuWin

    required property var bar
    property var handle: null
    property var backStack: []

    anchor.window: bar
    implicitWidth: 240
    implicitHeight: menuCol.implicitHeight + 16
    visible: false
    color: "transparent"

    function openFor(item, xInWindow) {
        backStack = [];
        handle = item.menu;
        anchor.rect.x = Math.max(8, Math.min(xInWindow, bar.width - implicitWidth - 8));
        anchor.rect.y = Theme.barHeight;
        PopupGuard.claim(menuWin);
        visible = true;
    }

    function fmtLabel(t) {
        // strip dbusmenu mnemonic underscores: "_Quit" -> "Quit"
        return (t || "").replace(/_([^_])/g, "$1");
    }

    QsMenuOpener {
        id: opener
        menu: menuWin.handle
    }

    HoverHandler {
        id: menuHover
    }

    Timer {
        interval: 3000
        running: menuWin.visible && !menuHover.hovered
        onTriggered: menuWin.visible = false
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.popupBg
        border.color: Theme.popupBorder
        border.width: 1

        Column {
            id: menuCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            spacing: 1

            Rectangle {
                visible: menuWin.backStack.length > 0
                width: parent.width
                height: 26
                radius: 6
                color: backMouse.containsMouse ? Theme.hover : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "‹ Back"
                    color: Theme.fgDim
                    font.pixelSize: Theme.fontSize
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        const s = menuWin.backStack.slice();
                        menuWin.handle = s.pop();
                        menuWin.backStack = s;
                    }
                }
            }

            Text {
                visible: !opener.children || opener.children.values.length === 0
                text: "…"
                color: Theme.fgDim
                font.pixelSize: Theme.fontSize
                leftPadding: 8
            }

            Repeater {
                model: opener.children

                delegate: Rectangle {
                    required property var modelData

                    width: menuCol.width
                    height: modelData.isSeparator ? 7 : 26
                    radius: 6
                    color: !modelData.isSeparator && entryMouse.containsMouse && modelData.enabled
                        ? Theme.hover : "transparent"

                    // separator line
                    Rectangle {
                        visible: modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 12
                        height: 1
                        color: "#2effffff"
                    }

                    Row {
                        visible: !modelData.isSeparator
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            visible: modelData.buttonType !== QsMenuButtonType.None
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12
                            text: modelData.checkState === Qt.Checked ? "✓" : ""
                            color: Theme.accent
                            font.pixelSize: 12
                        }

                        IconImage {
                            visible: (modelData.icon || "") !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 15
                            source: modelData.icon || ""
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                                - (modelData.buttonType !== QsMenuButtonType.None ? 18 : 0)
                                - ((modelData.icon || "") !== "" ? 21 : 0)
                                - (modelData.hasChildren ? 16 : 0)
                            text: menuWin.fmtLabel(modelData.text)
                            color: modelData.enabled ? Theme.fg : Theme.fgDim
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: modelData.hasChildren
                            anchors.verticalCenter: parent.verticalCenter
                            text: "›"
                            color: Theme.fgDim
                            font.pixelSize: Theme.fontSize
                        }
                    }

                    MouseArea {
                        id: entryMouse
                        visible: !modelData.isSeparator
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (modelData.hasChildren) {
                                menuWin.backStack = menuWin.backStack.concat([menuWin.handle]);
                                menuWin.handle = modelData;
                            } else if (modelData.enabled) {
                                modelData.triggered();
                                menuWin.visible = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
