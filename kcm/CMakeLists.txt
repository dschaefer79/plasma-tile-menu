# SPDX-FileCopyrightText: 2026 dschaefer79 <dschaefer79@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

cmake_minimum_required(VERSION 3.20)
project(plasma-tile-menu-kcm LANGUAGES CXX)

find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Qml Quick)
find_package(KF6 6.0 REQUIRED COMPONENTS CoreAddons KCMUtils)

# The pages of System Settings for the two widgets, each with its ui/main.qml.
add_library(widgetsettings STATIC widgetsettings.cpp widgetsettings.h)
set_target_properties(widgetsettings PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(widgetsettings PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(widgetsettings PUBLIC Qt6::Core KF6::CoreAddons KF6::KCMUtilsQuick)

add_subdirectory(tiling)
add_subdirectory(resolution)
