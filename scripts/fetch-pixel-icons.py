#!/usr/bin/env python3
"""
Build Pixels.js, the panel's pixel icons, from Pixelarticons (MIT,
https://pixelarticons.com) plus the two it lacks (AirPods and their case),
drawn here on the same grid in the same weight.

Pixelarticons are drawn on a 24-unit grid with two-unit strokes. Their SVGs
are outlines of rectangles, so each icon turns into an exact grid of pixels:
a cell is on when its centre is inside the shape. PixelIcon.qml draws the
grid as rectangles on whole device pixels, so the icons stay sharp at any
scale. Small sizes use the same grid halved (see `halve`). Run from the repo root:

    python3 scripts/fetch-pixel-icons.py
"""

import io
import json
import os
import re
import sys
import tarfile
import urllib.request

VERSION = "2.4.2"
TARBALL = "https://registry.npmjs.org/pixelarticons/-/pixelarticons-%s.tgz" % VERSION
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# The icons the panel draws, by the name Pixelarticons gives them.
ICONS = [
    "mouse", "keyboard", "headphone", "volume-2", "gamepad", "hand",
    "tablet", "pencil", "smartphone", "music", "tv", "power", "battery",
    "battery-low", "battery-medium", "battery-full", "zap", "plug", "reload", "settings-cog",
    "arrow-left", "key", "warning-diamond", "layout", "bell", "percent", "clock",
    "download", "check", "chevron-down",
]

# Drawn here on a 12-cell grid (each cell two units), in Pixelarticons'
# weight: one-cell lines, corners cut square.
CUSTOM = {
    # Pixelarticons' laptop is two rows short of the square its neighbours
    # fill, and sat low in the bar beside them. The same drawing, its screen
    # two rows taller.
    "laptop": [
        "............",
        "..#######...",
        ".#.......#..",
        ".#.......#..",
        ".#.......#..",
        ".#.......#..",
        ".#.......#..",
        ".#.......#..",
        ".#########..",
        "#.........#.",
        "###########.",
        "............",
    ],
    # Two buds in outline like the rest: round heads, stems down.
    "airpods": [
        "............",
        ".###....###.",
        "#...#..#...#",
        "#...#..#...#",
        ".##.#..#.##.",
        "..#.#..#.#..",
        "..#.#..#.#..",
        "..#.#..#.#..",
        "..#.#..#.#..",
        "..###..###..",
        "............",
        "............",
    ],
    # One bud alone, the pair's left one drawn a size up with its speaker
    # grille, so beside a figure it reads as a bud and not a 9. For a room of
    # its own (the AirPods card). The right is its mirror.
    "airpod-left": [
        "............",
        "...#####....",
        "..#.....#...",
        "..#.##..#...",
        "..#.....#...",
        "...####.#...",
        "......#.#...",
        "......#.#...",
        "......#.#...",
        "......#.#...",
        "......###...",
        "............",
    ],
    # The case: a rounded box, the lid's seam across it, the light under it.
    "airpods-case": [
        "............",
        "............",
        "..########..",
        ".#........#.",
        ".#........#.",
        ".##########.",
        ".#........#.",
        ".#...##...#.",
        ".#........#.",
        "..########..",
        "............",
        "............",
    ],
}
CUSTOM["airpod-right"] = [row[::-1] for row in CUSTOM["airpod-left"]]


