// SPDX-FileCopyrightText: 2026 dschaefer79 <dschaefer79@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "widgetsettings.h"

#include <QDir>
#include <QFile>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QXmlStreamReader>

namespace
{
// Where plasma-tile-menu keeps the widgets' settings: WIDGET.conf, the copy
// a widget stores on each change, and import-WIDGET.conf, settings for the
// widget to take over (see store-config and take-import).
QString configDir()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/plasma-tile-menu");
}

// KEY=VALUE lines of a file; empty if it cannot be read.
QVariantMap readSettings(const QString &path)
{
    QVariantMap values;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return values;
    }
    while (!file.atEnd()) {
        const QString line = QString::fromUtf8(file.readLine()).trimmed();
        const qsizetype i = line.indexOf(QLatin1Char('='));
        if (i > 0) {
            values.insert(line.left(i), line.mid(i + 1));
        }
    }
    return values;
}

// A value as the widgets write it: true/false, a number, or a list joined
// with commas.
QString text(const QVariant &value)
{
    if (value.typeId() == QMetaType::Bool) {
        return QLatin1String(value.toBool() ? "true" : "false");
    }
    if (value.typeId() == QMetaType::QStringList) {
        return value.toStringList().join(QLatin1Char(','));
    }
    return value.toString();
}

bool writeSettings(const QString &path, const QVariantMap &values)
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }
    for (auto it = values.cbegin(); it != values.cend(); ++it) {
        file.write((it.key() + QLatin1Char('=') + text(it.value()) + QLatin1Char('\n')).toUtf8());
    }
    return file.commit();
}

// The settings and their defaults, from a widget's configuration schema.
QVariantMap schemaDefaults(const QString &plasmoid)
{
    QVariantMap defaults;
    QFile file(QStandardPaths::locate(QStandardPaths::GenericDataLocation,
                                      QStringLiteral("plasma/plasmoids/%1/contents/config/main.xml").arg(plasmoid)));
    if (!file.open(QIODevice::ReadOnly)) {
        return defaults;
    }
    QXmlStreamReader xml(&file);
    QString name;
    QString type;
    while (!xml.atEnd()) {
        if (xml.readNext() != QXmlStreamReader::StartElement) {
            continue;
        }
        if (xml.name() == QLatin1String("entry")) {
            name = xml.attributes().value(QLatin1String("name")).toString();
            type = xml.attributes().value(QLatin1String("type")).toString();
        } else if (xml.name() == QLatin1String("default") && !name.isEmpty()) {
            const QString value = xml.readElementText().trimmed();
            if (type == QLatin1String("Bool")) {
                defaults.insert(name, value == QLatin1String("true"));
            } else if (type == QLatin1String("Int")) {
                defaults.insert(name, value.toInt());
            } else if (type == QLatin1String("StringList")) {
                defaults.insert(name, value.split(QLatin1Char(','), Qt::SkipEmptyParts));
            }
            name.clear();
        }
    }
    return defaults;
}
}

WidgetSettings::WidgetSettings(QObject *parent, const KPluginMetaData &data)
    : KQuickConfigModule(parent, data)
    , m_widget(data.value(QStringLiteral("X-PlasmaTileMenu-Widget")))
{
    m_defaults = schemaDefaults(m_widget == QLatin1String("resolution") ? QStringLiteral("org.dschaefer.resolutionmenu")
                                                                        : QStringLiteral("org.dschaefer.tilemenu"));
    setButtons(Apply | Default);
    m_saved = m_values = m_defaults;
}

QVariantMap WidgetSettings::values() const
{
    return m_values;
}

void WidgetSettings::setValues(const QVariantMap &values)
{
    QVariantMap merged = m_values;
    merged.insert(typed(values));
    if (merged == m_values) {
        return;
    }
    m_values = merged;
    Q_EMIT valuesChanged();
    update();
}

// The known settings of values, with the type of their default.
QVariantMap WidgetSettings::typed(const QVariantMap &values) const
{
    static const QRegularExpression size(QStringLiteral("^[1-9][0-9]{2,4}x[1-9][0-9]{2,4}$"));
    QVariantMap result;
    for (auto it = values.cbegin(); it != values.cend(); ++it) {
        const QVariant def = m_defaults.value(it.key());
        const QVariant &value = it.value();
        if (def.typeId() == QMetaType::Bool) {
            if (value.typeId() == QMetaType::Bool) {
                result.insert(it.key(), value.toBool());
            } else if (value.toString() == QLatin1String("true") || value.toString() == QLatin1String("false")) {
                result.insert(it.key(), value.toString() == QLatin1String("true"));
            }
        } else if (def.typeId() == QMetaType::Int) {
            bool ok = false;
            const double number = value.toDouble(&ok);
            if (ok) {
                result.insert(it.key(), qRound(number));
            }
        } else if (def.typeId() == QMetaType::QStringList) {
            // Lists of resolutions: from the page, or joined with commas.
            const QStringList items = value.typeId() == QMetaType::QString ? value.toString().split(QLatin1Char(','), Qt::SkipEmptyParts)
                                                                          : value.toStringList();
            QStringList list;
            for (const QString &item : items) {
                if (size.match(item).hasMatch()) {
                    list << item;
                }
            }
            if (!list.isEmpty()) {
                result.insert(it.key(), list);
            }
        }
    }
    return result;
}

QString WidgetSettings::settingsFile(const QString &prefix) const
{
    return configDir() + QLatin1Char('/') + prefix + m_widget + QStringLiteral(".conf");
}

void WidgetSettings::update()
{
    setNeedsSave(m_values != m_saved);
    setRepresentsDefaults(m_values == m_defaults);
}

void WidgetSettings::load()
{
    // The applied settings, and those the widget has not taken over yet.
    m_saved = m_defaults;
    m_saved.insert(typed(readSettings(settingsFile(QString()))));
    m_saved.insert(typed(readSettings(settingsFile(QStringLiteral("import-")))));
    m_values = m_saved;
    Q_EMIT valuesChanged();
    Q_EMIT reset();
    update();
}

void WidgetSettings::save()
{
    QDir().mkpath(configDir());
    // For the widget, which takes them over within a few seconds, and the
    // copy shown when this page is opened again.
    if (!writeSettings(settingsFile(QStringLiteral("import-")), m_values) || !writeSettings(settingsFile(QString()), m_values)) {
        setNeedsSave(true);
        return;
    }
    if (m_widget == QLatin1String("tiling")) {
        // KWin's tiling script gets them right away, also without the
        // widget (taken off with Quit), as the widget passes them.
        QStringList args{QStringLiteral("sync-config")};
        for (const char *key : {"vertical", "horizontal", "wideMinWidth", "wideColumns", "normalColumns", "tallMinHeight", "tallRows", "normalRows",
                                "gap", "gapMm", "snap", "snapShiftOnly", "snapShiftSwap", "resizeNeighbours", "disabled", "tileNew"}) {
            args << QLatin1String(key) + QLatin1Char('=') + text(m_values.value(QLatin1String(key)));
        }
        args << QStringLiteral("gapUnit=") + QLatin1String(m_values.value(QStringLiteral("gapUnitIndex")).toInt() == 1 ? "mm" : "px");
        QProcess::startDetached(QStringLiteral("plasma-tile-menu"), args);
    }
    m_saved = m_values;
    update();
}

void WidgetSettings::defaults()
{
    m_values = m_defaults;
    Q_EMIT valuesChanged();
    Q_EMIT reset();
    update();
}
