"""The café shell: floating grass island, plank floor, walls with windows and a door.

World layout (metres): floor x in [-3.0, 3.0], z in [-4.2, 2.6], floor top at y=0.
Back wall at z=-4.2, side walls at x=+-3.0, open front for the camera.
The door is in the right wall between z=1.45 and z=2.45.
"""

import math
import random

from forge.scene import Node

FX, FZ0, FZ1 = 3.0, -4.2, 2.6
WALL_H = 2.4
T = 0.2  # wall thickness
DOOR_Z = (1.45, 2.45)
DOOR_H = 1.75
WIN_Y = (1.0, 1.95)


def _island(n):
    n.rbox("grass", (0, -0.17, -0.3), (10.6, 0.28, 11.6), 0.12)
    n.rbox("dirt", (0, -0.58, -0.3), (10.3, 0.6, 11.3), 0.22)
    n.rbox("dirt_dark", (0, -1.02, -0.3), (9.0, 0.5, 10.0), 0.25)
    for x, z, s in ((3.55, 1.95, 1.0), (4.1, 1.7, 0.85), (4.65, 2.05, 0.95), (5.2, 1.8, 0.8)):
        n.ell("stone", (x, -0.03, z), (0.22 * s, 0.04, 0.17 * s), rot=(0, x * 40, 0), seg=14, rings=6)
    for x, z in ((-4.6, -5.2), (4.7, -5.3), (-4.8, 4.6), (4.8, 4.8)):
        n.sphere("grass_dark", (x, -0.02, z), 0.3, s=(1, 0.35, 1), seg=12, rings=6)


def _floor(n):
    rnd = random.Random(7)
    n.rbox("wood_dark", (0, -0.07, (FZ0 + FZ1) / 2), (2 * FX + 0.1, 0.1, FZ1 - FZ0 + 0.1), 0.03)
    tile_end = -2.7
    # kitchen tiles
    x = -FX
    i = 0
    while x < FX - 1e-6:
        z = FZ0
        j = 0
        while z < tile_end - 1e-6:
            mat = "white" if (i + j) % 2 == 0 else "mint_light"
            n.box(mat, (x + 0.25, -0.03, z + 0.25), (0.49, 0.06, 0.49))
            z += 0.5
            j += 1
        x += 0.5
        i += 1
    # planks, running front to back with staggered joints
    x = -FX
    while x < FX - 1e-6:
        z = tile_end
        while z < FZ1 - 1e-6:
            L = min(rnd.uniform(1.4, 2.8), FZ1 - z)
            if FZ1 - (z + L) < 0.5:
                L = FZ1 - z
            mat = rnd.choice(("wood", "wood", "wood_mid", "wood_light"))
            n.box(mat, (x + 0.25, -0.03, z + L / 2), (0.49, 0.06, L - 0.012))
            z += L
        x += 0.5
    n.rbox("wood_dark", (0, -0.03, FZ1 + 0.06), (2 * FX + 0.2, 0.08, 0.14), 0.03)
    # door mat
    n.rbox("tomato", (FX - 0.4, 0.004, sum(DOOR_Z) / 2), (0.55, 0.02, 0.95), 0.01)
    n.rbox("butter", (FX - 0.4, 0.008, sum(DOOR_Z) / 2), (0.4, 0.02, 0.8), 0.01)


def _panel(n, mat, axis, fixed, a0, a1, y0, y1, depth=T):
    """Axis-aligned wall slab. axis='z' -> runs along x at z=fixed; axis='x' -> runs along z at x=fixed."""
    if a1 - a0 < 1e-4 or y1 - y0 < 1e-4:
        return
    c_run = (a0 + a1) / 2
    cy = (y0 + y1) / 2
    if axis == "z":
        n.rbox(mat, (c_run, cy, fixed), (a1 - a0, y1 - y0, depth), 0.02, steps=1)
    else:
        n.rbox(mat, (fixed, cy, c_run), (depth, y1 - y0, a1 - a0), 0.02, steps=1)


