"""The five cooking stations. Each is a 0.9 x 0.66 m counter unit.

Nodes the game looks for:
  Slot     where a finished dish appears (on the counter, front)
  Top      where the cooking progress ring floats
  Cooking  shown only while the station is busy (pancakes, bubbles ...)
"""

import math

from forge.scene import Node

W, H, D = 0.9, 0.62, 0.66
TOP = H + 0.06


def _cabinet(n, body, dark, light, doors=True, counter="cream"):
    n.rbox(dark, (0, 0.035, 0), (W - 0.06, 0.07, D - 0.06), 0.02, steps=2)
    n.rbox(body, (0, 0.07 + (H - 0.07) / 2, 0), (W, H - 0.07, D), 0.06)
    if counter:
        n.rbox(counter, (0, H + 0.03, 0), (W + 0.04, 0.06, D + 0.04), 0.025)
    if doors:
        for sx in (-1, 1):
            n.rbox(light, (sx * 0.215, 0.35, D / 2 + 0.004), (0.37, 0.4, 0.02), 0.03)
            n.sphere(dark, (sx * 0.06, 0.44, D / 2 + 0.024), 0.022, seg=10, rings=6)


def _markers(n, slot=(0, TOP, 0.2)):
    n.child("Slot", slot)
    n.child("Top", (0, 1.5, 0.05))
    return n.child("Cooking")


def coffee_machine():
    n = Node("CoffeeMachine")
    _cabinet(n, "mint", "mint_dark", "mint_light")
    n.rbox("mint", (0, TOP + 0.23, -0.12), (0.5, 0.46, 0.3), 0.07)
    n.rbox("mint_dark", (0, TOP + 0.42, -0.12), (0.52, 0.08, 0.32), 0.035)
    n.rbox("offwhite", (0, TOP + 0.36, 0.04), (0.3, 0.1, 0.14), 0.04)
    n.rbox("offwhite", (0, TOP + 0.13, 0.03), (0.34, 0.2, 0.02), 0.02)
    n.cyl("steel", (0, TOP + 0.25, 0.07), 0.045, 0.06, bevel=0.01, seg=16)
    n.rbox("charcoal", (0, TOP + 0.015, 0.03), (0.3, 0.03, 0.14), 0.01)
    n.lathe("white", [(0, 0), (0.03, 0), (0.04, 0.05), (0.036, 0.052), (0, 0.045)], c=(0, TOP + 0.03, 0.05), seg=14)
    n.cyl("white", (0.17, TOP + 0.23, 0.03), 0.045, 0.012, bevel=0.005, rot=(90, 0, 0), seg=16)
    n.rbox("tomato", (0.17, TOP + 0.245, 0.046), (0.008, 0.04, 0.006), 0.003, rot=(0, 0, -35))
    n.lathe("coffee", [(0, 0), (0.035, 0), (0.08, 0.1), (0.085, 0.14), (0, 0.14)], c=(-0.13, TOP + 0.46, -0.13), seg=14)
    n.cyl("mint_dark", (-0.13, TOP + 0.6, -0.13), 0.09, 0.03, bevel=0.012, seg=16)
    n.rod("steel", (-0.2, TOP + 0.3, 0.02), (-0.24, TOP + 0.12, 0.09), 0.012)
    for x in (-0.06, 0.06):
        n.sphere("tomato" if x < 0 else "butter", (x + 0.12, TOP + 0.36, 0.115), 0.02, seg=10, rings=6)
    cooking = _markers(n, (0.0, TOP, 0.22))
    cooking.rod("coffee", (0, TOP + 0.22, 0.07), (0, TOP + 0.08, 0.05), 0.008)
    return n


