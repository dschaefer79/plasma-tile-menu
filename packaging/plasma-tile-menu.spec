# Keep the files' real dates: with all of them set to the changelog date,
# Plasma's QML cache does not notice that an upgrade changed them.
%global clamp_mtime_to_source_date_epoch 0
%global source_date_epoch_from_changelog 0

Name:           plasma-tile-menu
Version:        1.34
Release:        1%{?dist}
Summary:        KDE Plasma system tray menus for window tiling and screen resolution
License:        GPL-3.0-or-later
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  desktop-file-utils
# The Window Tiling page of System Settings
BuildRequires:  cmake
BuildRequires:  extra-cmake-modules
BuildRequires:  gcc-c++
BuildRequires:  cmake(Qt6Core)
BuildRequires:  cmake(Qt6Qml)
BuildRequires:  cmake(Qt6Quick)
BuildRequires:  cmake(KF6CoreAddons)
BuildRequires:  cmake(KF6KCMUtils)
Requires:       kwin >= 6.0
Requires:       plasma-workspace >= 6.0
Requires:       /usr/bin/kwriteconfig6
Requires:       /usr/bin/kscreen-doctor
Requires:       /usr/bin/busctl
Requires:       python3
Requires(posttrans): systemd
Recommends:     libnotify
# Adding resolutions in a Plasma X11 session
Recommends:     xrandr
Recommends:     cvt

%description
Two KDE Plasma 6 system tray widgets, the counterparts of xfce-tile-menu and
xfce-resolution-menu:

Window Tiling tiles the windows of the current desktop into side-by-side
columns, rows stacked top to bottom, or a grid of both: automatically (3
columns on screens at least 5120 pixels wide, such as 5120x1440, and 2
otherwise; rows follow the same rule by screen height), or into 4, 3 or 2
columns, 3 or 2 rows, or a 2x2, 3x2 or 4x2 grid directly, and puts them back with
Restore. New windows can be tiled automatically as they open. Its settings turn
columns and rows on or off, set the auto rules and window gap, and can turn
on snapping: a window dragged with the mouse and dropped fills the column,
row or grid cell under the pointer. Snapping can be limited to drops with
Shift held, and Shift can swap columns and rows. The tiling runs in a KWin
script.

Resolution Menu switches the screen resolution with kscreen-doctor from a
list you edit in its settings (1920x1080, 1900x1000 and 5120x1440 by
default). Sizes the screen does not offer are added to it, as KWin custom
modes on Wayland or with xrandr on X11, when picked or right away from the
settings.

Both widgets are put in each user's system tray (notification area) at
their next login, or right away by running plasma-tile-menu setup.

This software was written entirely with Claude, Anthropic's AI assistant.

%prep
%autosetup

%build
%cmake -S kcm
%cmake_build

