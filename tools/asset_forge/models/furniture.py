"""Dining-room furniture and décor."""

import math

from forge.scene import Node


def table():
    n = Node("Table")
    n.lathe(
        "wood_dark",
        [(0, 0), (0.2, 0), (0.21, 0.02), (0.19, 0.04), (0.06, 0.07), (0.045, 0.1), (0.045, 0.46), (0.1, 0.5), (0.1, 0.5), (0, 0.5)],
        seg=24,
    )
    n.cyl("white", (0, 0.47, 0), 0.475, 0.115, bevel=0.025, seg=36)
    for k in range(20):
        a = math.radians(k * 18 + 9)
        n.sphere("white", (0.47 * math.sin(a), 0.47, 0.47 * math.cos(a)), 0.035, seg=8, rings=6)
    for k in range(20):
        a = math.radians(k * 18)
        n.sphere("strawberry", (0.482 * math.sin(a), 0.45, 0.482 * math.cos(a)), 0.02, seg=8, rings=5)
    # vase + flower
    n.lathe("sky", [(0, 0), (0.035, 0), (0.045, 0.04), (0.02, 0.09), (0.028, 0.11), (0.02, 0.112), (0, 0.1)], c=(0, 0.585, -0.08), seg=14)
    n.rod("leaf", (0, 0.68, -0.08), (0.01, 0.77, -0.07), 0.006)
    n.ell("leaf", (0.035, 0.73, -0.07), (0.03, 0.008, 0.016), rot=(0, 0, 30), seg=8, rings=5)
    for k in range(5):
        a = math.radians(k * 72)
        n.sphere("strawberry", (0.01 + 0.03 * math.sin(a), 0.785, -0.07 + 0.03 * math.cos(a)), 0.025, s=(1, 0.6, 1), seg=10, rings=6)
    n.sphere("butter", (0.01, 0.795, -0.07), 0.018, seg=10, rings=6)
    n.child("Top", (0, 0.585, 0))
    return n


def chair():
    n = Node("Chair")
    for sx in (-1, 1):
        for sz in (-1, 1):
            n.rod("wood_dark", (sx * 0.14, 0.0, sz * 0.14), (sx * 0.125, 0.3, sz * 0.125), 0.022)
    n.cyl("wood", (0, 0.29, 0), 0.21, 0.05, bevel=0.02, seg=24)
    n.cyl("strawberry", (0, 0.335, 0), 0.18, 0.045, bevel=0.02, seg=24)
    for sx in (-1, 1):
        n.rod("wood_dark", (sx * 0.12, 0.33, -0.16), (sx * 0.12, 0.5, -0.18), 0.018)
    n.rbox("wood", (0, 0.6, -0.185), (0.36, 0.26, 0.05), 0.08, rot=(-8, 0, 0))
    n.sphere("strawberry", (0, 0.6, -0.155), 0.035, s=(1, 1, 0.4), seg=12, rings=8)
    n.child("Seat", (0, 0.36, 0))
    return n


def _leaf(n, base, yaw, pitch, length, mat, width=0.1):
    d = (math.sin(math.radians(yaw)) * math.cos(math.radians(pitch)), math.sin(math.radians(pitch)), math.cos(math.radians(yaw)) * math.cos(math.radians(pitch)))
    tip = tuple(base[i] + d[i] * length for i in range(3))
    mid = tuple(base[i] + d[i] * length * 0.62 for i in range(3))
    n.rod("leaf", base, mid, 0.008, seg=6)
    n.ell(mat, tuple((mid[i] + tip[i]) / 2 for i in range(3)), (width, 0.025, length * 0.42), rot=(-pitch, yaw, 0), seg=14, rings=8)


def plant_big():
    n = Node("PlantBig")
    n.lathe(
        "terracotta",
        [(0, 0), (0.13, 0), (0.14, 0.01), (0.165, 0.25), (0.2, 0.26), (0.205, 0.31), (0.195, 0.32), (0.17, 0.3), (0, 0.3)],
        seg=24,
    )
    n.cyl("terracotta_dark", (0, 0.25, 0), 0.203, 0.012, seg=24)
    n.cyl("dirt_dark", (0, 0.27, 0), 0.17, 0.03, seg=20)
    mats = ("leaf", "leaf_mid", "leaf_light")
    for k in range(9):
        yaw = k * 40 + (k % 3) * 7
        pitch = 30 + (k % 3) * 14
        _leaf(n, (0, 0.3, 0), yaw, pitch, 0.34 + (k % 2) * 0.08, mats[k % 3], 0.1)
    _leaf(n, (0, 0.3, 0), 10, 80, 0.4, "leaf_light", 0.09)
    return n


