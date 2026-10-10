// SPDX-FileCopyrightText: 2026 dschaefer79 <dschaefer79@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <KQuickConfigModule>
#include <QVariantMap>

// A page of System Settings with the settings of a widget of
// plasma-tile-menu, "tiling" or "resolution" as named by the page's
// metadata (X-PlasmaTileMenu-Widget). The widget takes them over through
// plasma-tile-menu's import file, as with "Load settings from file…".
class WidgetSettings : public KQuickConfigModule
{
    Q_OBJECT
    // The settings shown, by key of the widget's configuration.
    Q_PROPERTY(QVariantMap values READ values WRITE setValues NOTIFY valuesChanged)

public:
    WidgetSettings(QObject *parent, const KPluginMetaData &data);

    QVariantMap values() const;
    void setValues(const QVariantMap &values);

    void load() override;
    void save() override;
    void defaults() override;

Q_SIGNALS:
    void valuesChanged();
    // values was replaced (load, defaults): show it in the fields.
    void reset();

private:
    QVariantMap typed(const QVariantMap &values) const;
    QString settingsFile(const QString &prefix) const;
    void update();

    QString m_widget;
    QVariantMap m_defaults;
    QVariantMap m_saved;
    QVariantMap m_values;
};