def oven():
    n = Node("BakeryOven")
    _cabinet(n, "strawberry", "strawberry_dark", "pink_light", doors=False)
    n.rbox("cocoa", (0, 0.36, D / 2 + 0.006), (0.66, 0.36, 0.02), 0.06)
    n.rbox("glow", (0, 0.36, D / 2 + 0.016), (0.58, 0.28, 0.01), 0.05)
    n.rbox("strawberry_dark", (0, 0.3, D / 2 + 0.022), (0.5, 0.012, 0.006), 0.003)
    n.rod("steel", (-0.24, 0.585, D / 2 + 0.05), (0.24, 0.585, D / 2 + 0.05), 0.016)
    for sx in (-1, 1):
        n.rod("steel", (sx * 0.22, 0.585, D / 2 + 0.05), (sx * 0.22, 0.585, D / 2), 0.012)
    n.rbox("strawberry", (0, TOP + 0.12, -0.3), (W, 0.24, 0.06), 0.03)
    for x in (-0.25, -0.1, 0.05):
        n.sphere("white", (x, TOP + 0.13, -0.265), 0.03, s=(1, 1, 0.6), seg=12, rings=8)
    n.sphere("butter", (0.25, TOP + 0.13, -0.265), 0.035, s=(1, 1, 0.5), seg=12, rings=8)
    # cake stand with a whole cake
    n.lathe("white", [(0, 0), (0.07, 0), (0.075, 0.012), (0.02, 0.02), (0.02, 0.1), (0.14, 0.1), (0.145, 0.115), (0, 0.115)], c=(-0.24, TOP, -0.1), seg=20)
    n.cyl("sponge", (-0.24, TOP + 0.115, -0.1), 0.11, 0.08, bevel=0.02, seg=20)
    n.cyl("pink_light", (-0.24, TOP + 0.175, -0.1), 0.115, 0.03, bevel=0.015, seg=20)
    for k in range(5):
        a = math.radians(k * 72)
        n.sphere("berry", (-0.24 + 0.07 * math.sin(a), TOP + 0.215, -0.1 + 0.07 * math.cos(a)), 0.022, seg=10, rings=6)
    n.rod("wood_light", (0.14, TOP + 0.03, -0.08), (0.38, TOP + 0.03, -0.14), 0.028)
    cooking = _markers(n, (0.14, TOP, 0.2))
    cooking.rbox("bulb", (0, 0.36, D / 2 + 0.02), (0.5, 0.2, 0.01), 0.04)
    return n


def griddle():
    n = Node("Griddle")
    _cabinet(n, "butter", "butter_dark", "offwhite", doors=False, counter=None)
    n.rbox("offwhite", (0, 0.27, D / 2 + 0.004), (0.76, 0.3, 0.02), 0.04)
    n.rod("steel", (-0.15, 0.36, D / 2 + 0.035), (0.15, 0.36, D / 2 + 0.035), 0.014)
    for x in (-0.25, 0.0, 0.25):
        n.cyl("white", (x, 0.52, D / 2), 0.04, 0.03, bevel=0.012, rot=(90, 0, 0), seg=14)
        n.rbox("charcoal", (x, 0.52, D / 2 + 0.032), (0.012, 0.05, 0.008), 0.004)
    n.rbox("cream", (0, H + 0.03, 0), (W + 0.04, 0.06, D + 0.04), 0.025)
    n.rbox("charcoal", (0, TOP + 0.01, -0.06), (0.8, 0.03, 0.44), 0.012)
    n.rbox("butter", (0, TOP + 0.12, -0.3), (W, 0.24, 0.06), 0.03)
    n.rbox("steel", (0.36, TOP + 0.01, 0.2), (0.09, 0.008, 0.11), 0.004)
    n.rod("wood_dark", (0.36, TOP + 0.012, 0.14), (0.36, TOP + 0.03, 0.0), 0.012)
    cooking = _markers(n, (-0.06, TOP, 0.22))
    for x in (-0.18, 0.14):
        cooking.cyl("pancake", (x, TOP + 0.025, -0.08), 0.09, 0.02, bevel=0.009, seg=20)
    return n


