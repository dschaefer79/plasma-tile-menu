<!--
SPDX-FileCopyrightText: 2026 dschaefer79 <dschaefer79@gmail.com>
SPDX-License-Identifier: GPL-3.0-or-later
-->

# plasma-tile-menu

Two KDE Plasma 6 system tray widgets:

- **Window Tiling** tiles the windows of the current desktop into columns,
  rows or a grid (automatically, or 2, 3 or 4 columns, 2 or 3 rows, a 2 × 2,
  3 × 2 or 4 × 2 grid), puts them back with Restore, can tile new windows as
  they open and snap dropped windows into place. Each action has a keyboard
  shortcut in System Settings > Shortcuts > Window Tiling.
- **Resolution Menu** switches the screen resolution from a list you edit,
  adding sizes the screen does not offer (KWin custom modes on Wayland,
  xrandr on X11).

Both have a page in System Settings: Window Management > Window Tiling Menu
and Display & Monitor > Resolution Menu.

## Installing

On Fedora 45 with KDE Plasma 6, from Copr:

```
sudo dnf copr enable dschaefer79/plasma-tile-menu
sudo dnf install plasma-tile-menu
```

The widgets appear in the system tray at the next login, or right away
after `plasma-tile-menu setup`.

## Building

The RPM spec is in `packaging/`. From a checkout:

```
sudo dnf builddep packaging/plasma-tile-menu.spec
version=$(rpmspec -q --qf '%{version}\n' packaging/plasma-tile-menu.spec | head -1)
git archive --prefix=plasma-tile-menu-$version/ -o ~/rpmbuild/SOURCES/plasma-tile-menu-$version.tar.gz HEAD
rpmbuild -ba packaging/plasma-tile-menu.spec
```

The widgets, the KWin script and the System Settings pages work together
through the `plasma-tile-menu` helper, so install the package rather than
the widgets alone.

## Written with Claude

This project was written entirely with Claude, Anthropic's AI assistant,
through Claude Code: the widgets, the KWin script, the System Settings
pages, the helper script and the RPM packaging.

## License

GPL-3.0-or-later; see [LICENSE](LICENSE).
