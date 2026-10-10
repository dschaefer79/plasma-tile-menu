// SPDX-FileCopyrightText: 2026 dschaefer79 <dschaefer79@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "video-display"
        source: "ConfigGeneral.qml"
    }
}
