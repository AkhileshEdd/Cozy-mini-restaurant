"""Chef Mochi and the five regulars (see the Characters board of the art sheet).

Shared rig, all pivots in metres, facing +Z, origin between the feet:
  Body   (0, 0, 0)          egg body in the shirt colour
  Head   (0, 0.46, 0)       neck pivot; head centre sits 0.22 above it
  ArmL/R (+-0.225, 0.37, 0) shoulder pivots
  FootL/R(+-0.105, 0, 0.03)
  Hold   (0, 0.36, 0.33)    where a carried tray goes
"""

import math

from forge.scene import Node

HEAD_C = (0.0, 0.22, 0.0)
HEAD_R = (0.285, 0.26, 0.265)


def _base(name, fur, feet, shirt, arms=None, wings=False):
    root = Node(name)
    body = root.child("Body")
    body.ell(shirt, (0, 0.28, 0), (0.245, 0.23, 0.215), seg=26, rings=16)
    for sx, nm in ((-1, "ArmL"), (1, "ArmR")):
        arm = root.child(nm, (sx * 0.225, 0.37, 0.0))
        if wings:
            arm.ell(arms or fur, (sx * 0.03, -0.08, 0.0), (0.045, 0.11, 0.085), rot=(0, 0, -sx * 14))
        else:
            arm.ell(arms or fur, (sx * 0.02, -0.085, 0.0), (0.062, 0.105, 0.062), rot=(0, 0, -sx * 12))
        foot = root.child("Foot" + nm[-1], (sx * 0.105, 0.0, 0.03))
        foot.ell(feet, (0, 0.045, 0.02), (0.08, 0.048, 0.105), seg=16, rings=10)
    head = root.child("Head", (0, 0.46, 0))
    root.child("Hold", (0, 0.36, 0.33))
    return root, body, head


def _head(head, fur, seg=28):
    head.ell(fur, HEAD_C, HEAD_R, seg=seg, rings=18)


def _eyes(head, y=0.235, x=0.1, z=0.238, color="eye"):
    for sx in (-1, 1):
        head.ell(color, (sx * x, y, z), (0.034, 0.046, 0.024), rot=(0, sx * 22, 0), seg=14, rings=10)
        head.sphere("white", (sx * x + 0.012, y + 0.02, z + 0.02), 0.011, seg=8, rings=6)


def _cheeks(head, y=0.15, x=0.17, z=0.2):
    for sx in (-1, 1):
        head.ell("blush", (sx * x, y, z), (0.05, 0.03, 0.018), rot=(0, sx * 38, 0), seg=14, rings=8)


def _smile(head, y=0.13, z=0.25, R=0.022, w=False):
    if w:
        for sx in (-1, 1):
            head.smile("eye", (sx * 0.02, y, z), 0.02, 0.0065, span=85)
    else:
        head.smile("eye", (0, y, z), R, 0.0065)


# ---------------------------------------------------------------------------


def chef_cat():
    root, body, head = _base("ChefMochi", "ginger", "ginger_dark", "ginger")
    # apron: a shell that hugs the front of the body
    prof = []
    for k in range(9):
        y = 0.07 + 0.34 * k / 8
        t = (y - 0.28) / 0.238
        prof.append((0.252 * max(0.0, 1 - t * t) ** 0.5, y))
    body.lathe("white", prof, s=(1.0, 1.0, 0.885), seg=14, a0=-62, a1=62)
    body.rbox("strawberry", (0, 0.2, 0.214), (0.11, 0.07, 0.03), 0.013)
    body.cone("tomato", (0, 0.49, 0.16), 0.085, 0.11, rot=(180, 0, 0), s=(1.0, 1.0, 0.45))
    body.capsule("ginger", (0.08, 0.1, -0.17), 0.035, 0.26, rot=(-55, 0, -25))

    _head(head, "ginger")
    for i, x in enumerate((-0.06, 0.0, 0.06)):
        head.ell("ginger_dark", (x, 0.45, 0.07), (0.018, 0.012, 0.05), rot=(35, 0, 0), seg=8, rings=6)
    for sx in (-1, 1):
        head.cone("ginger", (sx * 0.17, 0.36, -0.01), 0.09, 0.16, rot=(0, 0, -sx * 22))
        head.cone("pink_inner", (sx * 0.165, 0.37, 0.03), 0.055, 0.11, rot=(0, 0, -sx * 22), s=(1, 1, 0.5))
    head.ell("offwhite", (0, 0.125, 0.205), (0.1, 0.07, 0.07), seg=18, rings=10)
    head.ell("tomato", (0, 0.168, 0.268), (0.022, 0.015, 0.014), seg=10, rings=6)
    _eyes(head)
    _cheeks(head)
    _smile(head, y=0.128, z=0.272, w=True)
    # chef hat
    head.cyl("white", (0, 0.4, -0.01), 0.2, 0.12, bevel=0.03, seg=28)
    head.cyl("linen", (0, 0.4, -0.01), 0.205, 0.035, bevel=0.012, seg=28)
    for c, r in (((-0.1, 0.57, -0.01), 0.11), ((0.1, 0.57, -0.01), 0.11), ((0, 0.58, 0.08), 0.1), ((0, 0.58, -0.1), 0.1), ((0, 0.63, -0.01), 0.13)):
        head.sphere("white", c, r, seg=18, rings=12)
    return root