%install
%cmake_install
install -Dpm 0755 plasma-tile-menu %{buildroot}%{_bindir}/plasma-tile-menu
install -Dpm 0644 plasma-tile-menu.desktop %{buildroot}%{_datadir}/applications/plasma-tile-menu.desktop
install -Dpm 0644 plasma-tile-menu-setup.desktop %{buildroot}%{_sysconfdir}/xdg/autostart/plasma-tile-menu-setup.desktop
install -Dpm 0644 org.dschaefer.tilemenu.desktop %{buildroot}%{_datadir}/kglobalaccel/org.dschaefer.tilemenu.desktop
install -dm 0755 %{buildroot}%{_datadir}/kwin/scripts %{buildroot}%{_datadir}/plasma/plasmoids
cp -pr kwin/org.dschaefer.tilemenu.kwin %{buildroot}%{_datadir}/kwin/scripts/
cp -pr plasmoids/org.dschaefer.tilemenu plasmoids/org.dschaefer.resolutionmenu %{buildroot}%{_datadir}/plasma/plasmoids/
install -dm 0755 %{buildroot}%{_datadir}/icons/hicolor/scalable/actions
install -pm 0644 icons/*.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/actions/

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/plasma-tile-menu.desktop
desktop-file-validate %{buildroot}%{_sysconfdir}/xdg/autostart/plasma-tile-menu-setup.desktop
desktop-file-validate %{buildroot}%{_datadir}/kglobalaccel/org.dschaefer.tilemenu.desktop
for f in $(find %{buildroot} -name metadata.json); do
    python3 -m json.tool "$f" >/dev/null
done

%posttrans
# For users who are logged in: KDE's shortcut service reads the "Window
# Tiling" shortcuts only when it starts, so restart it to load this
# version's actions and default keys; then restart Plasma, so the new
# widgets are used.
for user in $(loginctl list-users --no-legend 2>/dev/null | awk '{print $2}'); do
    for service in plasma-kglobalaccel.service plasma-plasmashell.service; do
        if systemctl --user -M "$user@" is-active -q $service 2>/dev/null; then
            systemctl --user -M "$user@" restart $service >/dev/null 2>&1 || :
        fi
    done
done
:

%files
%license LICENSE
%doc README.md
%{_bindir}/plasma-tile-menu
%{_datadir}/applications/plasma-tile-menu.desktop
%config(noreplace) %{_sysconfdir}/xdg/autostart/plasma-tile-menu-setup.desktop
%{_datadir}/kwin/scripts/org.dschaefer.tilemenu.kwin/
%{_datadir}/kglobalaccel/org.dschaefer.tilemenu.desktop
%{_datadir}/plasma/plasmoids/org.dschaefer.tilemenu/
%{_datadir}/plasma/plasmoids/org.dschaefer.resolutionmenu/
%{_qt6_plugindir}/plasma/kcms/systemsettings/kcm_plasma_tile_menu.so
%{_qt6_plugindir}/plasma/kcms/systemsettings/kcm_plasma_resolution_menu.so
%{_datadir}/applications/kcm_plasma_tile_menu.desktop
%{_datadir}/applications/kcm_plasma_resolution_menu.desktop
%{_datadir}/icons/hicolor/scalable/actions/tilemenu-*-symbolic.svg

%changelog
* Sun Oct 11 2026 dschaefer79 <dschaefer79@gmail.com> - 1.34-1
- README.md, describing the widgets and noting that the software was
  written entirely with Claude, Anthropic's AI assistant; the package
  description says so too

* Sun Oct 11 2026 dschaefer79 <dschaefer79@gmail.com> - 1.33-1
- License changed from MIT to GPL-3.0-or-later: LICENSE file with the GNU
  General Public License version 3, and SPDX license headers in the
  source files

* Sun Oct 11 2026 dschaefer79 <dschaefer79@gmail.com> - 1.32-1
- System Settings > Display & Monitor > Resolution Menu is now a page of
  System Settings with all the settings of the Resolution widget (the
  list of resolutions, adding them to the screen, settings file), like
  Window Tiling Menu, instead of opening the widget's settings window

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.31-1
- System Settings > Window Management > Window Tiling Menu is now a page
  of System Settings with all the settings of the Window Tiling widget,
  applied with Apply (Defaults resets them), instead of opening the
  widget's settings window
- The package is no longer noarch: the page is a compiled plugin

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.30-1
- Entries in System Settings: "Window Tiling Menu" under Window Management
  and "Resolution Menu" under Display & Monitor open the settings of the
  widgets (putting a widget taken off with Quit back first). New command:
  plasma-tile-menu configure [tiling|resolution]

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.29-1
- New version, same contents as 1.28

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.28-1
- Window Tiling shortcuts: on Wayland, "Tile in 4 columns" and "Tile in
  4 x 2 grid" were still missing from System Settings > Shortcuts after an
  upgrade, until the next login: KDE's shortcut service runs inside KWin
  and keeps the shortcuts file it read when KWin started. When it lacks
  actions, the widget now has it read the file again, keeping your keys

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.27-1
- Load settings from file: the keyboard shortcuts are now set through
  KDE's shortcut service. On Wayland it runs inside KWin, so restarting
  it (as before) did not work and the shortcuts were not loaded. A key
  that cannot be set is reported; the other settings still load

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.26-1
- "Save settings to file…" and "Load settings from file…" in the settings
  of both widgets: the settings of the tiling and resolution menus and the
  keyboard shortcuts in one file. New commands: plasma-tile-menu
  export|import FILE

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.25-1
- Resolution: "Quit" at the end of the menu takes the widget off the
  tray or panel; "Window Tiling Menu" in the applications menu puts it
  back. New command: plasma-tile-menu quit resolution

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.24-1
- "Window Tiling Menu" in the applications menu (Utilities) puts the
  tiling menu on the panel, also after Quit

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.23-1
- Window Tiling: "Quit" at the end of the menu takes the widget off the tray or panel;
  tiling and its shortcuts keep working. "plasma-tile-menu setup" puts
  it back. New command: plasma-tile-menu quit

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.22-1
- Restart KDE's shortcut service for logged-in users when the package is
  installed or upgraded, so the "Window Tiling" shortcuts in System
  Settings always list every action with its default key

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.21-1
- Window Tiling shortcuts: after an upgrade, KDE's shortcut service kept
  the actions and keys of the version it first loaded, so "Tile in 4
  columns" and "Tile in 4 x 2 grid" were missing and no shortcut had a
  key. The widget now restarts the service once when the shortcuts file
  is newer than it, so all actions and their default keys are active

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.20-1
- Window Tiling: the menu shows the keyboard shortcut of each tiling
  entry and of Restore windows, on the right, read from System
  Settings each time the menu opens

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.19-1
- Window Tiling: opening the widget's settings no longer tiles the
  windows when "Tile new windows" is on; Plasma's own windows are never
  tiled

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.18-1
- Window Tiling: default keyboard shortcuts: Meta+Alt+A tiles
  automatically, Meta+Alt+2, 3 or 4 tiles in 2, 3 or 4 columns,
  Meta+Ctrl+Alt+2 or 3 in 2 or 3 rows, Meta+Ctrl+2, 3 or 4 in a 2 x 2,
  3 x 2 or 4 x 2 grid, and Meta+Alt+0 restores the windows.

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.17-1
- Window Tiling: layouts keep their columns, rows and cells again (undoing
  the change of 1.16); the windows that do not fit are now tiled too,
  into the cell under their middle, behind the windows in front

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.16-1
- Window Tiling: the menu entries and shortcuts tile all windows on the
  screen, not only as many as the layout has cells; a column with more
  windows than rows splits its height among all of them

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.15-1
- Window Tiling: setting "Resize neighbouring windows together" (off by
  default): dragging the left or right edge of a window also moves the
  edge of the window beside it, keeping the gap, so windows side by side
  stay together

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.14-1
- Resolution Menu: an Edit button on each resolution in the settings loads it
  into the width and height fields to change it

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.13-1
- Window Tiling: menu entries and shortcuts to tile in 4 columns and in a
  4 x 2 grid

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.12-1
- Window Tiling: the gap also applies to KWin's own tiling: its tile layout
  (Meta+T, Shift while dragging) gets the same padding, and quick-tiled
  windows (screen edges, Meta+arrows) keep the gap around them

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.11-1
- Window Tiling: keyboard shortcuts for every option, in a "Window Tiling"
  group in System Settings > Shortcuts, and a "Keyboard shortcuts…" entry
  in the menu to open it
- Shortcuts to turn automatic tiling, tiling new windows and tiling as a
  whole on or off; the widget follows these changes

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.10-2
- Fix choosing millimetres for the gap: the unit was not saved
- Restore windows: a window moved by other means than the mouse (keyboard,
  another tool) since it was tiled goes back to its new place

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.10-1
- Window Tiling: the gap between windows can be set in millimetres, worked
  out from each screen's physical size, as well as in pixels

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.9-4
- Tile new windows into the layout last used on their screen (columns,
  rows or grid) instead of always the automatic one
- Restore windows: keep each window's original place when the screen is
  tiled again (for example for a new window), unless you moved the window

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.9-3
- Restart Plasma for logged-in users after installing or upgrading, so the
  new version is used without running systemctl as the user
- Keep the files' real modification dates so Plasma's QML cache notices
  upgrades

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.9-2
- Reload the KWin tiling script when the installed one changes; after an
  upgrade KWin kept running the old script, so new actions such as the
  2x2 and 3x2 grids did nothing

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.9-1
- Window Tiling: menu entries and shortcuts to tile in a 2x2 or 3x2 grid
- Option in the menu and the settings to tile every new window
  automatically as it opens
- Rename the icons to tilemenu-*: the plasma-tile-* names showed the Plasma
  logo instead

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.8-1
- Both widgets: compact popup menus with less space between the entries,
  instead of the standard menu style

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.7-2
- Window Tiling: the menu switch is now "Automatic tiling", which turns
  snapping of dropped windows on or off; hiding the "Tile automatically"
  entry stays in the settings

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.7-1
- Window Tiling: replace the Options list in the menu with two switches,
  "Tile automatically" and "Disable tiling"
- Disable tiling turns off all tiling and snapping (also in the settings);
  Restore windows still works

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.6-1
- Window Tiling: option in the menu and the settings to hide the
  "Tile automatically" entry
- Reopen the first menu after Plasma starts once it knows its real size,
  so it is not cut off

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.5-1
- Window Tiling: Options section in the menu to turn columns, rows,
  snapping, snapping only with Shift, and Shift swapping on or off
- Fix the first menu after Plasma starts coming out too short, with a
  scroll arrow

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.4-1
- Window Tiling: option to snap only when Shift is held while dropping
- Option to hold Shift while dropping to snap into rows instead of columns
  (or columns instead of rows, or swapped in a grid)
- Explain how dropping works in the settings, the menu and the tooltip

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.3-1
- Window Tiling: settings to turn vertical (columns) and horizontal (rows)
  tiling on or off; with both on, windows are tiled into a grid
- Rows have the same settings as columns: tall screen height, rows on tall
  screens and rows on other screens
- Menu entries and shortcuts to tile in 3 or 2 rows; snapping fills the
  column, row or grid cell under the pointer
- plasma-tile-menu sync-config now takes KEY=VALUE settings

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.2-1
- Resolution Menu: option to add a resolution to the screen right away when
  it is added in the settings (KWin custom mode on Wayland, xrandr on X11),
  and a button per resolution to add it now
- Add plasma-tile-menu add-mode WIDTHxHEIGHT
- Switch resolutions with xrandr in Plasma X11 sessions

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.1-2
- Open a compact menu next to the tray icon instead of the large system
  tray popup, which left a lot of empty space around the entries

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.1-1
- Show both widgets in the system tray (notification area) instead of as
  separate panel buttons; existing panel buttons are moved at next login
- Use a monochrome monitor icon for the Resolution widget

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.0-2
- Resolution Menu: add sizes the screen does not offer (such as 1900x1000)
  as KWin custom modes instead of failing

* Sat Oct 10 2026 dschaefer79 <dschaefer79@gmail.com> - 1.0-1
- Initial package: KDE Plasma 6 port of xfce-tile-menu and xfce-resolution-menu