# The parts of an icon that move on their own (Motion.js acts them out), as
# boxes on the 12-cell grid, (col0, row0, col1, row1) inclusive. "*" is the
# whole icon. A pixel in no part is the still base. The first part that
# claims a pixel keeps it.
PARTS = {
    "mouse": [("wheel", [(5, 3, 5, 4)])],
    "keyboard": [
        ("k2", [(4, 3, 4, 3)]), ("k3", [(6, 3, 6, 3)]), ("k5", [(3, 5, 3, 5)]), ("k7", [(7, 5, 7, 5)]),
        ("space", [(3, 7, 8, 7)]),
    ],
    "headphone": [("cupL", [(0, 6, 5, 9)]), ("cupR", [(6, 6, 11, 9)])],
    "volume-2": [("inner", [(7, 5, 7, 6)]), ("outer", [(7, 3, 9, 3), (9, 4, 9, 7), (7, 8, 9, 8)])],
    "gamepad": [("dpad", [(3, 4, 5, 6)]), ("btnA", [(7, 4, 7, 4)]), ("btnB", [(8, 6, 8, 6)])],
    "hand": [("hand", "*")],
    "tablet": [("home", [(5, 8, 5, 8)])],
    "pencil": [("pencil", "*")],
    "smartphone": [("phone", "*")],
    "music": [("notes", "*")],
    "power": [("stem", [(5, 1, 5, 4)])],
    "battery": [("nub", [(10, 4, 10, 6)])],
    "battery-low": [("c1", [(3, 4, 3, 6)])],
    "battery-medium": [("c1", [(3, 4, 3, 6)]), ("c2", [(5, 4, 5, 6)])],
    "battery-full": [("c1", [(3, 4, 3, 6)]), ("c2", [(5, 4, 5, 6)]), ("c3", [(7, 4, 7, 6)])],
    "zap": [("top", [(0, 0, 11, 3)]), ("mid", [(0, 4, 11, 6)]), ("bot", [(0, 7, 11, 11)])],
    "plug": [("head", [(0, 0, 11, 8)])],
    "settings-cog": [("hub", [(4, 4, 7, 7)])],
    "arrow-left": [("arrow", "*")],
    "key": [("teeth", [(5, 6, 9, 7)]), ("bow", "*")],
    "warning-diamond": [("mark", [(5, 3, 5, 5), (5, 7, 5, 7)])],
    "layout": [("bar", [(1, 4, 10, 4)])],
    "bell": [("skirt", [(0, 4, 11, 7)]), ("clapper", [(0, 9, 11, 10)])],
    "percent": [("o1", [(2, 2, 5, 5)]), ("o2", [(6, 6, 9, 9)])],
    "clock": [("hand", [(5, 3, 5, 5)])],
    "download": [("arrow", [(3, 1, 7, 6)])],
    "check": [("short", [(2, 6, 4, 8)]), ("long", [(5, 3, 9, 7)])],
    "airpods": [("budL", [(0, 0, 5, 11)]), ("budR", [(6, 0, 11, 11)])],
    "airpods-case": [("lid", [(0, 0, 11, 4)]), ("light", [(5, 7, 6, 7)])],
    "airpod-left": [("bud", "*")],
    "airpod-right": [("bud", "*")],
}

# Pixels an icon shows only while it acts: 12-cell drawings, or rectangles
# on the 24-unit grid where a cell's odd unit would sit off centre.
EXTRAS = {
    "laptop": [
        ("prompt", [
            "............",
            "............",
            "............",
            "...#........",
            "....#.......",
            "...#........",
        ]),
        ("cursor", [
            "............",
            "............",
            "............",
            "............",
            "............",
            ".....##.....",
        ]),
    ],
    "tablet": [("swipe", [
        "............",
        "............",
        "............",
        "..#.........",
        "..#.........",
        "..#.........",
        "..#.........",
    ])],
    "tv": [("scan", [
        "............",
        "............",
        "............",
        "..########..",
    ])],
    "pencil": [
        ("ink1", ["", "", "", "", "", "", "", "", "", "", "", ".#.........."]),
        ("ink2", ["", "", "", "", "", "", "", "", "", "", "", "..#........."]),
    ],
    "clock": [
        ("right", ["", "", "", "", "", ".....####..."]),
        ("down", ["", "", "", "", "", ".....#......", ".....#......", ".....#......", ".....#......"]),
        ("left", ["", "", "", "", "", "..####......"]),
    ],
    # The hub pressed in: its hole filled.
    "settings-cog": [("pressed", [[10, 10, 4, 4]])],
}