def bunny():
    root, body, head = _base("Pip", "bunny", "bunny_feet", "sky", arms="bunny")
    body.sphere("white", (0, 0.16, -0.21), 0.065)
    _head(head, "bunny")
    head.ell("bunny", (-0.1, 0.55, -0.02), (0.062, 0.17, 0.045), rot=(-6, 0, 8))
    head.ell("pink_inner", (-0.1, 0.56, 0.02), (0.032, 0.12, 0.02), rot=(-6, 0, 8))
    head.ell("bunny", (0.12, 0.52, 0.0), (0.062, 0.17, 0.045), rot=(18, 0, -24))
    head.ell("pink_inner", (0.125, 0.53, 0.04), (0.032, 0.12, 0.02), rot=(18, 0, -24))
    # little bow at the base of the left ear
    head.ell("strawberry", (-0.03, 0.44, 0.08), (0.04, 0.028, 0.02), rot=(0, 0, 20))
    head.ell("strawberry", (-0.11, 0.44, 0.08), (0.04, 0.028, 0.02), rot=(0, 0, -20))
    head.sphere("strawberry_dark", (-0.07, 0.44, 0.09), 0.018)
    _eyes(head)
    _cheeks(head)
    head.ell("strawberry", (0, 0.168, 0.258), (0.02, 0.014, 0.012), seg=10, rings=6)
    _smile(head, y=0.13, z=0.252, w=True)
    return root


def bear():
    root, body, head = _base("Bruno", "bear", "bear_dark", "mint", arms="bear")
    body.sphere("bear", (0, 0.14, -0.2), 0.05)
    _head(head, "bear")
    for sx in (-1, 1):
        head.sphere("bear", (sx * 0.2, 0.4, -0.03), 0.085)
        head.ell("bear_muzzle", (sx * 0.2, 0.4, 0.035), (0.045, 0.045, 0.022))
    head.ell("bear_muzzle", (0, 0.125, 0.205), (0.1, 0.07, 0.07), seg=18, rings=10)
    head.ell("eye", (0, 0.168, 0.265), (0.03, 0.021, 0.018), seg=10, rings=6)
    _eyes(head, y=0.245)
    _cheeks(head)
    _smile(head, y=0.13, z=0.268, R=0.025)
    return root


def frog():
    root, body, head = _base("Lily", "frog", "leaf", "butter", arms="frog")
    head.ell("frog", (0, 0.2, 0), (0.31, 0.24, 0.27), seg=28, rings=18)
    for sx in (-1, 1):
        head.sphere("frog", (sx * 0.14, 0.36, 0.08), 0.1)
        head.sphere("white", (sx * 0.145, 0.37, 0.135), 0.068)
        head.sphere("eye", (sx * 0.148, 0.372, 0.19), 0.036, seg=12, rings=8)
        head.sphere("white", (sx * 0.148 + 0.012, 0.386, 0.222), 0.011, seg=8, rings=6)
    _cheeks(head, y=0.14, x=0.2, z=0.19)
    head.smile("eye", (0, 0.16, 0.255), 0.07, 0.008, rot=(-12, 0, 0), span=70)
    # a small flower tucked on the head
    for k in range(5):
        a = k * 72
        head.sphere("pink_light", (0.2 + 0.025 * math.cos(math.radians(a)), 0.37 + 0.025 * math.sin(math.radians(a)), -0.05), 0.022)
    head.sphere("butter", (0.2, 0.37, -0.04), 0.018)
    return root


def chick():
    root, body, head = _base("Sunny", "chick", "beak", "pink_light", arms="chick_wing", wings=True)
    body.cone("chick", (0, 0.2, -0.2), 0.07, 0.1, rot=(-110, 0, 0), s=(1.2, 1, 0.6))
    _head(head, "chick")
    head.ell("chick", (0.0, 0.5, 0.02), (0.03, 0.07, 0.03), rot=(0, 0, 0))
    head.ell("chick", (-0.04, 0.49, 0.02), (0.026, 0.055, 0.026), rot=(0, 0, 30))
    head.ell("chick", (0.04, 0.49, 0.02), (0.026, 0.055, 0.026), rot=(0, 0, -30))
    head.cone("beak", (0, 0.155, 0.24), 0.05, 0.075, rot=(90, 0, 0), s=(1.2, 1.0, 0.7))
    _eyes(head, y=0.245)
    _cheeks(head)
    return root


def panda():
    root, body, head = _base("Bao", "panda", "panda_dark", "lavender", arms="panda_dark")
    body.sphere("panda", (0, 0.14, -0.2), 0.05)
    _head(head, "panda")
    for sx in (-1, 1):
        head.sphere("panda_dark", (sx * 0.2, 0.4, -0.03), 0.085)
        head.ell("panda_dark", (sx * 0.1, 0.225, 0.232), (0.06, 0.075, 0.025), rot=(0, sx * 22, sx * 25))
        head.sphere("white", (sx * 0.1, 0.235, 0.254), 0.026, seg=12, rings=8)
        head.sphere("eye", (sx * 0.1, 0.232, 0.272), 0.015, seg=10, rings=6)
    head.ell("panda_dark", (0, 0.165, 0.258), (0.028, 0.019, 0.015), seg=10, rings=6)
    _cheeks(head, y=0.13)
    _smile(head, y=0.12, z=0.25, R=0.022)
    return root


MODELS = {
    "chef_cat": chef_cat,
    "cust_bunny": bunny,
    "cust_bear": bear,
    "cust_frog": frog,
    "cust_chick": chick,
    "cust_panda": panda,
}
