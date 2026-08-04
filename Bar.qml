import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: bar

    required property var modelData
    readonly property var mon: DwmState.monitorFor(bar.screen)

    screen: modelData
    aboveWindows: true
    color: Theme.barBg

    readonly property int maxSubIcons: 3
    readonly property int dragThreshold: 4

    // Drag state lives on the bar: the ghost paints above every pill and the
    // drop target is a sibling of the pill the gesture started on.
    // The payload is a snapshot, not a reference into DwmState.monitors --
    // dwm rewrites its state file on every redraw and hands out a brand-new
    // clients array each time.
    property bool dragActive: false
    property int dragSourceIndex: -1
    property int dragTargetIndex: -1
    property var dragWins: []          // window ids to retag
    property var dragClient: null      // { win: 0, "class": ... } for the ghost
    property int dragCount: 0
    property real dragSceneX: 0

    readonly property bool dragDroppable: bar.dragTargetIndex >= 0
                                       && bar.dragTargetIndex !== bar.dragSourceIndex

    // dwm rewrites its state file on every bar redraw; latching the clients
    // array instead of binding to it holds the pills still for the length of
    // a drag, so the drop target cannot shift under a stationary cursor.
    property var monClients: []

    onMonChanged: bar.syncClients()
    Component.onCompleted: bar.syncClients()

    function syncClients() {
        if (!bar.dragActive)
            bar.monClients = bar.mon && bar.mon.clients ? bar.mon.clients : [];
    }

    function beginDrag(sourceIndex, clients, ghostClient) {
        const wins = [];
        for (let i = 0; i < clients.length; i++)
            wins.push(clients[i].win);
        bar.dragWins = wins;
        bar.dragCount = wins.length;
        bar.dragClient = { win: 0, "class": ghostClient ? ghostClient["class"] : "" };
        bar.dragSourceIndex = sourceIndex;
        bar.dragTargetIndex = sourceIndex;
        bar.dragActive = true;
    }

    function updateDrag(sceneX, sceneY) {
        bar.dragSceneX = sceneX;
        bar.dragTargetIndex = bar.tagIndexAt(sceneX, sceneY);
    }

    function endDrag() {
        if (bar.dragDroppable)
            DwmState.moveToTag(bar.dragWins, bar.dragTargetIndex);
        bar.cancelDrag();
    }

    function cancelDrag() {
        bar.dragActive = false;
        bar.dragSourceIndex = -1;
        bar.dragTargetIndex = -1;
        bar.dragWins = [];
        bar.dragClient = null;
        bar.dragCount = 0;
        bar.syncClients();
    }

    // The pill under a scene point, or -1. Pills sit 2px apart; each claims
    // half the gap, so a drop between two pills is not a cancel.
    function tagIndexAt(sceneX, sceneY) {
        if (sceneY < 0 || sceneY > bar.height)
            return -1;
        const p = leftRow.mapFromItem(null, sceneX, sceneY);
        const pad = leftRow.spacing / 2;
        for (let i = 0; i < leftRow.children.length; i++) {
            const c = leftRow.children[i];
            if (c.objectName !== "tagPill")
                continue;
            if (p.x >= c.x - pad && p.x <= c.x + c.width + pad)
                return c.tagIndex;
        }
        return -1;
    }

    // One app icon: the real icon when the WM_CLASS resolves, otherwise a
    // monogram chip so two unresolved apps stay distinguishable. Pure visual:
    // the pill's single MouseArea owns all input, so a dwm state rewrite that
    // rebuilds these delegates can never kill an in-flight mouse grab.
    component AppIcon: Item {
        id: appIcon

        required property var client
        required property int size

        readonly property string wmClass: client ? client.class : ""
        readonly property string iconPath: AppIcons.iconFor(appIcon.wmClass)

        implicitWidth: size
        implicitHeight: size

        IconImage {
            anchors.fill: parent
            visible: appIcon.iconPath !== ""
            source: appIcon.iconPath
        }

        Rectangle {
            anchors.fill: parent
            visible: appIcon.iconPath === ""
            radius: Math.max(2, Math.round(appIcon.size / 6))
            color: Theme.hover
            border.width: 1
            border.color: Theme.fgDim

            Text {
                anchors.centerIn: parent
                text: AppIcons.monogramFor(appIcon.wmClass)
                color: Theme.fg
                font.pixelSize: Math.round(appIcon.size * 0.62)
                font.bold: true
            }
        }
    }

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight

    function nextLayoutKey() {
        const l = bar.mon ? bar.mon.layout : "[]=";
        if (l === "[]=")
            return "super+f";
        if (l === "><>")
            return "super+m";
        return "super+t";
    }

    // ---- left: tags, layout, focused window title ----
    Row {
        id: leftRow
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        // A tag pill shows the apps living on that tag: dwm's master at full
        // size, then smaller icons for the rest, capped with a "+N". Empty tags
        // keep their number, so all nine positions stay countable.
        Repeater {
            model: 9

            delegate: Item {
                id: tagPill
                required property int index

                objectName: "tagPill"
                readonly property int tagIndex: tagPill.index

                readonly property var tagClients: {
                    const all = bar.monClients;
                    const mask = 1 << tagPill.index;
                    const out = [];
                    for (let i = 0; i < all.length; i++)
                        if ((all[i].tags & mask) !== 0)
                            out.push(all[i]);
                    return out;
                }

                // dwm's master is the first non-floating client in m->clients
                // order — what tile() would put in the big pane. A tag holding
                // only floating windows falls back to its first client, so the
                // pill never regresses to a bare digit while windows are open.
                readonly property var ordered: {
                    const cs = tagPill.tagClients;
                    if (cs.length === 0)
                        return [];
                    let master = 0;
                    for (let i = 0; i < cs.length; i++) {
                        if (!cs[i].floating) {
                            master = i;
                            break;
                        }
                    }
                    const out = [cs[master]];
                    for (let i = 0; i < cs.length; i++)
                        if (i !== master)
                            out.push(cs[i]);
                    return out;
                }

                readonly property var shownIcons: tagPill.ordered.slice(0, bar.maxSubIcons + 1)
                readonly property int overflow: tagPill.ordered.length - tagPill.shownIcons.length
                readonly property bool occupied: tagPill.ordered.length > 0
                readonly property bool tagSelected: bar.mon ? (bar.mon.tags & (1 << tagPill.index)) !== 0 : tagPill.index === 0
                readonly property bool tagUrgent: bar.mon ? (bar.mon.urg & (1 << tagPill.index)) !== 0 : false

                width: Math.max(24, pillRow.implicitWidth + 12)
                height: 22

                Behavior on width {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: bar.dragActive && bar.dragTargetIndex === tagPill.index && bar.dragDroppable
                             ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
                         : tagPill.tagUrgent
                             ? Qt.rgba(Theme.urgent.r, Theme.urgent.g, Theme.urgent.b, 0.22)
                         : (bar.dragActive ? bar.dragSourceIndex === tagPill.index : tagMouse.containsMouse)
                             ? Theme.hover
                         : "transparent"
                    border.width: bar.dragActive && bar.dragTargetIndex === tagPill.index && bar.dragDroppable ? 1 : 0
                    border.color: Theme.accent
                }

                // selected/urgent marker, in the gap between pill and bar edge
                Rectangle {
                    visible: tagPill.tagSelected || tagPill.tagUrgent
                    width: Math.max(12, parent.width - 8)
                    height: 2
                    radius: 1
                    color: tagPill.tagUrgent ? Theme.urgent : Theme.accent
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -3
                }

                Text {
                    visible: !tagPill.occupied
                    anchors.centerIn: parent
                    text: tagPill.index + 1
                    color: tagPill.tagSelected ? Theme.fg : Theme.fgDim
                    font.pixelSize: Theme.fontSize
                }

                Row {
                    id: pillRow
                    visible: tagPill.occupied
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: tagPill.shownIcons

                        delegate: AppIcon {
                            required property int index
                            required property var modelData

                            anchors.verticalCenter: parent.verticalCenter
                            client: modelData
                            size: index === 0 ? 18 : 11
                            opacity: bar.dragActive && bar.dragWins.indexOf(modelData.win) >= 0 ? 0.35 : 1
                        }
                    }

                    Text {
                        visible: tagPill.overflow > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+" + tagPill.overflow
                        color: Theme.fgDim
                        font.pixelSize: 9
                    }
                }

                // The pill's only input surface: the icons are pure visuals, so
                // one grab covers a click on an icon, a click on the pill, and
                // either drag. Because it belongs to the fixed nine-pill model,
                // a dwm state rewrite can never destroy it mid-gesture.
                MouseArea {
                    id: tagMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    // the drag flag outlives the drop by design (see onClicked),
                    // so the cursor follows the bar instead: every pill wears
                    // the closed hand while a drag is in flight, none after it
                    cursorShape: bar.dragActive ? Qt.ClosedHandCursor : Qt.ArrowCursor

                    // the client under the press, null when the press landed on
                    // the pill itself (background, tag number or the "+N")
                    property var pressedClient: null
                    property real pressSceneX: 0
                    property bool dragging: false

                    function clientAt(x, y) {
                        if (!tagPill.occupied)
                            return null;
                        const p = pillRow.mapFromItem(tagMouse, x, y);
                        const item = pillRow.childAt(p.x, p.y);
                        return item && item.client ? item.client : null;
                    }

                    // Only the button that opened a gesture drives it: a
                    // second button pressed mid-drag (a right-click while the
                    // left one is held) must not reset the state machine under
                    // the live grab, or the drag would restart as a whole-stack
                    // one and the release stop matching the press.
                    onPressed: mouse => {
                        if (mouse.buttons !== mouse.button)
                            return;
                        tagMouse.dragging = false;
                        tagMouse.pressedClient = mouse.button === Qt.LeftButton
                            ? tagMouse.clientAt(mouse.x, mouse.y) : null;
                        tagMouse.pressSceneX = tagMouse.mapToItem(null, mouse.x, mouse.y).x;
                    }

                    onPositionChanged: mouse => {
                        if (!(mouse.buttons & Qt.LeftButton))
                            return;
                        const p = tagMouse.mapToItem(null, mouse.x, mouse.y);
                        if (!tagMouse.dragging) {
                            if (Math.abs(p.x - tagMouse.pressSceneX) < bar.dragThreshold)
                                return;
                            if (!tagMouse.pressedClient && !tagPill.occupied)
                                return;
                            tagMouse.dragging = true;
                            if (tagMouse.pressedClient)
                                bar.beginDrag(tagPill.tagIndex, [tagMouse.pressedClient], tagMouse.pressedClient);
                            else
                                bar.beginDrag(tagPill.tagIndex, tagPill.ordered, tagPill.ordered[0]);
                        }
                        bar.updateDrag(p.x, p.y);
                    }

                    onReleased: mouse => {
                        if (tagMouse.dragging && mouse.button === Qt.LeftButton)
                            bar.endDrag();
                    }

                    // the grab can be taken away (window deactivation); the
                    // ghost must not outlive it
                    onCanceled: {
                        if (tagMouse.dragging)
                            bar.cancelDrag();
                        tagMouse.dragging = false;
                    }

                    // released is emitted before clicked, so `dragging` is
                    // cleared on the next press, never here
                    onClicked: mouse => {
                        if (tagMouse.dragging)
                            return;
                        // the release of a second button, with the one that
                        // opened the gesture still held: not a click either
                        if (mouse.buttons !== Qt.NoButton)
                            return;
                        if (tagMouse.pressedClient) {
                            DwmState.activate(tagMouse.pressedClient.win);
                            return;
                        }
                        const combo = (mouse.button === Qt.RightButton ? "super+ctrl+" : "super+") + (tagPill.index + 1);
                        if (bar.mon)
                            DwmState.keyOnMonitor(bar.mon.num, combo);
                        else
                            DwmState.key(combo);
                    }
                }
            }
        }

        Item { width: 8; height: 1 }

        Rectangle {
            width: layoutText.implicitWidth + 12
            height: 22
            radius: 6
            color: layoutMouse.containsMouse ? Theme.hover : "transparent"

            Text {
                id: layoutText
                anchors.centerIn: parent
                text: bar.mon ? bar.mon.layout : "[]="
                color: Theme.fgDim
                font.pixelSize: Theme.fontSize
            }

            MouseArea {
                id: layoutMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (bar.mon)
                        DwmState.keyOnMonitor(bar.mon.num, bar.nextLayoutKey());
                    else
                        DwmState.key(bar.nextLayoutKey());
                }
            }
        }

        Item { width: 10; height: 1 }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            // truncate before reaching the centered tip text
            width: Math.max(0, Math.min(implicitWidth, tipsWidget.x - (leftRow.x + x) - 16))
            text: bar.mon ? bar.mon.title : ""
            color: bar.mon && bar.mon.selected ? Theme.fg : Theme.fgDim
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }
    }

    Tips {
        id: tipsWidget
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        maxWidth: bar.width * 0.30
    }

    // ---- right: tray, network, bluetooth, clock ----
    Row {
        id: rightRow
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: SystemTray.items

            delegate: Rectangle {
                required property var modelData

                width: 26
                height: 22
                radius: 6
                color: trayMouse.containsMouse ? Theme.hover : "transparent"

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 18
                    source: modelData.icon
                }

                function openMenu() {
                    const p = mapToItem(null, 0, 0);
                    trayMenu.openFor(modelData, p.x);
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            if (modelData.onlyMenu && modelData.hasMenu)
                                parent.openMenu();
                            else
                                modelData.activate();
                        } else if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate();
                        } else if (modelData.hasMenu) {
                            parent.openMenu();
                        }
                    }
                }
            }
        }

        Item { width: 4; height: 1 }

        NetworkWidget { bar: bar }
        SoundWidget { bar: bar }
        BluetoothWidget { bar: bar }
        WallpaperWidget { bar: bar }
        ScreensaverWidget { bar: bar }

        Item { width: 4; height: 1 }

        NotificationCenter {
            anchors.verticalCenter: parent.verticalCenter
            bar: bar
        }

        CalendarWidget {
            anchors.verticalCenter: parent.verticalCenter
            bar: bar
        }
    }

    TrayMenu {
        id: trayMenu
        bar: bar
    }

    // Drag ghost. The bar is 30px tall and every drop target sits in one
    // horizontal row, so the ghost tracks the cursor on x only and stays
    // vertically centred -- following y would only clip it against the panel.
    Item {
        id: dragGhost

        visible: bar.dragActive
        z: 10
        width: 22
        height: 22
        x: bar.dragSceneX - width / 2
        y: (bar.height - height) / 2
        opacity: bar.dragDroppable ? 0.95 : 0.4

        // a stack drag rides on a card so it reads as more than one window
        Rectangle {
            visible: bar.dragCount > 1
            anchors.fill: parent
            radius: 5
            color: Theme.barBg
            border.width: 1
            border.color: Theme.popupBorder
        }

        AppIcon {
            anchors.centerIn: parent
            client: bar.dragClient
            size: 18
        }

        Rectangle {
            visible: bar.dragCount > 1
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: -2
            width: ghostCount.implicitWidth + 6
            height: 12
            radius: 6
            color: Theme.accent

            Text {
                id: ghostCount
                anchors.centerIn: parent
                text: bar.dragCount
                color: Theme.fg
                font.pixelSize: 9
                font.bold: true
            }
        }
    }
}
