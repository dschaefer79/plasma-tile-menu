// SPDX-FileCopyrightText: 2026 dschaefer79 <dschaefer79@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    Plasmoid.icon: "monitor-symbolic"
    // Always visible in the system tray, not tucked into its overflow.
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    toolTipMainText: i18n("Resolution")
    toolTipSubText: i18n("Switch the screen resolution")

    readonly property var resolutions: Plasmoid.configuration.resolutions
        .filter(r => /^[1-9][0-9]{2,4}x[1-9][0-9]{2,4}$/.test(r))

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => disconnectSource(source)
    }

    // A copy of the settings for "Save settings to file…", kept up to date.
    readonly property var storedKeys: ["resolutions", "addToScreen"]
    function storeSettings() {
        executable.connectSource("plasma-tile-menu store-config resolution resolutions="
            + root.resolutions.join(",") + " addToScreen=" + Plasmoid.configuration.addToScreen);
    }
    Connections {
        target: Plasmoid.configuration
        function onValueChanged(key, value) {
            storeTimer.restart();
        }
    }
    Timer {
        id: storeTimer
        interval: 300
        onTriggered: root.storeSettings()
    }
    Component.onCompleted: storeSettings()

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
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: importReader.connectSource("plasma-tile-menu take-import resolution")
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
        menu.visible = true;
        menu.requestActivate();
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

                Repeater {
                    model: root.resolutions
                    delegate: MenuRow {
                        required property string modelData
                        text: modelData.replace("x", " × ")
                        iconName: "video-display"
                        onActivated: {
                            menu.visible = false;
                            // modelData is checked against the WIDTHxHEIGHT pattern.
                            executable.connectSource("plasma-tile-menu resolution " + modelData);
                        }
                    }
                }
                Kirigami.Separator {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                }
                MenuRow {
                    text: i18n("Settings…")
                    iconName: "configure"
                    onActivated: {
                        menu.visible = false;
                        Plasmoid.internalAction("configure").trigger();
                    }
                }
                // Take the widget off the tray or panel; "Window Tiling Menu"
                // in the applications menu puts it back.
                MenuRow {
                    text: i18n("Quit")
                    iconName: "application-exit"
                    onActivated: {
                        menu.visible = false;
                        executable.connectSource("plasma-tile-menu quit resolution");
                    }
                }
            }
        }
    }
}
