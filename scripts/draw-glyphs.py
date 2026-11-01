#!/usr/bin/env python3
"""
Draw the panel's device glyphs and write Glyphs.js.

The panel shows devices the way it shows AirPods: one solid silhouette with
fine details cut out of it. Each glyph is built here from plain shapes on a
48-unit grid and filled even-odd, so a shape inside another cuts it and a
shape inside a cut fills again (a key on a keyboard, a wheel in its slot).
Shapes must never overlap, or the overlap flips. Run from the repo root:

    python3 scripts/draw-glyphs.py
"""

import json
import os
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def n(v):
    return ("%.3f" % v).rstrip("0").rstrip(".")


def rrect(x, y, w, h, r):
    r = min(r, w / 2, h / 2)
    return ("M%s %sH%sA%s %s 0 0 1 %s %sV%sA%s %s 0 0 1 %s %sH%sA%s %s 0 0 1 %s %sV%sA%s %s 0 0 1 %s %sZ" % (
        n(x + r), n(y), n(x + w - r), n(r), n(r), n(x + w), n(y + r), n(y + h - r), n(r), n(r), n(x + w - r), n(y + h),
        n(x + r), n(r), n(r), n(x), n(y + h - r), n(y + r), n(r), n(r), n(x + r), n(y)))


def circle(cx, cy, r):
    return "M%s %sA%s %s 0 1 1 %s %sA%s %s 0 1 1 %s %sZ" % (
        n(cx - r), n(cy), n(r), n(r), n(cx + r), n(cy), n(r), n(r), n(cx - r), n(cy))


def plus(cx, cy, arm, w):
    a, h = arm, w / 2
    pts = [(-h, -a), (h, -a), (h, -h), (a, -h), (a, h), (h, h), (h, a), (-h, a), (-h, h), (-a, h), (-a, -h), (-h, -h)]
    return "M" + "L".join("%s %s" % (n(cx + x), n(cy + y)) for x, y in pts) + "Z"


def laptop():
    # An open laptop from the front: the lid with a thin bezel, a camera in
    # it and a deeper chin, a hinge gap, then the wider base with its notch.
    return [
        rrect(6, 6, 36, 23.5, 2.2),
        rrect(7.7, 7.7, 32.6, 19.0, 0.8),
        circle(24, 6.85, 0.45),
        "M2 30.3H46V31.6C46 32.6 45.2 33.4 44.2 33.4H3.8C2.8 33.4 2 32.6 2 31.6Z",
        "M19.5 30.3H28.5V30.55A0.85 0.85 0 0 1 27.65 31.4H20.35A0.85 0.85 0 0 1 19.5 30.55Z",
    ]


def mouse():
    # A gaming mouse from above: the buttons split down the middle, the
    # wheel in its slot, the seam where the buttons meet the palm, and two
    # side buttons.
    return [
        "M24 3C31 3 36 7 36.5 15L37 30C37 39 31.5 45 24 45C16.5 45 11 39 11 30L11.5 15C12 7 17 3 24 3Z",
        rrect(23.55, 3.4, 0.9, 3.5, 0.45),
        rrect(21.9, 7.2, 4.2, 9.2, 2.1),
        rrect(23.05, 8.4, 1.9, 6.8, 0.95),
        rrect(23.55, 16.7, 0.9, 3.4, 0.45),
        "M12.4 18.9Q24 23.5 35.6 18.9L35.6 19.9Q24 24.5 12.4 19.9Z",
        rrect(12.5, 22.6, 0.9, 3.6, 0.45),
        rrect(12.6, 27.0, 0.9, 3.6, 0.45),
    ]


def keyboard():
    # A compact keyboard from above: a frame, then every key, with a long
    # space bar on the bottom row.
    out = [rrect(2, 12.5, 44, 23, 2.6), rrect(3.3, 13.8, 41.4, 20.4, 1.4)]
    pitch, kw, kh, top = 4.1, 3.3, 3.0, 14.6
    left = 3.3 + (41.4 - (9 * pitch + kw)) / 2
    for row in range(5):
        y = top + row * 3.85
        if row < 4:
            for col in range(10):
                out.append(rrect(left + col * pitch, y, kw, kh, 0.6))
        else:
            for col in (0, 1, 2, 7, 8, 9):
                out.append(rrect(left + col * pitch, y, kw, kh, 0.6))
            out.append(rrect(left + 3 * pitch, y, 3 * pitch + kw, kh, 0.6))
    return out


def speaker():
    # A speaker from the front: the cabinet, a tweeter, and a woofer with its
    # surround and dust cap, each ring cut and filled in turn.
    return [
        rrect(11, 3, 26, 42, 5),
        circle(24, 12.6, 4.3), circle(24, 12.6, 3.1), circle(24, 12.6, 1.05),
        circle(24, 30.4, 9.7), circle(24, 30.4, 8.3), circle(24, 30.4, 4.5), circle(24, 30.4, 3.4),
    ]


def phone():
    # A phone from the front: a thin bezel, the camera pill in the screen,
    # buttons on both sides.
    return [
        rrect(13, 2, 22, 44, 4.6),
        rrect(14.9, 3.9, 18.2, 40.2, 2.9),
        rrect(20.6, 5.6, 6.8, 2, 1),
        rrect(11.8, 10, 0.9, 3, 0.45),
        rrect(11.8, 14.5, 0.9, 5, 0.45),
        rrect(35.3, 13, 0.9, 7, 0.45),
    ]


