// SPDX-FileCopyrightText: 2026 dschaefer79 <dschaefer79@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property var cfg_resolutions: []
    property var cfg_resolutionsDefault: []
    property alias cfg_addToScreen: addToScreen.checked
    property bool cfg_addToScreenDefault: true

    // Row being edited in the fields below, or -1 while adding.
    property int editIndex: -1

    // Assign a new array so the dialog notices the change. Rows move, so
    // an edit in progress ends.
    function update(list) {
        cfg_resolutions = list;
        editIndex = -1;
    }

    // Add a size to the screen's list of modes right away: a KWin custom
    // mode on Wayland, xrandr --newmode/--addmode on X11.
    function addToScreenNow(mode) {
        status.text = i18n("Adding %1 to the screen…", mode.replace("x", " × "));
        status.type = Kirigami.MessageType.Information;
        status.visible = true;
        // mode is built from two numbers or checked against WIDTHxHEIGHT.
        executable.connectSource("plasma-tile-menu add-mode " + mode);
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            const ok = data["exit code"] === 0;
            const text = (ok ? data["stdout"] : data["stderr"]).trim()
                .replace(/^plasma-tile-menu: /, "");
            status.text = text || (ok ? i18n("Done.") : i18n("Could not add the resolution."));
            status.type = ok ? Kirigami.MessageType.Positive : Kirigami.MessageType.Error;
            status.visible = true;
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: i18n("Resolutions shown in the menu, top to bottom. A resolution your screen does not offer yet is added to it when you pick it from the menu, or right away.")
        }

        Repeater {
            model: page.cfg_resolutions
            delegate: RowLayout {
                required property string modelData
                required property int index
                Layout.fillWidth: true

                QQC2.Label {
                    Layout.fillWidth: true
                    text: modelData.replace("x", " × ")
                    font.bold: index === page.editIndex
                }
                QQC2.ToolButton {
                    icon.name: "document-edit"
                    onClicked: {
                        const [w, h] = modelData.split("x").map(Number);
                        widthBox.value = w;
                        heightBox.value = h;
                        page.editIndex = index;
                    }
                    QQC2.ToolTip.text: i18n("Edit")
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.ToolButton {
                    icon.name: "monitor-symbolic"
                    onClicked: page.addToScreenNow(modelData)
                    QQC2.ToolTip.text: i18n("Add to the screen now")
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.ToolButton {
                    icon.name: "go-up"
                    enabled: index > 0
                    onClicked: {
                        const list = page.cfg_resolutions.slice();
                        list.splice(index - 1, 0, list.splice(index, 1)[0]);
                        page.update(list);
                    }
                    QQC2.ToolTip.text: i18n("Move up")
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.ToolButton {
                    icon.name: "go-down"
                    enabled: index < page.cfg_resolutions.length - 1
                    onClicked: {
                        const list = page.cfg_resolutions.slice();
                        list.splice(index + 1, 0, list.splice(index, 1)[0]);
                        page.update(list);
                    }
                    QQC2.ToolTip.text: i18n("Move down")
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.ToolButton {
                    icon.name: "list-remove"
                    enabled: page.cfg_resolutions.length > 1
                    onClicked: {
                        const list = page.cfg_resolutions.slice();
                        list.splice(index, 1);
                        page.update(list);
                    }
                    QQC2.ToolTip.text: i18n("Remove")
                    QQC2.ToolTip.visible: hovered
                }
            }
        }

        RowLayout {
            QQC2.SpinBox {
                id: widthBox
                from: 320
                to: 32768
                value: 1920
                editable: true
            }
            QQC2.Label {
                text: "×"
            }
            QQC2.SpinBox {
                id: heightBox
                from: 200
                to: 32768
                value: 1080
                editable: true
            }
            QQC2.Button {
                text: page.editIndex >= 0 ? i18n("Save") : i18n("Add")
                icon.name: page.editIndex >= 0 ? "document-save" : "list-add"
                onClicked: {
                    const mode = widthBox.value + "x" + heightBox.value;
                    const found = page.cfg_resolutions.indexOf(mode);
                    if (page.editIndex >= 0) {
                        // Replace the edited row, unless the size is listed already.
                        if (found >= 0 && found !== page.editIndex) {
                            status.text = i18n("%1 is already in the list.", mode.replace("x", " × "));
                            status.type = Kirigami.MessageType.Warning;
                            status.visible = true;
                            return;
                        }
                        const list = page.cfg_resolutions.slice();
                        list[page.editIndex] = mode;
                        page.update(list);
                    } else if (found < 0) {
                        page.update(page.cfg_resolutions.concat([mode]));
                    }
                    if (addToScreen.checked)
                        page.addToScreenNow(mode);
                }
            }
            QQC2.Button {
                visible: page.editIndex >= 0
                text: i18n("Cancel")
                icon.name: "dialog-cancel"
                onClicked: page.editIndex = -1
            }
        }

        QQC2.CheckBox {
            id: addToScreen
            text: i18n("Add new resolutions to the screen right away")
        }

        Kirigami.InlineMessage {
            id: status
            Layout.fillWidth: true
            visible: false
            showCloseButton: true
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
        }
        SettingsFile {
            section: "resolution"
            onLoaded: values => {
                if ("resolutions" in values)
                    page.update(values.resolutions.split(",")
                        .filter(r => /^[1-9][0-9]{2,4}x[1-9][0-9]{2,4}$/.test(r)));
                if (values.addToScreen === "true" || values.addToScreen === "false")
                    page.cfg_addToScreen = values.addToScreen === "true";
            }
        }
    }
}
