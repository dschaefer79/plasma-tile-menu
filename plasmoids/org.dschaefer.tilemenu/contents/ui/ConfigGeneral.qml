// SPDX-FileCopyrightText: 2026 dschaefer79 <dschaefer79@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property alias cfg_disabled: disabled.checked
    property alias cfg_showAuto: showAuto.checked
    property alias cfg_tileNew: tileNew.checked
    property alias cfg_vertical: vertical.checked
    property alias cfg_horizontal: horizontal.checked
    property alias cfg_wideMinWidth: wideMinWidth.value
    property alias cfg_wideColumns: wideColumns.value
    property alias cfg_normalColumns: normalColumns.value
    property alias cfg_tallMinHeight: tallMinHeight.value
    property alias cfg_tallRows: tallRows.value
    property alias cfg_normalRows: normalRows.value
    property alias cfg_gap: gap.value
    property alias cfg_gapMm: gapMm.value
    property alias cfg_gapUnitIndex: gapUnit.currentIndex
    property alias cfg_snap: snap.checked
    property alias cfg_snapShiftOnly: snapShiftOnly.checked
    property alias cfg_snapShiftSwap: snapShiftSwap.checked
    property alias cfg_resizeNeighbours: resizeNeighbours.checked

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: disabled
            Kirigami.FormData.label: i18n("Tiling:")
            text: i18n("Disable tiling completely")
        }
        QQC2.Label {
            text: i18n("Nothing is tiled or snapped while this is on; Restore windows still works.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
        QQC2.CheckBox {
            id: tileNew
            enabled: !disabled.checked
            text: i18n("Tile new windows automatically")
        }
        QQC2.Label {
            text: i18n("Each window that opens is tiled together with the others on its screen,\nin the layout last used there (at first, “Tile automatically”).")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
        QQC2.CheckBox {
            id: showAuto
            Kirigami.FormData.label: i18n("Menu:")
            enabled: !disabled.checked
            text: i18n("Show “Tile automatically”")
        }
        QQC2.Label {
            text: i18n("Untick to keep only the entries with a fixed number of columns or rows.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: i18n("With both on, windows are tiled into a grid of columns and rows.")
        }

        QQC2.CheckBox {
            id: vertical
            Kirigami.FormData.label: i18n("Vertical:")
            text: i18n("Tile into columns side by side")
            // Keep at least one direction on.
            enabled: !checked || horizontal.checked
        }
        QQC2.SpinBox {
            id: wideMinWidth
            Kirigami.FormData.label: i18n("Wide screen from (pixels wide):")
            enabled: vertical.checked
            from: 640
            to: 32768
            editable: true
        }
        QQC2.SpinBox {
            id: wideColumns
            Kirigami.FormData.label: i18n("Columns on wide screens:")
            enabled: vertical.checked
            from: 1
            to: 8
        }
        QQC2.SpinBox {
            id: normalColumns
            Kirigami.FormData.label: i18n("Columns on other screens:")
            enabled: vertical.checked
            from: 1
            to: 8
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: horizontal
            Kirigami.FormData.label: i18n("Horizontal:")
            text: i18n("Tile into rows stacked top to bottom")
            enabled: !checked || vertical.checked
        }
        QQC2.SpinBox {
            id: tallMinHeight
            Kirigami.FormData.label: i18n("Tall screen from (pixels high):")
            enabled: horizontal.checked
            from: 480
            to: 32768
            editable: true
        }
        QQC2.SpinBox {
            id: tallRows
            Kirigami.FormData.label: i18n("Rows on tall screens:")
            enabled: horizontal.checked
            from: 1
            to: 8
        }
        QQC2.SpinBox {
            id: normalRows
            Kirigami.FormData.label: i18n("Rows on other screens:")
            enabled: horizontal.checked
            from: 1
            to: 8
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Gap between windows:")
            QQC2.SpinBox {
                id: gap
                visible: gapUnit.currentIndex === 0
                from: 0
                to: 100
            }
            QQC2.SpinBox {
                id: gapMm
                visible: gapUnit.currentIndex === 1
                from: 0
                to: 50
            }
            QQC2.ComboBox {
                id: gapUnit
                // Index 0: pixels, 1: millimetres.
                model: [i18n("pixels"), i18n("mm")]
            }
        }
        QQC2.Label {
            visible: gapUnit.currentIndex === 1
            text: i18n("Millimetres on the screen, worked out from its physical size.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
        QQC2.CheckBox {
            id: resizeNeighbours
            Kirigami.FormData.label: i18n("Resizing:")
            text: i18n("Resize neighbouring windows together")
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            text: i18n("Dragging the left or right edge of a window also moves the edge of the window next to it, so windows side by side stay together.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
        QQC2.CheckBox {
            id: snap
            Kirigami.FormData.label: i18n("Snapping:")
            text: i18n("Automatic tiling: snap windows into place when dropped")
        }
        QQC2.CheckBox {
            id: snapShiftOnly
            enabled: snap.checked
            text: i18n("Only when Shift is held while dropping")
        }
        QQC2.CheckBox {
            id: snapShiftSwap
            enabled: snap.checked
            text: (vertical.checked && horizontal.checked)
                ? i18n("Hold Shift to swap columns and rows")
                : vertical.checked ? i18n("Hold Shift to snap into rows instead of columns")
                                   : i18n("Hold Shift to snap into columns instead of rows")
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: {
                if (!snap.checked)
                    return i18n("Drag a window with the mouse and let go: with snapping on, it fills the column, row or grid cell under the pointer.");
                const other = vertical.checked && horizontal.checked ? i18n("with columns and rows swapped")
                            : vertical.checked ? i18n("into the row") : i18n("into the column");
                const here = vertical.checked && horizontal.checked ? i18n("the grid cell")
                           : vertical.checked ? i18n("the column") : i18n("the row");
                if (snapShiftOnly.checked && snapShiftSwap.checked)
                    return i18n("A window dropped normally stays where it is. Hold Shift while dropping to snap it %1 under the pointer.", other);
                if (snapShiftOnly.checked)
                    return i18n("A window dropped normally stays where it is. Hold Shift while dropping to make it fill %1 under the pointer.", here);
                if (snapShiftSwap.checked)
                    return i18n("A dropped window fills %1 under the pointer. Hold Shift while dropping to snap it %2 instead.", here, other);
                return i18n("A dropped window fills %1 under the pointer.", here);
            }
        }
        QQC2.Label {
            visible: snap.checked && (snapShiftOnly.checked || snapShiftSwap.checked)
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("While Shift is held during a drag, KWin shows the outline of its own tile layout; the window still goes where this widget puts it.")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Settings file")
        }
        SettingsFile {
            section: "tiling"
            // Show a loaded file's values in the fields; Apply keeps them.
            onLoaded: values => {
                for (const key in values) {
                    const name = "cfg_" + key;
                    if (!(name in page))
                        continue;
                    const value = values[key];
                    if (typeof page[name] === "boolean") {
                        if (value === "true" || value === "false")
                            page[name] = value === "true";
                    } else if (typeof page[name] === "number" && value !== "" && !isNaN(Number(value))) {
                        page[name] = Number(value);
                    }
                }
            }
        }
    }
}