def tablet():
    return [
        rrect(6.5, 2.5, 35, 43, 3.6),
        rrect(8.6, 4.6, 30.8, 38.8, 1.8),
        circle(24, 3.55, 0.5),
        rrect(42.8, 6, 0.9, 4, 0.45),
    ]


def airpods_case():
    # A charging case: the lid over the body with a thin seam between them,
    # and the status light.
    return [
        "M14 9H34A10 10 0 0 1 43.982 18.4H4.018A10 10 0 0 1 14 9Z",
        "M4 19.4H44V29A10 10 0 0 1 34 39H14A10 10 0 0 1 4 29Z",
        circle(24, 25.2, 0.95),
    ]


def headphones():
    # Over-ear headphones: the band with a groove along it, hinges, then the
    # cups with the cushion line on their inner side.
    return [
        "M8.5 26A15.5 15.5 0 0 1 39.5 26H36.9A12.9 12.9 0 0 0 11.1 26Z",
        "M10.98 18.6A14.6 14.6 0 0 1 37.02 18.6L36.32 18.95A13.8 13.8 0 0 0 11.68 18.95Z",
        rrect(6.5, 26.8, 8.6, 16.2, 4),
        rrect(12.3, 29.2, 0.8, 11.4, 0.4),
        rrect(32.9, 26.8, 8.6, 16.2, 4),
        rrect(34.9, 29.2, 0.8, 11.4, 0.4),
    ]


def gamepad():
    # A controller: the d-pad, four face buttons, two sticks in their rings
    # and the two small buttons between.
    return [
        "M14 13H34C40 13 44 17 45 23L46.5 33C47.2 38 43 41 39.5 37.5L35.5 33.5H12.5L8.5 37.5C5 41 0.8 38 1.5 33L3 23C4 17 8 13 14 13Z",
        plus(12.5, 21.5, 3.6, 2.2),
        circle(35.5, 18.4, 1.15), circle(35.5, 24.6, 1.15), circle(32.4, 21.5, 1.15), circle(38.6, 21.5, 1.15),
        circle(18.5, 27.6, 2.8), circle(18.5, 27.6, 1.8),
        circle(29.5, 27.6, 2.8), circle(29.5, 27.6, 1.8),
        rrect(20.4, 18.6, 2.6, 1.1, 0.55), rrect(25, 18.6, 2.6, 1.1, 0.55),
    ]


# Arcs only list their end points, so a glyph whose outline bulges past
# them names its extent here.
INK = {
    "headphones": [6.5, 10.5, 41.5, 43],
}

GLYPHS = {
    "laptop": laptop,
    "mouse": mouse,
    "keyboard": keyboard,
    "speaker": speaker,
    "phone": phone,
    "tablet": tablet,
    "airpods-case": airpods_case,
    "headphones": headphones,
    "gamepad": gamepad,
}


def bounds(path):
    xs, ys = [], []
    for cmd in re.finditer(r"([MLHVCQAZ])([^MLHVCQAZ]*)", path):
        c, args = cmd.group(1), [float(v) for v in re.findall(r"-?\d*\.?\d+", cmd.group(2))]
        if c in "ML":
            xs += args[0::2]; ys += args[1::2]
        elif c == "H":
            xs += args
        elif c == "V":
            ys += args
        elif c in "CQ":
            xs += args[0::2]; ys += args[1::2]
        elif c == "A":
            xs.append(args[5]); ys.append(args[6])
    return xs, ys


def main():
    glyphs = {}
    for name, draw in GLYPHS.items():
        parts = draw()
        path = " ".join(parts)
        # The points each part moves or draws to, control points included:
        # close enough to the drawn extent for these shapes.
        xs, ys = bounds(path)
        ink = INK.get(name) or [min(xs), min(ys), max(xs), max(ys)]
        glyphs[name] = {"ink": [round(v, 3) for v in ink], "path": path}

    lines = [
        ".pragma library",
        "",
        "// Generated by scripts/draw-glyphs.py: the panel's device glyphs, solid",
        "// with details cut out, on a 48-unit grid. Fill them odd-even. `ink` is",
        "// each drawing's extent as [left, top, right, bottom].",
        "",
        "var glyphs = {",
    ]
    lines += ["  %s: %s," % (json.dumps(k), json.dumps(v)) for k, v in glyphs.items()]
    lines[-1] = lines[-1].rstrip(",")
    lines += ["}", ""]
    with open(os.path.join(ROOT, "Glyphs.js"), "w") as f:
        f.write("\n".join(lines))

    # A preview sheet, for drawing new glyphs.
    cells = []
    for name, g in glyphs.items():
        x0, y0, x1, y1 = g["ink"]
        cells.append('<figure><svg viewBox="%s %s %s %s"><path fill-rule="evenodd" d="%s"/></svg><figcaption>%s</figcaption></figure>' % (
            n(x0), n(y0), n(x1 - x0), n(y1 - y0), g["path"], name))
    with open("/tmp/glyphs-preview.html", "w") as f:
        f.write("".join(cells))
    print("wrote Glyphs.js with %d glyphs" % len(glyphs))


if __name__ == "__main__":
    main()
