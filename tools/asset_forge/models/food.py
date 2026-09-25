"""Menu dishes and small props (coin, tray, emotes). Origins sit at the base centre."""

import math

from forge.scene import Node
from forge import geom as G


def _plate(n, R=0.15, mat="white"):
    n.lathe(mat, [(0, 0), (R * 0.7, 0), (R * 0.95, 0.012), (R, 0.02), (R * 0.96, 0.024), (R * 0.72, 0.012), (0, 0.012)], seg=28)


def latte():
    n = Node("Latte")
    n.lathe("strawberry", [(0, 0), (0.1, 0), (0.14, 0.02), (0.145, 0.028), (0.135, 0.031), (0.09, 0.013), (0, 0.013)], seg=28)
    n.lathe(
        "offwhite",
        [(0, 0.012), (0.055, 0.012), (0.075, 0.05), (0.085, 0.105), (0.088, 0.128), (0.082, 0.134), (0.076, 0.126), (0.072, 0.1), (0, 0.1)],
        seg=28,
    )
    n.cyl("coffee", (0, 0.1, 0), 0.074, 0.016, seg=24)
    n.torus("offwhite", (0.088, 0.072, 0), 0.034, 0.011, rot=(90, 0, 0), seg=12, tube=8, a0=15, a1=165)
    for sx in (-1, 1):
        n.ell("foam", (sx * 0.015, 0.117, -0.008), (0.022, 0.004, 0.02), seg=12, rings=6)
    n.cone("foam", (0, 0.117, 0.004), 0.028, 0.036, rot=(90, 0, 0), s=(1.05, 1.0, 0.12), seg=12)
    return n


def cake():
    n = Node("StrawberryCake")
    _plate(n)
    s = n.child("Slice")
    layers = [("sponge", 0.012, 0.052), ("white", 0.052, 0.064), ("sponge", 0.064, 0.104)]
    for mat, y0, y1 in layers:
        prof = [(0, y0), (0.14, y0), (0.14, y0), (0.14, y1), (0.14, y1), (0, y1)]
        s.add(mat, G.lathe(prof, 10, -27, 27, caps=True), G.compose(G.rot_y(70), G.translate(0, 0, -0.065)))
    top = [(r, y + 0.102) for (r, y) in G.rounded_cyl_profile(0.146, 0.024, 0.011, 2)]
    s.add("pink_light", G.lathe(top, 10, -27, 27, caps=True), G.compose(G.rot_y(70), G.translate(0, 0, -0.065)))
    n.sphere("white", (0.0, 0.132, 0.0), 0.026, s=(1, 0.7, 1))
    n.ell("berry", (0.0, 0.16, 0.0), (0.027, 0.032, 0.027), seg=14, rings=10)
    for a in (0, 120, 240):
        n.ell("leaf", (0, 0.19, 0), (0.016, 0.005, 0.008), rot=(0, a, 0))
    return n


def pancakes():
    n = Node("Pancakes")
    _plate(n, 0.16)
    for i, mat in enumerate(("pancake", "pancake_light", "pancake")):
        n.cyl(mat, (0, 0.014 + i * 0.029, 0), 0.11, 0.032, bevel=0.014, seg=28)
    n.cyl("syrup", (0, 0.1, 0), 0.098, 0.009, bevel=0.004, seg=24)
    for a, h in ((20, 0.03), (110, 0.022), (200, 0.035), (290, 0.02)):
        x, z = 0.103 * math.sin(math.radians(a)), 0.103 * math.cos(math.radians(a))
        n.ell("syrup", (x, 0.1 - h / 2, z), (0.018, h / 2 + 0.006, 0.018), seg=10, rings=6)
    n.rbox("butter_pat", (0.0, 0.116, 0.0), (0.05, 0.022, 0.05), 0.008, rot=(0, 25, 0))
    n.sphere("lavender_dark", (0.055, 0.112, 0.04), 0.014, seg=10, rings=6)
    n.sphere("lavender_dark", (-0.05, 0.112, 0.045), 0.014, seg=10, rings=6)
    return n


