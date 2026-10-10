// SPDX-FileCopyrightText: 2026 dschaefer79 <dschaefer79@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    Plasmoid.icon: "view-grid"
    // Always visible in the system tray, not tucked into its overflow.
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    toolTipMainText: i18n("Window Tiling")
    toolTipSubText: disabled ? i18n("Tiling is disabled")
        : snapHint ? i18n("Tile windows into columns or rows.\n%1", snapHint)
                   : i18n("Tile windows into columns or rows")

    // With both off the KWin script tiles into columns.
    readonly property bool rows: Plasmoid.configuration.horizontal
    readonly property bool columns: Plasmoid.configuration.vertical || !rows
    readonly property bool disabled: Plasmoid.configuration.disabled

    // How dropping a window works with the current settings.
    readonly property string snapHint: {
        const c = Plasmoid.configuration;
        if (c.disabled || !c.snap)
            return "";
        const swapped = columns && rows ? i18n("with columns and rows swapped")
                      : columns ? i18n("into rows") : i18n("into columns");
        if (c.snapShiftOnly && c.snapShiftSwap)
            return i18n("Hold Shift while dropping a window to snap it %1.", swapped);
        if (c.snapShiftOnly)
            return i18n("Hold Shift while dropping a window to snap it.");
        if (c.snapShiftSwap)
            return i18n("Drop a window to snap it; hold Shift to snap it %1.", swapped);
        return i18n("Drop a window to snap it into place.");
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => disconnectSource(source)
    }

    function run(args) {
        // Arguments are fixed strings or numbers from the settings.
        executable.connectSource("plasma-tile-menu " + args.join(" "));
    }

    // KWin runs the tiling; keep its copy of the settings in step.
    function syncSettings() {
        const c = Plasmoid.configuration;
        run(["sync-config",
             "vertical=" + c.vertical, "horizontal=" + c.horizontal,
             "wideMinWidth=" + c.wideMinWidth, "wideColumns=" + c.wideColumns,
             "normalColumns=" + c.normalColumns,
             "tallMinHeight=" + c.tallMinHeight, "tallRows=" + c.tallRows,
             "normalRows=" + c.normalRows,
             "gap=" + c.gap, "gapUnit=" + (c.gapUnitIndex === 1 ? "mm" : "px"), "gapMm=" + c.gapMm,
             "snap=" + c.snap,
             "snapShiftOnly=" + c.snapShiftOnly, "snapShiftSwap=" + c.snapShiftSwap,
             "resizeNeighbours=" + c.resizeNeighbours,
             "disabled=" + c.disabled, "tileNew=" + c.tileNew]);
        // A copy for "Save settings to file…".
        run(["store-config", "tiling"].concat(storedKeys.map(k => k + "=" + c[k])));
    }

    readonly property var storedKeys: ["disabled", "tileNew", "showAuto", "vertical",
        "horizontal", "wideMinWidth", "wideColumns", "normalColumns", "tallMinHeight",
        "tallRows", "normalRows", "gap", "gapUnitIndex", "gapMm", "snap", "snapShiftOnly",
        "snapShiftSwap", "resizeNeighbours"]

    // Settings loaded from a file (plasma-tile-menu import) for this widget,
    // as KEY=VALUE lines: take over the known keys with the right type.
    function applyImport(text) {
        const c = Plasmoid.configuration;
        String(text).trim().split("\n").forEach(line => {
            const i = line.indexOf("=");
            const key = line.slice(0, i), value = line.slice(i + 1);
            if (i <= 0 || root.storedKeys.indexOf(key) < 0)
                return;
            if (typeof c[key] === "boolean") {
                if (value === "true" || value === "false")
                    c[key] = value === "true";
            } else if (typeof c[key] === "number") {
                if (value !== "" && !isNaN(Number(value)))
                    c[key] = Number(value);
            } else {
                c[key] = value.split(",").filter(r => /^[1-9][0-9]{2,4}x[1-9][0-9]{2,4}$/.test(r));
            }
        });
    }
    P5Support.DataSource {
        id: importReader
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            const text = String(data["stdout"]).trim();
            // "configure" first: its entry in System Settings asks for
            // the settings.
            if (text.split("\n")[0] === "configure")
                Plasmoid.internalAction("configure").trigger();
            if (text !== "")
                root.applyImport(text);
        }
    }

    Connections {
        target: Plasmoid.configuration
        function onValueChanged(key, value) {
            root.changedAt = Date.now();
            syncTimer.restart();
        }
    }

    // The switches can also be flipped with keyboard shortcuts, which change
    // the KWin script's settings: take those over. Not right after a change
    // here, which KWin may not have yet.
    property double changedAt: 0
    P5Support.DataSource {
        id: toggleReader
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            if (syncTimer.running || Date.now() - root.changedAt < 3000)
                return;
            const c = Plasmoid.configuration;
            String(data["stdout"]).trim().split("\n").forEach(line => {
                const [key, value] = line.split("=");
                if (["snap", "tileNew", "disabled"].indexOf(key) >= 0
                        && (value === "true" || value === "false")
                        && c[key] !== (value === "true"))
                    c[key] = value === "true";
            });
        }
    }
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            toggleReader.connectSource("plasma-tile-menu get-toggles");
            importReader.connectSource("plasma-tile-menu take-import tiling");
        }
    }

    // Several keys change at once when settings are applied.
    Timer {
        id: syncTimer
        interval: 300
        onTriggered: root.syncSettings()
    }

    Component.onCompleted: {
        syncSettings();
        readShortcuts();
    }

    // Keys of the menu entries, by tile action: {"4": "Meta+Alt+4", ...}.
    // Read again each time the menu opens, as they can change in System
    // Settings.
    property var shortcutKeys: ({})
    readonly property var shortcutActions: ({
        "TileAuto": "auto", "Tile4Columns": "4", "Tile3Columns": "3", "Tile2Columns": "2",
        "Tile3Rows": "rows-3", "Tile2Rows": "rows-2", "TileGrid2x2": "grid-2x2",
        "TileGrid3x2": "grid-3x2", "TileGrid4x2": "grid-4x2", "Restore": "restore",
    })
    P5Support.DataSource {
        id: shortcutReader
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            const keys = {};
            String(data["stdout"]).trim().split("\n").forEach(line => {
                const i = line.indexOf("=");
                const action = root.shortcutActions[line.slice(0, i)];
                if (i > 0 && action)
                    keys[action] = line.slice(i + 1);
            });
            root.shortcutKeys = keys;
        }
    }
    function readShortcuts() {
        shortcutReader.connectSource("plasma-tile-menu get-shortcuts");
    }

    // A click opens a compact menu next to the icon instead of a popup:
    // the system tray would show the popup at its own large size. The
    // popup is never shown, it only receives the click.
    fullRepresentation: Item {}
    // Collapse once the tray has finished handling the click; doing it
    // right away makes the tray expand the widget again, endlessly.
    onExpandedChanged: {
        if (root.expanded)
            Qt.callLater(collapseToMenu);
    }
    function collapseToMenu() {
        root.expanded = false;
        toggleMenu();
    }

    // Clicking the icon while the menu is open first closes it (the menu
    // loses focus); do not open it again right away.
    property double menuClosedAt: 0

    function toggleMenu() {
        if (menu.visible) {
            menu.visible = false;
            return;
        }
        if (Date.now() - menuClosedAt < 300)
            return;
        readShortcuts();
        menu.visible = true;
        menu.requestActivate();
    }

    function act(args) {
        menu.visible = false;
        run(args);
    }

    // Our own popup instead of a standard menu: its rows can be closer
    // together than the style's menu entries.
    PlasmaCore.PopupPlasmaWindow {
        id: menu
        visualParent: root
        popupDirection: {
            switch (Plasmoid.location) {
            case PlasmaCore.Types.TopEdge: return Qt.BottomEdge;
            case PlasmaCore.Types.LeftEdge: return Qt.RightEdge;
            case PlasmaCore.Types.RightEdge: return Qt.LeftEdge;
            default: return Qt.TopEdge;
            }
        }
        hideOnWindowDeactivate: true
        // Only as large as the entries; otherwise the window takes a large
        // default size.
        width: entries.implicitWidth + leftPadding + rightPadding
        height: entries.implicitHeight + topPadding + bottomPadding
        onVisibleChanged: {
            if (!visible)
                root.menuClosedAt = Date.now();
        }

        mainItem: Item {
            implicitWidth: entries.implicitWidth
            implicitHeight: entries.implicitHeight
            focus: true
            Keys.onEscapePressed: menu.visible = false

            ColumnLayout {
                    id: entries
                // Kept at the top so the entries never spread out.
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 0

                MenuRow {
                    visible: Plasmoid.configuration.showAuto
                    enabled: !root.disabled
                    text: i18n("Tile automatically")
                    iconName: "view-app-grid-symbolic"
                    shortcut: root.shortcutKeys["auto"] || ""
                    onActivated: root.act(["tile", "auto"])
                }
                MenuRow {
                    visible: root.columns
                    enabled: !root.disabled
                    text: i18n("Tile in 4 columns")
                    iconName: "tilemenu-columns-4-symbolic"
                    shortcut: root.shortcutKeys["4"] || ""
                    onActivated: root.act(["tile", "4"])
                }
                MenuRow {
                    visible: root.columns
                    enabled: !root.disabled
                    text: i18n("Tile in 3 columns")
                    iconName: "tilemenu-columns-3-symbolic"
                    shortcut: root.shortcutKeys["3"] || ""
                    onActivated: root.act(["tile", "3"])
                }
                MenuRow {
                    visible: root.columns
                    enabled: !root.disabled
                    text: i18n("Tile in 2 columns")
                    iconName: "tilemenu-columns-2-symbolic"
                    shortcut: root.shortcutKeys["2"] || ""
                    onActivated: root.act(["tile", "2"])
                }
                MenuRow {
                    visible: root.rows
                    enabled: !root.disabled
                    text: i18n("Tile in 3 rows")
                    iconName: "tilemenu-rows-3-symbolic"
                    shortcut: root.shortcutKeys["rows-3"] || ""
                    onActivated: root.act(["tile", "rows-3"])
                }
                MenuRow {
                    visible: root.rows
                    enabled: !root.disabled
                    text: i18n("Tile in 2 rows")
                    iconName: "tilemenu-rows-2-symbolic"
                    shortcut: root.shortcutKeys["rows-2"] || ""
                    onActivated: root.act(["tile", "rows-2"])
                }
                MenuRow {
                    enabled: !root.disabled
                    text: i18n("Tile in 2 × 2 grid")
                    iconName: "tilemenu-grid-2x2-symbolic"
                    shortcut: root.shortcutKeys["grid-2x2"] || ""
                    onActivated: root.act(["tile", "grid-2x2"])
                }
                MenuRow {
                    enabled: !root.disabled
                    text: i18n("Tile in 3 × 2 grid")
                    iconName: "tilemenu-grid-3x2-symbolic"
                    shortcut: root.shortcutKeys["grid-3x2"] || ""
                    onActivated: root.act(["tile", "grid-3x2"])
                }
                MenuRow {
                    enabled: !root.disabled
                    text: i18n("Tile in 4 × 2 grid")
                    iconName: "tilemenu-grid-4x2-symbolic"
                    shortcut: root.shortcutKeys["grid-4x2"] || ""
                    onActivated: root.act(["tile", "grid-4x2"])
                }
                Kirigami.Separator {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                }
                MenuRow {
                    text: i18n("Restore windows")
                    iconName: "view-restore-symbolic"
                    shortcut: root.shortcutKeys["restore"] || ""
                    onActivated: root.act(["tile", "restore"])
                }
                Kirigami.Separator {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                }
                // Snap windows into place when they are dropped.
                MenuRow {
                    text: i18n("Automatic tiling")
                    checkable: true
                    checked: Plasmoid.configuration.snap
                    enabled: !root.disabled
                    onActivated: Plasmoid.configuration.snap = !Plasmoid.configuration.snap
                }
                // Tile each window that opens together with the others.
                MenuRow {
                    text: i18n("Tile new windows")
                    checkable: true
                    checked: Plasmoid.configuration.tileNew
                    enabled: !root.disabled
                    onActivated: Plasmoid.configuration.tileNew = !Plasmoid.configuration.tileNew
                }
                MenuRow {
                    text: i18n("Disable tiling")
                    checkable: true
                    checked: root.disabled
                    onActivated: Plasmoid.configuration.disabled = !root.disabled
                }
                Kirigami.Separator {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                }
                PlasmaComponents3.Label {
                    visible: root.snapHint !== ""
                    Layout.fillWidth: true
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    wrapMode: Text.WordWrap
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    text: root.snapHint
                }
                MenuRow {
                    text: i18n("Keyboard shortcuts…")
                    iconName: "preferences-desktop-keyboard-shortcut"
                    onActivated: root.act(["shortcuts"])
                }
                MenuRow {
                    text: i18n("Settings…")
                    iconName: "configure"
                    onActivated: {
                        menu.visible = false;
                        Plasmoid.internalAction("configure").trigger();
                    }
                }
                // Take the widget off the tray or panel; tiling and its
                // shortcuts keep working. "plasma-tile-menu setup" puts it back.
                MenuRow {
                    text: i18n("Quit")
                    iconName: "application-exit"
                    onActivated: root.act(["quit"])
                }
            }
        }
    }
}
