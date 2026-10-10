// SPDX-FileCopyrightText: 2026 dschaefer79 <dschaefer79@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

// "Save settings to file…" and "Load settings from file…" for a settings
// page: the settings of both widgets and the keyboard shortcuts, through
// plasma-tile-menu export|import. loaded() gets this page's part of a
// loaded file, as {key: "value"}, to show in the page's fields.
ColumnLayout {
    id: settingsFile

    // "tiling" or "resolution": the part of the file for this page.
    property string section
    signal loaded(var values)

    spacing: Kirigami.Units.smallSpacing

    function quoted(text) {
        return "'" + text.replace(/'/g, "'\\''") + "'";
    }
    function localPath(url) {
        return decodeURIComponent(String(url).replace(/^file:\/\//, ""));
    }
    function run(command, path) {
        message.visible = false;
        helper.command = command;
        helper.path = path;
        helper.connectSource("plasma-tile-menu " + command + " " + quoted(path));
    }

    P5Support.DataSource {
        id: helper
        property string command
        property string path
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            const name = path.replace(/.*\//, "");
            // A load prints what it loaded, also when some of it failed.
            if (command === "import") {
                const values = {};
                String(data["stdout"]).trim().split("\n").forEach(line => {
                    const i = line.indexOf("=");
                    const dot = line.indexOf(".");
                    if (dot > 0 && i > dot && line.slice(0, dot) === settingsFile.section)
                        values[line.slice(dot + 1, i)] = line.slice(i + 1);
                });
                if (Object.keys(values).length > 0)
                    settingsFile.loaded(values);
            }
            if (data["exit code"] !== 0) {
                message.type = Kirigami.MessageType.Error;
                message.text = String(data["stderr"]).trim().split("\n").pop().replace(/^plasma-tile-menu: /, "")
                    || i18n("Could not use %1.", name);
            } else if (command === "export") {
                message.type = Kirigami.MessageType.Positive;
                message.text = i18n("Saved to %1.", name);
            } else {
                message.type = Kirigami.MessageType.Positive;
                message.text = i18n("Loaded from %1. Apply to keep this page's settings; the other widget and the keyboard shortcuts already use them.", name);
            }
            message.visible = true;
        }
    }

    FileDialog {
        id: saveDialog
        title: i18n("Save Window Tiling settings")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "conf"
        nameFilters: [i18n("Settings files (*.conf)"), i18n("All files (*)")]
        onAccepted: settingsFile.run("export", settingsFile.localPath(selectedFile))
    }
    FileDialog {
        id: loadDialog
        title: i18n("Load Window Tiling settings")
        fileMode: FileDialog.OpenFile
        nameFilters: [i18n("Settings files (*.conf)"), i18n("All files (*)")]
        onAccepted: settingsFile.run("import", settingsFile.localPath(selectedFile))
    }

    RowLayout {
        QQC2.Button {
            text: i18n("Save settings to file…")
            icon.name: "document-save"
            onClicked: saveDialog.open()
        }
        QQC2.Button {
            text: i18n("Load settings from file…")
            icon.name: "document-open"
            onClicked: loadDialog.open()
        }
    }
    QQC2.Label {
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        opacity: 0.7
        text: i18n("The applied settings of the Window Tiling and Resolution widgets and the keyboard shortcuts, to keep a copy or to use them on another computer.")
    }
    Kirigami.InlineMessage {
        id: message
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        showCloseButton: true
    }
}
