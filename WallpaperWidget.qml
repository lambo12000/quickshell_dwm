import Quickshell
import Quickshell.Widgets
import Qt.labs.folderlistmodel
import QtQuick

// Bar widget: opens a wallpaper picker. Thumbnails come from
// ~/Pictures/Wallpapers; the monitor row chooses which output the next
// click applies to. Selections persist and re-apply on login.
Item {
    id: ww

    required property var bar

    width: 26
    height: 22

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: wwMouse.containsMouse ? Theme.hover : "transparent"

        Text {
            anchors.centerIn: parent
            font.family: Theme.iconFont
            font.pixelSize: 15
            text: "\u{f02e9}" // 󰋩 image
            color: Theme.fg
        }

        MouseArea {
            id: wwMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (popup.visible) {
                    popup.visible = false;
                    return;
                }
                const p = ww.mapToItem(null, 0, 0);
                popup.anchor.rect.x = Math.max(8, p.x + ww.width - popup.implicitWidth);
                popup.anchor.rect.y = Theme.barHeight;
                popup.targetScreen = ww.bar.screen.name;
                PopupGuard.claim(popup);
                popup.visible = true;
            }
        }
    }

    PopupWindow {
        id: popup

        // output the next thumbnail click applies to
        property string targetScreen: ""

        anchor.window: ww.bar
        implicitWidth: 380
        implicitHeight: Math.min(560, headerRow.height + monitorRow.height + grid.contentHeight + 52)
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

        FolderListModel {
            id: folder
            folder: "file://" + WallpaperStore.dir
            nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp",
                          "*.JPG", "*.JPEG", "*.PNG"]
            showDirs: false
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
                    text: "Wallpaper"
                    color: Theme.fg
                    font.pixelSize: 14
                    font.bold: true
                }
            }

            Row {
                id: monitorRow
                anchors.top: headerRow.bottom
                anchors.topMargin: 6
                anchors.left: parent.left
                anchors.leftMargin: 12
                height: 24
                spacing: 6

                Repeater {
                    model: Quickshell.screens

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool active: popup.targetScreen === modelData.name

                        width: monText.implicitWidth + 16
                        height: 22
                        radius: 6
                        color: active ? Theme.accent
                             : monMouse.containsMouse ? Theme.hover : "transparent"

                        Text {
                            id: monText
                            anchors.centerIn: parent
                            text: "\u{f0379}  " + modelData.name // 󰍹 monitor
                            font.family: Theme.iconFont
                            font.pixelSize: 11
                            color: parent.active ? "#ffffff" : Theme.fgDim
                        }

                        MouseArea {
                            id: monMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: popup.targetScreen = parent.modelData.name
                        }
                    }
                }
            }

            Text {
                visible: folder.count === 0
                anchors.top: monitorRow.bottom
                anchors.topMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Drop images in ~/Pictures/Wallpapers"
                color: Theme.fgDim
                font.pixelSize: 12
            }

            GridView {
                id: grid
                anchors.top: monitorRow.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                anchors.bottomMargin: 10
                clip: true
                cellWidth: 120
                cellHeight: 78
                model: folder

                delegate: Item {
                    id: cell

                    required property string filePath
                    required property string fileName
                    readonly property bool current:
                        WallpaperStore.wallpaperFor(popup.targetScreen) === filePath

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: thumb
                        anchors.margins: -2
                        radius: 8
                        color: "transparent"
                        border.color: cell.current ? Theme.accent
                                    : thumbMouse.containsMouse ? Theme.popupBorder : "transparent"
                        border.width: 2
                    }

                    ClippingRectangle {
                        id: thumb
                        anchors.centerIn: parent
                        width: 108
                        height: 61
                        radius: 6
                        color: "#111114"

                        Image {
                            anchors.fill: parent
                            source: "file://" + cell.filePath
                            sourceSize.width: 216
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }

                    MouseArea {
                        id: thumbMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: WallpaperStore.setWallpaper(popup.targetScreen, cell.filePath)
                    }
                }
            }
        }
    }
}