def polygons(d):
    """Rectilinear subpaths of an SVG path (M, H, V, L, h, v, l, m, Z)."""
    tokens = re.findall(r"[MmHhVvLlZz]|-?\d*\.?\d+", d)
    polys, cur, x, y, cmd, i = [], [], 0.0, 0.0, None, 0
    while i < len(tokens):
        t = tokens[i]
        if re.match(r"[A-Za-z]", t):
            cmd = t
            i += 1
            if cmd in "Zz":
                if cur:
                    polys.append(cur)
                    x, y = cur[0]
                cur = []
            continue
        if cmd in "Mm":
            nx, ny = float(tokens[i]), float(tokens[i + 1])
            i += 2
            if cmd == "m":
                nx, ny = x + nx, y + ny
            if cur:
                polys.append(cur)
            cur = [(nx, ny)]
            x, y = nx, ny
            cmd = "l" if cmd == "m" else "L"
        elif cmd in "Ll":
            nx, ny = float(tokens[i]), float(tokens[i + 1])
            i += 2
            if cmd == "l":
                nx, ny = x + nx, y + ny
            x, y = nx, ny
            cur.append((x, y))
        elif cmd in "Hh":
            v = float(tokens[i]); i += 1
            x = x + v if cmd == "h" else v
            cur.append((x, y))
        elif cmd in "Vv":
            v = float(tokens[i]); i += 1
            y = y + v if cmd == "v" else v
            cur.append((x, y))
        else:
            raise SystemExit("unsupported path command %r" % cmd)
    if cur:
        polys.append(cur)
    return polys


def raster(svg):
    """The 24x24 grid of an icon: rows of booleans, nonzero winding."""
    edges = []
    for d in re.findall(r'<path[^>]*\sd="([^"]+)"', svg):
        for poly in polygons(d):
            for (x0, y0), (x1, y1) in zip(poly, poly[1:] + poly[:1]):
                if x0 == x1 and y0 != y1:
                    edges.append((x0, y0, y1))
    for m in re.finditer(r'<rect[^>]*>', svg):
        a = dict(re.findall(r'(\w+)="([^"]+)"', m.group(0)))
        x, y, w, h = (float(a.get(k, 0)) for k in ("x", "y", "width", "height"))
        edges += [(x, y + h, y), (x + w, y, y + h)]
    if re.search(r"<(circle|ellipse|polygon|polyline|line)\b", svg):
        raise SystemExit("expected only paths and rects")
    grid = []
    for row in range(24):
        cy = row + 0.5
        line = []
        for col in range(24):
            cx = col + 0.5
            wind = 0
            for x, y0, y1 in edges:
                if x > cx and min(y0, y1) < cy < max(y0, y1):
                    wind += 1 if y1 > y0 else -1
            line.append(wind != 0)
        grid.append(line)
    return grid


