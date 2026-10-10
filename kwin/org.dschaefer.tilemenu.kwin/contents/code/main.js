// SPDX-FileCopyrightText: 2026 dschaefer79 <dschaefer79@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

// Window Tiling Menu for KWin 6: tile windows into side-by-side columns,
// stacked rows or a grid of both, restore them, and optionally snap windows
// dropped with the mouse into the column, row or cell under the pointer. The panel widget triggers the actions through
// these global shortcuts and writes the settings into this script's config.

var settings = {};

function loadSettings() {
    settings = {
        wideMinWidth: Number(readConfig("wideMinWidth", 5120)),
        wideColumns: Math.max(1, Number(readConfig("wideColumns", 3))),
        normalColumns: Math.max(1, Number(readConfig("normalColumns", 2))),
        tallMinHeight: Number(readConfig("tallMinHeight", 2160)),
        tallRows: Math.max(1, Number(readConfig("tallRows", 3))),
        normalRows: Math.max(1, Number(readConfig("normalRows", 2))),
        vertical: String(readConfig("vertical", true)) === "true",
        horizontal: String(readConfig("horizontal", false)) === "true",
        gap: Math.max(0, Number(readConfig("gap", 0))),
        gapUnit: String(readConfig("gapUnit", "px")),
        gapMm: Math.max(0, Number(readConfig("gapMm", 2))),
        screenWidthsMm: String(readConfig("screenWidthsMm", "")),
        disabled: String(readConfig("disabled", false)) === "true",
        tileNew: String(readConfig("tileNew", false)) === "true",
        snap: String(readConfig("snap", false)) === "true",
        snapShiftOnly: String(readConfig("snapShiftOnly", false)) === "true",
        snapShiftSwap: String(readConfig("snapShiftSwap", false)) === "true",
        resizeNeighbours: String(readConfig("resizeNeighbours", false)) === "true",
    };
    // Tiling needs at least one direction.
    if (!settings.vertical && !settings.horizontal)
        settings.vertical = true;
}

// Original geometry of windows moved by tiling, keyed by window id:
// { geometry: {x, y, width, height}, placed: {x, y, width, height},
//   moved: bool }. placed is where tiling put the window; moved is set
// when the user drags or resizes it. A window that was moved, or is no
// longer near where it was placed, gets its current place saved as the
// one to restore at the next tiling. (Right after tiling, the window's
// own geometry cannot be used: on Wayland it changes a moment later.)
var saved = {};

function near(a, b) {
    var slack = 16;
    return Math.abs(a.x - b.x) <= slack && Math.abs(a.y - b.y) <= slack
        && Math.abs(a.width - b.width) <= slack && Math.abs(a.height - b.height) <= slack;
}

// Layout last used on each screen, keyed by output name: {columns, rows}.
// New windows are tiled into it; Restore forgets it.
var layouts = {};

function rect(r) {
    return { x: Math.round(r.x), y: Math.round(r.y),
             width: Math.round(r.width), height: Math.round(r.height) };
}

function windowId(w) {
    return String(w.internalId);
}

// Column and row counts for the screen size, whether or not that
// direction is turned on.
function columnsFor(output) {
    var wide = output.geometry.width >= settings.wideMinWidth;
    return wide ? settings.wideColumns : settings.normalColumns;
}

function rowsFor(output) {
    var tall = output.geometry.height >= settings.tallMinHeight;
    return tall ? settings.tallRows : settings.normalRows;
}

// The gap in pixels on this screen. In millimetres it needs the screen's
// physical width, which the panel widget passes as "NAME=MM;NAME=MM";
// for a screen not in that list, assume 96 dpi.
function gapFor(output) {
    if (settings.gapUnit !== "mm")
        return settings.gap;
    var pxPerMm = 96 / 25.4;
    settings.screenWidthsMm.split(";").forEach(function (pair) {
        var parts = pair.split("=");
        if (parts[0] === output.name && Number(parts[1]) > 0)
            pxPerMm = output.geometry.width / Number(parts[1]);
    });
    return Math.round(settings.gapMm * pxPerMm);
}

function autoColumns(output) {
    return settings.vertical ? columnsFor(output) : 1;
}

function autoRows(output) {
    return settings.horizontal ? rowsFor(output) : 1;
}

