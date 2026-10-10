// SPDX-FileCopyrightText: 2026 dschaefer79 <dschaefer79@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

// One compact entry of the popup menu: icon (or check mark) and text.
MouseArea {
    id: row

    property string text
    property string iconName
    property bool checkable: false
    property bool checked: false
    signal activated()

    Layout.fillWidth: true
    implicitWidth: layout.implicitWidth + Kirigami.Units.largeSpacing * 2
    implicitHeight: layout.implicitHeight + Kirigami.Units.smallSpacing
    hoverEnabled: true
    opacity: enabled ? 1 : 0.5
    onClicked: activated()

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.highlightColor
        opacity: 0.3
        visible: row.containsMouse && row.enabled
    }

    RowLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.mediumSpacing

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: row.checkable ? (row.checked ? "checkmark" : "") : row.iconName
        }
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: row.text
        }
    }
}
