#!/usr/bin/env python3
"""Writes the three hand-made map layouts into data/maps/*.json.

The layouts are designed here as explicit shapes (rivers, ridges, rings),
not random noise, and every shape is painted together with its rotated images
so the starts are always identical. Re-run after editing:

    python3 tools/make_layouts.py

Legend (one character per 2x2-unit cell):
  . ground   f forest   r rock   w water
  1-4 player starts (the cell whose top-left corner is the HQ centre)
  s salvage field   S rich salvage field   u uplink site
"""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "maps")


class Grid:
    def __init__(self, n, order):
        self.n = n
        self.order = order  # 2 = half-turn symmetry, 4 = quarter turns
        self.cells = [["." for _ in range(n)] for _ in range(n)]

    def images(self, x, y):
        n = self.n
        if self.order == 4:
            out = [(x, y)]
            for _ in range(3):
                x, y = n - 1 - y, x
                out.append((x, y))
            return out
        return [(x, y), (n - 1 - x, n - 1 - y)]

    def put(self, x, y, ch):
        for ix, iy in self.images(x, y):
            if 0 <= ix < self.n and 0 <= iy < self.n:
                self.cells[iy][ix] = ch

    def paint(self, test, ch):
        """Paints every cell (and its images) for which test(x, y) is true."""
        for y in range(self.n):
            for x in range(self.n):
                if test(x, y):
                    self.put(x, y, ch)

    def clear_disc(self, cx, cy, r):
        for y in range(self.n):
            for x in range(self.n):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                    self.put(x, y, ".")

    def disc(self, cx, cy, r, ch):
        self.paint(lambda x, y: (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r, ch)

    def feature(self, x, y, ch, clear=3):
        """A field or uplink on a cell, with open ground around it."""
        for ix, iy in self.images(x, y):
            self.clear_only(ix + 0.5, iy + 0.5, clear)
        self.put(x, y, ch)

    def clear_only(self, cx, cy, r):
        for y in range(self.n):
            for x in range(self.n):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                    self.cells[y][x] = "."

    def starts(self, marks):
        """marks: list of (number, cell x, cell y). The HQ centre is the
        top-left corner of the marked cell. Call before placing features:
        it clears the ground around every start."""
        for _, x, y in marks:
            self.clear_only(x, y, 11.5)
        for num, x, y in marks:
            self.cells[y][x] = str(num)

    def rows(self):
        return ["".join(r) for r in self.cells]


def speckle(x, y, keep, mod=7):
    """Deterministic sparse pattern so forests are not solid blocks."""
    return (x * 13 + y * 29 + (x * y) % 11) % mod < keep


def twin_fords():
    n = 64
    g = Grid(n, 2)
    # A river down the anti-diagonal between the two bases, with three fords.
    g.paint(lambda x, y: abs(x + y - (n - 1)) <= 1, "w")
    g.paint(lambda x, y: 3 <= abs(x + y - (n - 1)) <= 5 and speckle(x, y, 5), "f")
    for d in (0, 30, -30):
        g.paint(lambda x, y, d=d: abs(x + y - (n - 1)) <= 6 and abs((x - y) - d) <= 2, ".")
    # Rock outcrops that turn the approaches to the outer fords into lanes.
    g.disc(34, 16, 3.2, "r")
    g.disc(16, 34, 3.2, "r")
    g.disc(27, 27, 2.4, "r")
    # Woods on each bank for infantry to hold.
    g.paint(lambda x, y: (x - 40) ** 2 + (y - 8) ** 2 <= 20 and speckle(x, y, 5), "f")
    g.paint(lambda x, y: (x - 8) ** 2 + (y - 40) ** 2 <= 20 and speckle(x, y, 5), "f")
    g.starts([(1, 13, 13), (2, 51, 51)])
    g.feature(22, 10, "s")
    g.feature(10, 22, "s")
    g.feature(36, 6, "s")
    g.feature(26, 33, "S")
    g.feature(46, 12, "u")
    return {
        "name": "Twin Fords",
        "players": 2,
        "desc": "A river splits the map. Three fords are the only ways across.",
        "rows": g.rows(),
    }


def crater_ring():
    n = 64
    g = Grid(n, 2)
    c = n / 2.0
    # A ring of rock around the middle with four gaps on the diagonals.
    def ring(x, y):
        d = math.hypot(x + 0.5 - c, y + 0.5 - c)
        if not (10.0 <= d <= 12.5):
            return False
        ang = math.degrees(math.atan2(y + 0.5 - c, x + 0.5 - c)) % 90.0
        return abs(ang - 45.0) > 13.0
    g.paint(ring, "r")
    # Ponds in the two empty corners, woods between the bases and the ring.
    g.disc(54, 9, 4.2, "w")
    g.paint(lambda x, y: (x - 30) ** 2 + (y - 12) ** 2 <= 18 and speckle(x, y, 5), "f")
    g.paint(lambda x, y: (x - 12) ** 2 + (y - 30) ** 2 <= 18 and speckle(x, y, 5), "f")
    g.paint(lambda x, y: 14.5 <= math.hypot(x + 0.5 - c, y + 0.5 - c) <= 16.5 and speckle(x, y, 3), "f")
    g.starts([(1, 13, 13), (2, 51, 51)])
    g.feature(23, 9, "s")
    g.feature(9, 23, "s")
    g.feature(38, 14, "s")
    g.feature(29, 29, "S")
    g.feature(48, 20, "u")
    return {
        "name": "Crater Ring",
        "players": 2,
        "desc": "Rich salvage sits inside a rock ring with four narrow gates.",
        "rows": g.rows(),
    }


def crossroads():
    n = 96
    g = Grid(n, 4)
    c = n / 2.0
    # Ridges along both centre lines cut the map into four quarters...
    g.paint(lambda x, y: abs(x + 0.5 - c) <= 1.5 and y < c, "r")
    # ...with a plaza in the middle and a pass half-way along each ridge.
    g.clear_disc(c, c, 9.5)
    g.paint(lambda x, y: abs(x + 0.5 - c) <= 2.5 and 18 <= y <= 24, ".")
    # Woods and a pond in every quarter.
    g.paint(lambda x, y: (x - 30) ** 2 + (y - 30) ** 2 <= 30 and speckle(x, y, 5), "f")
    g.paint(lambda x, y: (x - 38) ** 2 + (y - 10) ** 2 <= 14 and speckle(x, y, 5), "f")
    g.disc(10, 36, 3.4, "w")
    g.disc(36, 40, 2.6, "r")
    g.starts([(1, 13, 13), (2, 83, 83), (3, 83, 13), (4, 13, 83)])
    g.feature(23, 9, "s")
    g.feature(9, 23, "s")
    g.feature(36, 22, "s")
    g.feature(44, 43, "S")
    g.feature(43, 30, "u")
    return {
        "name": "Crossroads",
        "players": 4,
        "desc": "Four quarters divided by ridges. The plaza in the middle holds the richest salvage.",
        "rows": g.rows(),
    }


def main():
    os.makedirs(OUT, exist_ok=True)
    for key, layout in (("twin_fords", twin_fords()), ("crater_ring", crater_ring()), ("crossroads", crossroads())):
        path = os.path.join(OUT, key + ".json")
        with open(path, "w", newline="\n") as f:
            json.dump(layout, f, indent="\t")
            f.write("\n")
        print("wrote", os.path.relpath(path, ROOT), "%dx%d" % (len(layout["rows"][0]), len(layout["rows"])))


if __name__ == "__main__":
    main()