def plant_small():
    n = Node("PlantSmall")
    n.lathe("pink_light", [(0, 0), (0.08, 0), (0.09, 0.12), (0.1, 0.13), (0.095, 0.14), (0, 0.13)], seg=18)
    n.sphere("leaf_mid", (0, 0.2, 0), 0.1, s=(1, 0.85, 1))
    n.sphere("leaf", (-0.05, 0.24, 0.02), 0.07)
    n.sphere("leaf_light", (0.05, 0.25, -0.02), 0.065)
    for c in ((0.05, 0.27, 0.06), (-0.07, 0.25, 0.06), (0.0, 0.3, -0.04)):
        n.sphere("butter", c, 0.02, seg=8, rings=6)
    return n


def lamp():
    n = Node("PendantLamp")
    n.rod("cocoa", (0, 0.2, 0), (0, 1.8, 0), 0.008, seg=6)
    n.cyl("wood_dark", (0, 0.18, 0), 0.035, 0.05, bevel=0.01, seg=12)
    n.dome("butter", (0, 0.02, 0), (0.22, 0.18, 0.22), seg=24, rings=8)
    n.torus("butter_dark", (0, 0.02, 0), 0.215, 0.016, seg=24, tube=6)
    n.sphere("bulb", (0, 0.0, 0), 0.065, seg=12, rings=8)
    return n


def rug():
    n = Node("Rug")
    n.cyl("strawberry", (0, 0, 0), 1.0, 0.012, bevel=0.006, seg=48)
    n.cyl("cream", (0, 0.0, 0), 0.86, 0.016, seg=48)
    n.cyl("pink_light", (0, 0.0, 0), 0.52, 0.02, seg=40)
    for k in range(24):
        a = math.radians(k * 15)
        n.sphere("butter", (0.7 * math.sin(a), 0.016, 0.7 * math.cos(a)), 0.035, s=(1, 0.2, 1), seg=8, rings=4)
    return n


def menu_board():
    n = Node("MenuBoard")
    for sz in (-1, 1):
        rot = (sz * -14, 0, 0)
        c = (0, 0.42, sz * 0.1)
        n.rbox("wood", c, (0.5, 0.8, 0.04), 0.03, rot=rot)
        if sz > 0:
            n.rbox("charcoal", (0, 0.44, 0.124), (0.42, 0.62, 0.012), 0.02, rot=rot)
    for i, (w, mat) in enumerate(((0.26, "white"), (0.3, "pink_light"), (0.22, "white"), (0.28, "butter"), (0.18, "mint_light"))):
        y = 0.66 - i * 0.1
        z = 0.136 - (y - 0.44) * math.tan(math.radians(14))
        n.rbox(mat, (-0.02, y, z), (w, 0.022, 0.006), 0.008, rot=(-14, 0, 0))
    n.rod("wood_dark", (-0.2, 0.0, -0.05), (-0.2, 0.0, 0.05), 0.012)
    return n


def picture_frame():
    n = Node("PictureFrame")
    n.rbox("wood_dark", (0, 0, 0.02), (0.56, 0.44, 0.04), 0.02)
    n.rbox("sky_light", (0, 0, 0.042), (0.46, 0.34, 0.01), 0.01)
    n.dome("leaf_light", (0.05, -0.17, 0.047), (0.3, 0.12, 0.004), rot=(0, 0, 0), seg=20, rings=4)
    n.dome("leaf", (-0.14, -0.17, 0.049), (0.18, 0.09, 0.004), seg=20, rings=4)
    n.sphere("butter", (0.13, 0.07, 0.048), 0.05, s=(1, 1, 0.1))
    n.sphere("white", (-0.1, 0.09, 0.048), 0.04, s=(1.6, 0.8, 0.1))
    return n


def wall_clock():
    n = Node("WallClock")
    n.torus("wood_dark", (0, 0, 0.03), 0.2, 0.03, rot=(90, 0, 0), seg=32, tube=8)
    n.cyl("cream", (0, 0, 0.0), 0.2, 0.035, rot=(90, 0, 0), seg=32)
    for k in range(12):
        a = math.radians(k * 30)
        r = 0.018 if k % 3 == 0 else 0.01
        n.sphere("cocoa" if k % 3 == 0 else "wood_dark", (0.155 * math.sin(a), 0.155 * math.cos(a), 0.036), r, s=(1, 1, 0.4), seg=8, rings=5)
    n.sphere("tomato", (0, 0, 0.045), 0.02, seg=10, rings=6)
    hour = n.child("HourHand", (0, 0, 0.04))
    hour.rbox("cocoa", (0, 0.05, 0), (0.024, 0.11, 0.008), 0.008)
    minute = n.child("MinuteHand", (0, 0, 0.046))
    minute.rbox("cocoa", (0, 0.075, 0), (0.016, 0.155, 0.008), 0.006)
    return n


