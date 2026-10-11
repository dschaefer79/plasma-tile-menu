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

From the [latest GitHub release](https://github.com/dschaefer79/plasma-tile-menu/releases/latest):

| System | Plasma | Package |
|---|---|---|
| Fedora 45 | 6.7 | `plasma-tile-menu-1.35-1.fc45.x86_64.rpm` |
| Fedora 44 | 6.7 | `plasma-tile-menu-1.35-1.fc44.x86_64.rpm` |
| Ubuntu 26.10 (Kubuntu) | 6.7 | `plasma-tile-menu_1.35_ubuntu26.10_amd64.deb` |
| Ubuntu 26.04 (Kubuntu) | 6.6 | `plasma-tile-menu_1.35_ubuntu26.04_amd64.deb` |
| Debian 13 (trixie) | 6.3 | `plasma-tile-menu_1.35_debian13_amd64.deb` |

On Fedora:

```
sudo dnf install https://github.com/dschaefer79/plasma-tile-menu/releases/download/v1.35/plasma-tile-menu-1.35-1.fc45.x86_64.rpm
```

(`fc44` instead of `fc45` on Fedora 44). The package is also built in
Copr: `sudo dnf copr enable dschaefer79/plasma-tile-menu` and
`sudo dnf install plasma-tile-menu`.

On Ubuntu and Debian, for example Ubuntu 26.10:

```
wget https://github.com/dschaefer79/plasma-tile-menu/releases/download/v1.35/plasma-tile-menu_1.35_ubuntu26.10_amd64.deb
sudo apt install ./plasma-tile-menu_1.35_ubuntu26.10_amd64.deb
```

(`ubuntu26.04` or `debian13` instead of `ubuntu26.10` on those systems).

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

The Debian packaging for Ubuntu is in `packaging/debian/`. From a checkout,
on Ubuntu:

```
cp -r packaging/debian debian
sudo apt build-dep ./
dpkg-buildpackage -b -us -uc
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