def _wall(n, axis, fixed, inner_sign, run0, run1, openings):
    """Build one wall with rectangular openings [(a0, a1, y0, y1)] and its inner dressing."""
    cuts = sorted(openings)
    # full-height columns between openings, plus pieces above/below each opening
    cursor = run0
    for a0, a1, y0, y1 in cuts:
        _panel(n, "peach", axis, fixed, cursor, a0, 0, WALL_H)
        _panel(n, "peach", axis, fixed, a0, a1, 0, y0)
        _panel(n, "peach", axis, fixed, a0, a1, y1, WALL_H)
        cursor = a1
    _panel(n, "peach", axis, fixed, cursor, run1, 0, WALL_H)

    face = fixed + inner_sign * (T / 2)

    def strip(mat, a0, a1, y0, y1, depth, out=0.0):
        pos = face + inner_sign * (depth / 2 + out)
        _panel(n, mat, axis, pos, a0, a1, y0, y1, depth)

    def spans(y0, y1, lo=run0, hi=run1):
        """Parts of [lo, hi] not blocked by an opening overlapping the band y0..y1."""
        out, cur = [], lo
        for a0, a1, oy0, oy1 in cuts:
            if oy0 < y1 and oy1 > y0:
                if a0 > cur:
                    out.append((cur, a0))
                cur = max(cur, a1)
        if hi > cur:
            out.append((cur, hi))
        return out

    for a0, a1 in spans(0.0, 0.95):
        strip("cream", a0, a1, 0.1, 0.9, 0.02)
        strip("wood_dark", a0, a1, 0.0, 0.12, 0.04)
        strip("wood", a0, a1, 0.9, 0.97, 0.05)
    # wallpaper stripes on the upper wall
    s = run0 + 0.18
    while s < run1 - 0.1:
        for a0, a1 in spans(0.99, 2.28, s, s + 0.14):
            strip("peach_light", a0, a1, 0.99, 2.28, 0.01)
        s += 0.42
    strip("wood", run0, run1, 2.28, 2.4, 0.06)
    # opening frames
    for a0, a1, y0, y1 in cuts:
        is_door = y0 < 0.01
        frame = "wood_dark" if is_door else "white"
        strip(frame, a0 - 0.07, a0, y0, y1 + 0.07, 0.06)
        strip(frame, a1, a1 + 0.07, y0, y1 + 0.07, 0.06)
        strip(frame, a0 - 0.07, a1 + 0.07, y1, y1 + 0.07, 0.06)
        if not is_door:
            strip("white", a0 - 0.1, a1 + 0.1, y0 - 0.05, y0 + 0.01, 0.16)
            _panel(n, "sky_light", axis, fixed, a0, a1, y0, y1, 0.04)
            mid = (a0 + a1) / 2
            _panel(n, "white", axis, fixed + inner_sign * 0.03, mid - 0.025, mid + 0.025, y0, y1, 0.03)
            _panel(n, "white", axis, fixed + inner_sign * 0.03, a0, a1, (y0 + y1) / 2 - 0.025, (y0 + y1) / 2 + 0.025, 0.03)
            # a soft cloud painted on the glass
            cx = a0 + (a1 - a0) * 0.3
            cyy = y0 + (y1 - y0) * 0.75
            for dx, r in ((-0.06, 0.07), (0.05, 0.09), (0.15, 0.06)):
                p = [0.0, cyy, 0.0]
                if axis == "z":
                    p[0], p[2] = cx + dx, fixed + inner_sign * 0.02
                    n.sphere("white", tuple(p), r, s=(1, 0.7, 0.15), seg=12, rings=6)
                else:
                    p[2], p[0] = cx + dx, fixed + inner_sign * 0.02
                    n.sphere("white", tuple(p), r, s=(0.15, 0.7, 1), seg=12, rings=6)
            # curtains + rod
            rod_pos = face + inner_sign * 0.12
            for side, edge in ((-1, a0), (1, a1)):
                cc = edge - side * 0.04
                if axis == "z":
                    n.ell("strawberry", (cc, (y0 + y1) / 2 + 0.12, rod_pos), (0.11, 0.55, 0.05), seg=14, rings=10)
                    n.sphere("strawberry_dark", (cc, (y0 + y1) / 2 - 0.05, rod_pos + inner_sign * 0.03), 0.03, seg=8, rings=6)
                else:
                    n.ell("strawberry", (rod_pos, (y0 + y1) / 2 + 0.12, cc), (0.05, 0.55, 0.11), seg=14, rings=10)
                    n.sphere("strawberry_dark", (rod_pos + inner_sign * 0.03, (y0 + y1) / 2 - 0.05, cc), 0.03, seg=8, rings=6)
            if axis == "z":
                n.rod("wood_dark", (a0 - 0.2, y1 + 0.14, rod_pos), (a1 + 0.2, y1 + 0.14, rod_pos), 0.018)
            else:
                n.rod("wood_dark", (rod_pos, y1 + 0.14, a0 - 0.2), (rod_pos, y1 + 0.14, a1 + 0.2), 0.018)


