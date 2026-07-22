import QtQuick

// Rotating loading-screen-style tips, centered in the bar.
// Every tip reflects a real binding or feature of this config.
Item {
    id: tips

    property real maxWidth: 500

    readonly property var list: [
        "Super+Shift+Enter swaps the focused window into the master slot",
        "A dragged window floats — Super+Shift+Space snaps it back into the tiling",
        "Super+J and Super+K walk focus through the stack",
        "Super+Shift+J throws the focused window to the other monitor and follows it",
        "Right-click a tag to view it alongside the current one",
        "Super+0 shows windows from every tag at once",
        "Super+Shift+0 pins the focused window to every tag",
        "Super+H and Super+L resize the master area",
        "Super+I and Super+D add or remove master slots",
        "Super+M shows one maximized window at a time; Super+T returns to tiling",
        "Super+Ctrl+Space flips back to the previous layout",
        "Super+drag moves a window; Super+right-drag resizes it",
        "Super+Tab bounces between the current and previous tag",
        "Super+, and Super+. move focus across monitors",
        "Pin an app in the notification center and its alerts stay until dismissed",
        "Right-click a notification to dismiss it instantly",
        "Click the clock for a calendar; the ☰ opens notification history",
        "Middle-click a tray icon for its secondary action",
        "Super+P opens dmenu as a fallback launcher",
        "Esc closes Spotlight; Enter launches the top result"
    ]

    property int idx: Math.floor(Math.random() * list.length)

    implicitWidth: Math.min(row.implicitWidth, maxWidth)
    implicitHeight: 22

    Timer {
        interval: 30000
        running: Settings.tipsEnabled
        repeat: true
        onTriggered: cycle.restart()
    }

    SequentialAnimation {
        id: cycle

        NumberAnimation {
            target: row
            property: "opacity"
            to: 0
            duration: 300
        }
        ScriptAction {
            script: tips.idx = (tips.idx + 1) % tips.list.length
        }
        NumberAnimation {
            target: row
            property: "opacity"
            to: 1
            duration: 300
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Item {
            id: bulb
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 18

            Text {
                anchors.centerIn: parent
                font.family: Theme.iconFont
                font.pixelSize: 12
                text: "\u{f0335}" // 󰌵 lightbulb
                color: bulbMouse.containsMouse ? Theme.fg : "#66ffffff"
            }

            // slash when tips are disabled
            Rectangle {
                visible: !Settings.tipsEnabled
                anchors.centerIn: parent
                width: 16
                height: 1.4
                radius: 1
                rotation: -45
                color: bulbMouse.containsMouse ? Theme.fg : "#99ffffff"
            }

            MouseArea {
                id: bulbMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Settings.setTipsEnabled(!Settings.tipsEnabled)
            }
        }

        Text {
            visible: Settings.tipsEnabled
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, tips.maxWidth - 20)
            text: tips.list[tips.idx]
            color: Theme.fgDim
            font.pixelSize: 11
            font.italic: true
            elide: Text.ElideRight

            MouseArea {
                anchors.fill: parent
                onClicked: cycle.restart() // click the tip for the next one
            }
        }
    }
}
