# SPDX-FileCopyrightText: 2026 dschaefer79 <dschaefer79@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

kcmutils_add_qml_kcm(kcm_plasma_tile_menu SOURCES plugin.cpp)
target_link_libraries(kcm_plasma_tile_menu PRIVATE widgetsettings)
