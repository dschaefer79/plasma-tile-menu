// SPDX-FileCopyrightText: 2026 dschaefer79 <dschaefer79@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import "file:///usr/share/plasma/plasmoids/org.dschaefer.tilemenu/contents/ui" as Widget

// The settings page of the Window Tiling widget, in System Settings: its
// cfg_ fields are kept in step with kcm.values.
Widget.ConfigGeneral {
    id: page

    property bool showing: false

    // Show kcm.values in the fields.
    function show() {
        showing = true;
        const values = kcm.values;
        for (const key in values) {
            if (("cfg_" + key) in page)
                page["cfg_" + key] = values[key];
        }
        showing = false;
        collect();
    }

    // Hand the fields to kcm, which works out whether there is something
    // to apply.
    function collect() {
        if (showing)
            return;
        const values = {};
        for (const key in kcm.values) {
            if (("cfg_" + key) in page)
                values[key] = page["cfg_" + key];
        }
        kcm.values = values;
    }

    Component.onCompleted: {
        for (const key in kcm.values) {
            const changed = page["cfg_" + key + "Changed"];
            if (changed)
                changed.connect(collect);
        }
        show();
    }

    Connections {
        target: kcm
        function onReset() {
            page.show();
        }
    }
}