// Split length into count parts with gaps around them; the last part gets
// any leftover pixels from rounding. Returns [{start, size}].
function split(start, length, count, gap) {
    var size = Math.floor((length - gap * (count + 1)) / count);
    var parts = [];
    for (var i = 0; i < count; i++) {
        var from = start + gap + i * (size + gap);
        parts.push({ start: from,
                     size: i < count - 1 ? size : start + length - gap - from });
    }
    return parts;
}

function cellBox(area, columns, rows, col, row, gap) {
    var xs = split(area.x, area.width, columns, gap)[col];
    var ys = split(area.y, area.height, rows, gap)[row];
    return { x: xs.start, y: ys.start, width: xs.size, height: ys.size };
}

// The column and row of the cell under the point x, y: {col, row}.
function cellAt(area, columns, rows, x, y) {
    var col = Math.floor((x - area.x) * columns / Math.max(area.width, 1));
    var row = Math.floor((y - area.y) * rows / Math.max(area.height, 1));
    return { col: Math.min(Math.max(col, 0), columns - 1),
             row: Math.min(Math.max(row, 0), rows - 1) };
}

function usableArea(output) {
    return rect(workspace.clientArea(KWin.MaximizeArea, output, workspace.currentDesktop));
}

function onCurrentDesktop(w) {
    return w.onAllDesktops || w.desktops.indexOf(workspace.currentDesktop) >= 0;
}

// Plasma's own windows, such as a widget's settings dialog, are left alone:
// opening one must not tile the other windows.
function tileable(w) {
    return w.normalWindow && !w.minimized && !w.skipTaskbar && !w.transient
        && w.resizeable && w.moveable && String(w.resourceClass) !== "plasmashell";
}

function place(w, box) {
    if (w.fullScreen)
        w.fullScreen = false;
    w.setMaximize(false, false);
    w.frameGeometry = { x: box.x, y: box.y, width: box.width, height: box.height };
}

// columns and rows are numbers or "auto" (the count for the screen size,
// or 1 for a direction that is turned off). Tiles the screen under the
// pointer unless output is given.
function tile(columns, rows, output) {
    loadSettings();
    if (settings.disabled)
        return;
    output = output || workspace.screenAt(workspace.cursorPos) || workspace.activeScreen;
    if (columns === "auto")
        columns = autoColumns(output);
    if (rows === "auto")
        rows = autoRows(output);
    layouts[output.name] = { columns: columns, rows: rows };

    // Most recently used windows on this screen and desktop fill the grid;
    // the others go into the cell under their middle, behind them.
    var windows = [];
    var background = [];
    var stack = workspace.stackingOrder;
    for (var i = stack.length - 1; i >= 0; i--) {
        var w = stack[i];
        if (tileable(w) && w.output === output && onCurrentDesktop(w))
            (windows.length < columns * rows ? windows : background).push(w);
    }
    function centerX(w) { return w.frameGeometry.x + w.frameGeometry.width / 2; }
    function centerY(w) { return w.frameGeometry.y + w.frameGeometry.height / 2; }
    // Keep their left-to-right order across columns and top-to-bottom order
    // within a column. Windows are spread evenly over the columns, so with
    // fewer windows than cells the first columns get the extra rows.
    windows.sort(function (a, b) { return centerX(a) - centerX(b); });
    var area = usableArea(output);
    var next = 0;
    for (var col = 0; col < columns; col++) {
        var count = Math.floor(windows.length / columns)
            + (col < windows.length % columns ? 1 : 0);
        var inColumn = windows.slice(next, next + count);
        next += count;
        inColumn.sort(function (a, b) { return centerY(a) - centerY(b); });
        inColumn.forEach(function (w, row) {
            tileInto(w, cellBox(area, columns, rows, col, row, gapFor(output)));
        });
    }
    // Moving a window does not raise it, so these stay in the background.
    background.forEach(function (w) {
        var cell = cellAt(area, columns, rows, centerX(w), centerY(w));
        tileInto(w, cellBox(area, columns, rows, cell.col, cell.row, gapFor(output)));
    });
}

function tileInto(w, box) {
    var id = windowId(w);
    // Keep the original position if the window stayed where an earlier
    // tiling put it.
    var current = rect(w.frameGeometry);
    var entry = saved[id];
    if (!entry || entry.moved || !near(entry.placed, current))
        entry = saved[id] = { geometry: current, moved: false };
    place(w, box);
    entry.placed = rect(box);
}