def soup():
    n = Node("PumpkinSoup")
    n.lathe(
        "sky",
        [(0, 0), (0.06, 0), (0.066, 0.012), (0.11, 0.045), (0.134, 0.088), (0.14, 0.102), (0.132, 0.106), (0.118, 0.082), (0.09, 0.058), (0, 0.052)],
        seg=28,
    )
    n.lathe("soup", [(0, 0.06), (0.09, 0.06), (0.12, 0.086), (0.12, 0.086), (0, 0.088)], seg=28)
    n.smile("white", (0.0, 0.089, -0.01), 0.035, 0.007, rot=(-90, 0, 0), span=120)
    for c in ((-0.05, 0.091, 0.03), (0.04, 0.091, 0.05), (0.06, 0.091, -0.03), (-0.03, 0.091, -0.06)):
        n.ell("leaf", c, (0.012, 0.004, 0.008), rot=(0, c[0] * 900, 0), seg=8, rings=4)
    return n


def sundae():
    n = Node("BerrySundae")
    n.lathe(
        "lavender",
        [(0, 0), (0.065, 0), (0.07, 0.01), (0.064, 0.02), (0.02, 0.028), (0.016, 0.055), (0.024, 0.066), (0.085, 0.11), (0.1, 0.145), (0.094, 0.152), (0.082, 0.135), (0, 0.126)],
        seg=28,
    )
    n.sphere("pink_light", (-0.038, 0.165, 0.02), 0.058)
    n.sphere("sponge", (0.04, 0.165, 0.02), 0.058)
    n.sphere("mint_light", (0.0, 0.165, -0.04), 0.058)
    n.sphere("strawberry", (0.0, 0.225, 0.0), 0.055)
    n.torus("white", (0, 0.265, 0), 0.028, 0.02, seg=16, tube=8)
    n.sphere("white", (0, 0.285, 0), 0.028)
    n.sphere("berry", (0, 0.325, 0), 0.024)
    n.rod("leaf", (0, 0.34, 0), (0.02, 0.38, 0), 0.004)
    n.rbox("butter_dark", (0.07, 0.25, -0.02), (0.022, 0.13, 0.022), 0.006, rot=(0, 0, -25))
    return n


# ---------------------------------------------------------------------------


def coin():
    n = Node("Coin")
    n.cyl("gold", (0, 0, -0.018), 0.12, 0.036, bevel=0.014, rot=(90, 0, 0), seg=28)
    for sz in (-1, 1):
        z = sz * 0.019
        for sx in (-1, 1):
            n.ell("gold_dark", (sx * 0.028, 0.018, z), (0.034, 0.032, 0.006), seg=12, rings=6)
        n.cone("gold_dark", (0, 0.024, z), 0.05, 0.075, rot=(180, 0, 0), s=(1, 1, 0.12), seg=12)
    return n


def tray():
    n = Node("Tray")
    n.lathe("wood_light", [(0, 0), (0.2, 0), (0.212, 0.01), (0.216, 0.036), (0.206, 0.039), (0.198, 0.016), (0, 0.016)], seg=32)
    return n


def heart():
    n = Node("Heart")
    for sx in (-1, 1):
        n.sphere("strawberry", (sx * 0.07, 0.05, 0), 0.1, s=(1, 1, 0.6))
    n.cone("strawberry", (0, 0.07, 0), 0.155, 0.2, rot=(180, 0, 0), s=(1, 1, 0.55), seg=20)
    n.sphere("white", (-0.09, 0.09, 0.055), 0.022, s=(1, 1, 0.5))
    return n


def cloud():
    n = Node("GrumpyCloud")
    for c, r in (((-0.12, 0.0, 0), 0.1), ((0.12, 0.0, 0), 0.1), ((0, 0.04, 0), 0.14), ((-0.05, -0.04, 0.03), 0.1), ((0.06, -0.04, 0.03), 0.1)):
        n.sphere("cloud", c, r, s=(1, 0.85, 0.8))
    n.rbox("butter", (0.0, -0.17, 0.02), (0.035, 0.12, 0.02), 0.006, rot=(0, 0, 25))
    n.rbox("butter", (0.02, -0.25, 0.02), (0.035, 0.1, 0.02), 0.006, rot=(0, 0, -25))
    for sx in (-1, 1):
        n.rbox("cloud_dark", (sx * 0.05, 0.06, 0.12), (0.06, 0.016, 0.01), 0.004, rot=(0, 0, sx * 20))
    return n


MODELS = {
    "food_latte": latte,
    "food_cake": cake,
    "food_pancakes": pancakes,
    "food_soup": soup,
    "food_sundae": sundae,
    "coin": coin,
    "tray": tray,
    "emote_heart": heart,
    "emote_cloud": cloud,
}