def from_art(art):
    """A 12-cell drawing at 24 units: each cell two by two."""
    return [[art[r // 2][c // 2] == "#" for c in range(24)] for r in range(24)]


def from_cells(art):
    """A 12-cell drawing at 24 units, each cell on the odd unit `halve`
    samples, so it lines up with the strokes of a Pixelarticon."""
    grid = [[False] * 24 for _ in range(24)]
    for r, row in enumerate(art):
        for c, ch in enumerate(row):
            if ch == "#":
                for y in (2 * r + 1, 2 * r + 2):
                    for x in (2 * c + 1, 2 * c + 2):
                        if y < 24 and x < 24:
                            grid[y][x] = True
    return grid


def in_boxes(c, r, boxes):
    return boxes == "*" or any(c0 <= c <= c1 and r0 <= r <= r1 for c0, r0, c1, r1 in boxes)


def split(grid, parts):
    """The still base and each moving part of a 24-unit icon, at 24 and 12.
    Parts are drawn on the 12 grid; a 24-unit pixel goes with a cell its
    stroke covers, a moving one first, so a moving stroke keeps its weight."""
    small = halve(grid)
    owner = [[None] * 12 for _ in range(12)]
    for r in range(12):
        for c in range(12):
            if small[r][c]:
                for pid, boxes in parts:
                    if in_boxes(c, r, boxes):
                        owner[r][c] = pid
                        break
    ids = [pid for pid, _ in parts]
    big = {pid: [[False] * 24 for _ in range(24)] for pid in [None] + ids}
    for y in range(24):
        for x in range(24):
            if not grid[y][x]:
                continue
            cx = [(x - 1) // 2] if x % 2 else [x // 2 - 1, x // 2]
            cy = [(y - 1) // 2] if y % 2 else [y // 2 - 1, y // 2]
            found = [owner[r][c] for r in cy for c in cx if 0 <= r < 12 and 0 <= c < 12 and small[r][c]]
            moving = [o for o in found if o is not None]
            big[moving[0] if moving else None][y][x] = True
    out = {}
    for pid in [None] + ids:
        cells = [[small[r][c] and owner[r][c] == pid for c in range(12)] for r in range(12)]
        out[pid] = (big[pid], cells)
    return out


def halve(grid):
    # Every stroke is two units wide, so it covers exactly one odd unit:
    # sampling those keeps each stroke one cell wide, wherever it starts.
    return [[grid[r * 2 + 1][c * 2 + 1] for c in range(12)] for r in range(12)]


def rects(grid):
    """Runs along each row, merged down where the next rows repeat them."""
    n = len(grid)
    runs = []
    for r, line in enumerate(grid):
        c = 0
        while c < n:
            if line[c]:
                s = c
                while c < n and line[c]:
                    c += 1
                runs.append([s, r, c - s, 1])
            else:
                c += 1
    merged = []
    for run in runs:
        for m in merged:
            if m[0] == run[0] and m[2] == run[2] and m[1] + m[3] == run[1]:
                m[3] += 1
                break
        else:
            merged.append(list(run))
    return merged


def show(grid):
    return "\n".join("".join("#" if v else "." for v in line) for line in grid)


def svgs():
    """Each icon's SVG: the copies in pixels/, or Pixelarticons' package
    (with --fetch, or when a copy is missing), saved there."""
    local = {}
    for name in ICONS:
        path = os.path.join(ROOT, "pixels", name + ".svg")
        if os.path.exists(path):
            with open(path) as f:
                local[name] = f.read()
    if len(local) == len(ICONS) and "--fetch" not in sys.argv:
        return local
    with urllib.request.urlopen(TARBALL, timeout=30) as r:
        pack = tarfile.open(fileobj=io.BytesIO(r.read()))
    out = {}
    for name in ICONS:
        out[name] = pack.extractfile("package/svg/%s.svg" % name).read().decode()
        with open(os.path.join(ROOT, "pixels", name + ".svg"), "w") as f:
            f.write(out[name])
    return out


def main():
    source = svgs()
    out = {}
    for name in ICONS:
        out[name] = raster(source[name])
    for name, art in CUSTOM.items():
        out[name] = from_art(art)
    if "--show" in sys.argv:
        for name, grid in out.items():
            print(name)
            print(show(grid))
            print(show(halve(grid)))
            print()
        return
    lines = [
        ".pragma library",
        "",
        "// Generated by scripts/fetch-pixel-icons.py from Pixelarticons %s (MIT," % VERSION,
        "// https://pixelarticons.com), plus the AirPods and their case drawn there",
        "// on the same grid. Each icon is [x, y, width, height] rectangles: `g24` on",
        "// the 24-unit grid, `g12` on the same grid halved for small sizes. Those",
        "// are the parts that hold still; `parts` are the ones Motion.js moves, and",
        "// an `extra` part shows only while the icon acts.",
        "",
        "var icons = {",
    ]
    for name, grid in out.items():
        pieces = split(grid, PARTS.get(name, []))
        base24, base12 = pieces.pop(None)
        parts = []
        for pid, (g24, g12) in pieces.items():
            parts.append({"id": pid, "g24": rects(g24), "g12": rects(g12)})
        for pid, art in EXTRAS.get(name, []):
            if isinstance(art[0], list):
                g24 = [[False] * 24 for _ in range(24)]
                for x, y, w, h in art:
                    for yy in range(y, y + h):
                        for xx in range(x, x + w):
                            g24[yy][xx] = True
            elif name in CUSTOM:
                g24 = from_art(art + ["." * 12] * (12 - len(art)))
            else:
                g24 = from_cells(art)
            parts.append({"id": pid, "extra": True, "g24": rects(g24), "g12": rects(halve(g24))})
        entry = "  %s: { g24: %s, g12: %s" % (json.dumps(name), json.dumps(rects(base24)), json.dumps(rects(base12)))
        if parts:
            entry += ", parts: %s" % json.dumps(parts)
        lines.append(entry + " },")
    lines[-1] = lines[-1].rstrip(",")
    lines += ["}", ""]
    with open(os.path.join(ROOT, "Pixels.js"), "w") as f:
        f.write("\n".join(lines))
    print("wrote Pixels.js with %d icons" % len(out))


if __name__ == "__main__":
    main()