function restore() {
    workspace.windowList().forEach(function (w) {
        var entry = saved[windowId(w)];
        if (entry) {
            w.setMaximize(false, false);
            w.frameGeometry = entry.geometry;
        }
    });
    saved = {};
    layouts = {};
}

// KWin itself puts a window dropped with Shift held into a tile of its own
// layout (the one edited with Meta+T); scripts cannot read the keyboard, so
// that is how a Shift drop is recognised. Quick tiles from dragging to a
// screen edge belong to a different root and do not count.
function inCustomTile(w) {
    var root = workspace.tilingForScreen(w.output).rootTile;
    for (var tile = w.tile; tile; tile = tile.parent) {
        if (tile === root)
            return true;
    }
    return false;
}

// Columns and rows to snap into; swapped turns columns into rows and back.
function snapGrid(output, swapped) {
    var columns = autoColumns(output);
    var rows = autoRows(output);
    if (!swapped)
        return { columns: columns, rows: rows };
    if (settings.vertical && settings.horizontal)
        return { columns: rows, rows: columns };
    if (settings.vertical)
        return { columns: 1, rows: rowsFor(output) };
    return { columns: columnsFor(output), rows: 1 };
}

// Windows whose edge touches w's left or right edge, one gap apart and
// overlapping it vertically: {left: [{window, rect}], right: [...]}.
function neighbours(w) {
    var r = rect(w.frameGeometry);
    var slack = gapFor(w.output) + 8;
    var found = { left: [], right: [] };
    workspace.windowList().forEach(function (o) {
        if (o === w || !tileable(o) || o.output !== w.output || !onCurrentDesktop(o))
            return;
        var q = rect(o.frameGeometry);
        if (q.y >= r.y + r.height || q.y + q.height <= r.y)
            return;
        if (Math.abs(q.x - (r.x + r.width)) <= slack)
            found.right.push({ window: o, rect: q });
        else if (Math.abs(q.x + q.width - r.x) <= slack)
            found.left.push({ window: o, rect: q });
    });
    return found;
}

// Move the shared left or right edge of the windows beside a window that
// is being resized, keeping the gap between them.
function resizeNeighbours(w, resizing) {
    var minWidth = 50;
    var r = rect(w.frameGeometry);
    var s = resizing.start;
    var right = r.x + r.width;
    var startRight = s.x + s.width;
    function fit(n, x, width) {
        if (width < minWidth)
            return;
        n.window.setMaximize(false, false);
        n.window.frameGeometry = { x: x, y: n.rect.y, width: width, height: n.rect.height };
    }
    if (right !== startRight) {
        resizing.neighbours.right.forEach(function (n) {
            var x = right + (n.rect.x - startRight);
            fit(n, x, n.rect.x + n.rect.width - x);
        });
    }
    if (r.x !== s.x) {
        resizing.neighbours.left.forEach(function (n) {
            var end = r.x - (s.x - (n.rect.x + n.rect.width));
            fit(n, n.rect.x, end - n.rect.x);
        });
    }
}