def shelf():
    n = Node("Shelf")
    n.rbox("wood", (0, 0, 0.13), (0.9, 0.04, 0.24), 0.015)
    for sx in (-1, 1):
        n.rbox("wood_dark", (sx * 0.34, -0.08, 0.04), (0.04, 0.14, 0.06), 0.012)
    for k, (mat, lid) in enumerate((("tomato", "white"), ("butter", "strawberry"), ("leaf_light", "sky"))):
        x = -0.32 + k * 0.14
        n.lathe("sky_light", [(0, 0), (0.05, 0), (0.055, 0.12), (0.04, 0.14), (0, 0.14)], c=(x, 0.02, 0.13), seg=14)
        n.cyl(mat, (x, 0.03, 0.13), 0.047, 0.07, seg=14)
        n.cyl(lid, (x, 0.155, 0.13), 0.045, 0.03, bevel=0.01, seg=14)
    for i, mat in enumerate(("lavender", "mint", "strawberry")):
        n.rbox(mat, (0.12 + i * 0.045, 0.12, 0.13), (0.04, 0.2, 0.16), 0.01, rot=(0, 0, -6 if i == 2 else 0))
    n.lathe("terracotta", [(0, 0), (0.05, 0), (0.06, 0.08), (0, 0.08)], c=(0.33, 0.02, 0.13), seg=14)
    for k in range(4):
        n.ell("leaf_mid", (0.33 + 0.04 * math.sin(k * 1.6), 0.08, 0.13 + 0.04 * math.cos(k * 1.6)), (0.03, 0.012, 0.08), rot=(-60, k * 90, 0), seg=10, rings=6)
    return n


def tree():
    n = Node("Tree")
    n.lathe("trunk", [(0, 0), (0.16, 0), (0.12, 0.08), (0.09, 0.4), (0.08, 1.0), (0, 1.0)], seg=16)
    for c, r, mat in (
        ((0, 1.25, 0), 0.55, "leaf_mid"),
        ((-0.35, 1.05, 0.12), 0.38, "leaf"),
        ((0.35, 1.1, -0.05), 0.4, "leaf_mid"),
        ((0.05, 1.62, 0.02), 0.36, "leaf_light"),
        ((0.1, 1.2, 0.36), 0.3, "leaf_light"),
    ):
        n.sphere(mat, c, r, seg=18, rings=12)
    for c in ((0.2, 1.4, 0.45), (-0.3, 1.3, 0.35), (0.45, 1.05, 0.25)):
        n.sphere("berry", c, 0.04, seg=8, rings=6)
    return n


def bush():
    n = Node("Bush")
    n.sphere("leaf", (0, 0.2, 0), 0.26, s=(1, 0.8, 1))
    n.sphere("leaf_mid", (-0.2, 0.16, 0.08), 0.18)
    n.sphere("leaf_light", (0.2, 0.17, 0.04), 0.19)
    for c, mat in (((0.08, 0.38, 0.12), "strawberry"), ((-0.14, 0.3, 0.2), "white"), ((0.24, 0.28, 0.18), "butter")):
        n.sphere(mat, c, 0.035, seg=8, rings=6)
    return n


def flowers():
    n = Node("Flowers")
    for k, (x, z, mat) in enumerate(((-0.15, 0.05, "strawberry"), (0.0, -0.1, "butter"), (0.14, 0.08, "lavender"), (0.05, 0.14, "white"), (-0.06, -0.02, "sky"))):
        h = 0.18 + (k % 3) * 0.05
        n.rod("leaf", (x, 0, z), (x, h, z), 0.008, seg=6)
        n.ell("leaf_light", (x + 0.03, h * 0.5, z), (0.03, 0.008, 0.015), rot=(0, 0, 30), seg=8, rings=4)
        for p in range(5):
            a = math.radians(p * 72)
            n.sphere(mat, (x + 0.028 * math.sin(a), h, z + 0.028 * math.cos(a)), 0.022, s=(1, 0.5, 1), seg=8, rings=5)
        n.sphere("butter_dark" if mat != "butter" else "ginger", (x, h + 0.008, z), 0.016, seg=8, rings=5)
    return n


MODELS = {
    "table": table,
    "chair": chair,
    "plant_big": plant_big,
    "plant_small": plant_small,
    "lamp_pendant": lamp,
    "rug": rug,
    "menu_board": menu_board,
    "picture_frame": picture_frame,
    "wall_clock": wall_clock,
    "shelf": shelf,
    "tree": tree,
    "bush": bush,
    "flowers": flowers,
}