def soup_pot():
    n = Node("SoupPot")
    _cabinet(n, "sky", "sky_dark", "sky_light")
    n.cyl("charcoal", (-0.12, TOP, -0.1), 0.22, 0.02, bevel=0.008, seg=24)
    pot = [(0, 0), (0.17, 0), (0.19, 0.02), (0.2, 0.2), (0.212, 0.235), (0.2, 0.246), (0.19, 0.232), (0.188, 0.2), (0, 0.2)]
    n.lathe("tomato", pot, c=(-0.12, TOP + 0.02, -0.1), seg=28)
    n.lathe("soup", [(0, 0.19), (0.188, 0.19), (0.188, 0.21), (0, 0.212)], c=(-0.12, TOP + 0.02, -0.1), seg=24)
    for sx in (-1, 1):
        n.rbox("tomato_dark", (-0.12 + sx * 0.235, TOP + 0.2, -0.1), (0.07, 0.03, 0.1), 0.012)
    n.rod("steel", (-0.05, TOP + 0.22, -0.08), (0.04, TOP + 0.44, -0.02), 0.012)
    n.sphere("steel", (-0.07, TOP + 0.21, -0.09), 0.045, s=(1, 0.6, 1), seg=12, rings=8)
    n.rbox("sky", (0, TOP + 0.12, -0.3), (W, 0.24, 0.06), 0.03)
    for k, mat in enumerate(("tomato", "butter", "leaf")):
        n.lathe("sky_light", [(0, 0), (0.035, 0), (0.038, 0.09), (0, 0.09)], c=(0.18 + k * 0.08, TOP, -0.2), seg=12)
        n.cyl(mat, (0.18 + k * 0.08, TOP + 0.09, -0.2), 0.04, 0.02, bevel=0.008, seg=12)
    cooking = _markers(n, (0.25, TOP, 0.2))
    for c in ((-0.18, 0.0), (-0.06, -0.14), (-0.1, -0.02), (-0.2, -0.16)):
        cooking.sphere("soup", (c[0], TOP + 0.235, c[1]), 0.022, s=(1, 0.6, 1), seg=10, rings=6)
    return n


def freezer():
    n = Node("Freezer")
    _cabinet(n, "lavender", "lavender_dark", "lavender_light", doors=False, counter=None)
    n.rbox("lavender_dark", (0, H + 0.02, -0.08), (W + 0.04, 0.04, 0.52), 0.015)
    n.rbox("white", (0, H + 0.04, -0.08), (0.8, 0.012, 0.44), 0.005)
    for k, mat in enumerate(("pink_light", "sponge", "mint_light")):
        x = -0.26 + k * 0.26
        n.lathe("sky_light", [(0, 0), (0.1, 0), (0.105, 0.04), (0, 0.04)], c=(x, H + 0.04, -0.08), seg=16)
        n.dome(mat, (x, H + 0.075, -0.08), (0.095, 0.05, 0.095), seg=16)
    n.rbox("glass", (0, H + 0.14, -0.08), (0.84, 0.025, 0.46), 0.012)
    n.rbox("cream", (0, H + 0.03, 0.25), (W + 0.04, 0.06, 0.18), 0.025)
    n.cone("wood_light", (0.0, 0.34, D / 2 + 0.01), 0.07, 0.16, rot=(180, 0, 0), s=(1, 1, 0.25), seg=14)
    n.sphere("strawberry", (0.0, 0.37, D / 2 + 0.012), 0.075, s=(1, 1, 0.25))
    n.sphere("berry", (0.0, 0.45, D / 2 + 0.015), 0.022, s=(1, 1, 0.4), seg=10, rings=6)
    cooking = _markers(n, (0.0, TOP, 0.25))
    cooking.rod("steel", (0.1, H + 0.2, -0.05), (0.25, H + 0.36, 0.05), 0.012)
    cooking.sphere("pink_light", (0.08, H + 0.19, -0.06), 0.045)
    return n


MODELS = {
    "station_coffee": coffee_machine,
    "station_oven": oven,
    "station_griddle": griddle,
    "station_soup": soup_pot,
    "station_freezer": freezer,
}