function snapOnDrop(w) {
    var start = null;
    // Set while "resize neighbouring windows together" follows a resize.
    var resizing = null;
    // When this widget last snapped the window into place.
    var snappedAt = 0;
    var moving = false;
    w.interactiveMoveResizeStarted.connect(function () {
        start = rect(w.frameGeometry);
        moving = w.move;
        resizing = null;
        if (w.resize && settings.resizeNeighbours && !settings.disabled && tileable(w))
            resizing = { start: start, neighbours: neighbours(w) };
    });
    w.frameGeometryChanged.connect(function () {
        if (resizing && w.resize)
            resizeNeighbours(w, resizing);
    });
    w.interactiveMoveResizeFinished.connect(function () {
        if (resizing) {
            // The neighbours stay tiled: restore still knows where they were.
            resizing.neighbours.left.concat(resizing.neighbours.right).forEach(function (n) {
                var entry = saved[windowId(n.window)];
                if (entry)
                    entry.placed = rect(n.window.frameGeometry);
            });
            resizing = null;
        }
        if (saved[windowId(w)])
            saved[windowId(w)].moved = true;
        var end = rect(w.frameGeometry);
        var wasMove = moving || (start && start.width === end.width
                                       && start.height === end.height);
        start = null;
        moving = false;
        if (settings.disabled || !settings.snap || !wasMove || !tileable(w))
            return;
        // With both Shift options on, Shift snaps the other way and a
        // plain drop does not snap.
        var shift = inCustomTile(w);
        if (settings.snapShiftOnly && !shift)
            return;
        var swapped = shift && settings.snapShiftSwap;
        if (shift)
            w.tile = null;
        var pos = workspace.cursorPos;
        var output = workspace.screenAt(pos) || w.output;
        var area = usableArea(output);
        var grid = snapGrid(output, swapped);
        var cell = cellAt(area, grid.columns, grid.rows, pos.x, pos.y);
        place(w, cellBox(area, grid.columns, grid.rows, cell.col, cell.row, gapFor(output)));
        snappedAt = Date.now();
    });

    // KWin's quick tiling (screen edges, Meta+arrows) ignores the tile
    // padding: leave the gap around quick-tiled windows here.
    w.tileChanged.connect(function () {
        if (settings.disabled || !w.tile || inCustomTile(w))
            return;
        // A window this widget just snapped into place is left alone.
        if (Date.now() - snappedAt < 1000)
            return;
        var gap = gapFor(w.output);
        if (gap <= 0)
            return;
        var box = rect(w.tile.absoluteGeometry);
        var area = usableArea(w.output);
        // The full gap at the screen's edges, half of it on inner edges, so
        // that neighbouring windows are one gap apart.
        var half = Math.floor(gap / 2);
        var left = box.x <= area.x + 1 ? gap : gap - half;
        var top = box.y <= area.y + 1 ? gap : gap - half;
        var right = box.x + box.width >= area.x + area.width - 1 ? gap : half;
        var bottom = box.y + box.height >= area.y + area.height - 1 ? gap : half;
        w.frameGeometry = { x: box.x + left, y: box.y + top,
                            width: box.width - left - right,
                            height: box.height - top - bottom };
    });
}

// KWin's own tile layout (Meta+T, and Shift while dragging) uses its tile
// padding as the gap: keep it the same as this widget's gap.
function applyPadding() {
    workspace.screens.forEach(function (output) {
        var root = workspace.tilingForScreen(output).rootTile;
        var gap = gapFor(output);
        if (root && root.padding !== gap)
            root.padding = gap;
    });
}

loadSettings();
applyPadding();
options.configChanged.connect(function () {
    loadSettings();
    applyPadding();
});
workspace.screensChanged.connect(applyPadding);

workspace.windowList().forEach(snapOnDrop);
workspace.windowAdded.connect(snapOnDrop);
// Tile every new window with the others on its screen, if turned on, in
// the layout last used there (or the automatic one).
workspace.windowAdded.connect(function (w) {
    if (!settings.tileNew || settings.disabled || !tileable(w) || !onCurrentDesktop(w))
        return;
    var layout = layouts[w.output.name];
    if (layout)
        tile(layout.columns, layout.rows, w.output);
    else
        tile("auto", "auto", w.output);
});
workspace.windowRemoved.connect(function (w) {
    delete saved[windowId(w)];
});

registerShortcut("TileMenu Auto", "Window Tiling: tile automatically", "",
                 function () { tile("auto", "auto"); });
registerShortcut("TileMenu 4", "Window Tiling: tile in 4 columns", "",
                 function () { tile(4, "auto"); });
registerShortcut("TileMenu 3", "Window Tiling: tile in 3 columns", "",
                 function () { tile(3, "auto"); });
registerShortcut("TileMenu 2", "Window Tiling: tile in 2 columns", "",
                 function () { tile(2, "auto"); });
registerShortcut("TileMenu Rows 3", "Window Tiling: tile in 3 rows", "",
                 function () { tile("auto", 3); });
registerShortcut("TileMenu Rows 2", "Window Tiling: tile in 2 rows", "",
                 function () { tile("auto", 2); });
registerShortcut("TileMenu Grid 2x2", "Window Tiling: tile in a 2 x 2 grid", "",
                 function () { tile(2, 2); });
registerShortcut("TileMenu Grid 3x2", "Window Tiling: tile in a 3 x 2 grid", "",
                 function () { tile(3, 2); });
registerShortcut("TileMenu Grid 4x2", "Window Tiling: tile in a 4 x 2 grid", "",
                 function () { tile(4, 2); });
registerShortcut("TileMenu Restore", "Window Tiling: restore windows", "",
                 function () { restore(); });