def _string_lights(n, pts_fn, count):
    prev = None
    for k in range(count + 1):
        p = pts_fn(k / count)
        if prev is not None:
            n.rod("cocoa", prev, p, 0.007, seg=5)
        prev = p
        if k % 2 == 0 and 0 < k < count:
            n.cyl("cocoa", (p[0], p[1] - 0.04, p[2]), 0.018, 0.035, seg=8)
            n.sphere("bulb", (p[0], p[1] - 0.07, p[2]), 0.04, s=(1, 1.25, 1), seg=10, rings=8)


def room():
    root = Node("Cafe")
    _island(root.child("Island"))
    _floor(root.child("Floor"))
    walls = root.child("Walls")
    wx0, wx1 = -FX - T, FX + T
    _wall(walls, "z", FZ0 - T / 2, 1, wx0, wx1, [(-2.22, -1.22, *WIN_Y), (1.22, 2.22, *WIN_Y)])
    _wall(walls, "x", -FX - T / 2, 1, FZ0 - T, FZ1, [(-2.0, -1.0, *WIN_Y)])
    _wall(walls, "x", FX + T / 2, -1, FZ0 - T, FZ1, [(-2.0, -1.0, *WIN_Y), (DOOR_Z[0], DOOR_Z[1], 0.0, DOOR_H)])
    for sx in (-1, 1):
        walls.rbox("wood", (sx * (FX + T / 2), WALL_H / 2 + 0.03, FZ1), (T + 0.1, WALL_H + 0.06, 0.12), 0.03)
    walls.rbox("tomato", (FX + T + 0.12, DOOR_H + 0.22, sum(DOOR_Z) / 2), (0.4, 0.08, DOOR_Z[1] - DOOR_Z[0] + 0.4), 0.03, rot=(0, 0, -20))
    lights = root.child("Lights")
    sag = 0.22

    def back(t):
        x = -FX + 0.1 + t * (2 * FX - 0.2)
        local = (t * 3) % 1.0
        return (x, 2.22 - sag * math.sin(math.pi * local), FZ0 + 0.1)

    def left(t):
        z = FZ0 + 0.1 + t * (FZ1 - FZ0 - 0.4)
        local = (t * 3) % 1.0
        return (-FX + 0.1, 2.22 - sag * math.sin(math.pi * local), z)

    def right(t):
        z = FZ0 + 0.1 + t * (FZ1 - FZ0 - 0.4)
        local = (t * 3) % 1.0
        return (FX - 0.1, 2.22 - sag * math.sin(math.pi * local), z)

    _string_lights(lights, back, 30)
    _string_lights(lights, left, 32)
    _string_lights(lights, right, 32)
    return root


MODELS = {"room": room}
