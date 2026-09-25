"""Tiny scene graph used by model recipes.

A Node owns geometry grouped by palette material, plus child nodes. Only
translations are stored on nodes (pivots for in-game animation); every
rotation and scale is baked into the geometry.
"""

from . import geom as G


def _xf(c=(0.0, 0.0, 0.0), rot=(0.0, 0.0, 0.0), s=(1.0, 1.0, 1.0)):
    if not isinstance(s, (tuple, list)):
        s = (s, s, s)
    return G.compose(G.translate(*c), G.euler(*rot), G.scale(*s))


class Node:
    def __init__(self, name, t=(0.0, 0.0, 0.0)):
        self.name = name
        self.t = tuple(t)
        self.children = []
        self.parts = {}

    # -- structure ---------------------------------------------------------
    def child(self, name, t=(0.0, 0.0, 0.0)):
        n = Node(name, t)
        self.children.append(n)
        return n

    def add(self, mat, geo, m=None):
        if m is not None:
            geo = geo.transform(m)
        self.parts.setdefault(mat, []).append(geo)
        return self

    def walk(self):
        yield self
        for c in self.children:
            yield from c.walk()

    # -- primitive shortcuts -----------------------------------------------
    def sphere(self, mat, c, r, s=1.0, rot=(0, 0, 0), seg=20, rings=12):
        if not isinstance(s, (tuple, list)):
            s = (s, s, s)
        return self.add(mat, G.sphere(1.0, seg, rings), _xf(c, rot, (r * s[0], r * s[1], r * s[2])))

    def ell(self, mat, c, radii, rot=(0, 0, 0), seg=20, rings=12):
        return self.add(mat, G.sphere(1.0, seg, rings), _xf(c, rot, radii))

    def dome(self, mat, c, radii, rot=(0, 0, 0), seg=20, rings=6):
        return self.add(mat, G.hemisphere(1.0, seg, rings), _xf(c, rot, radii))

    def rbox(self, mat, c, size, r=0.02, rot=(0, 0, 0), steps=3):
        return self.add(mat, G.rounded_box(size[0], size[1], size[2], r, steps), _xf(c, rot))

    def box(self, mat, c, size, rot=(0, 0, 0)):
        r = min(size) * 0.12
        return self.add(mat, G.rounded_box(size[0], size[1], size[2], r, 1), _xf(c, rot))

    def cyl(self, mat, c, R, H, bevel=0.0, rot=(0, 0, 0), s=1.0, seg=24, steps=3):
        return self.add(mat, G.cylinder(R, H, bevel, seg, steps), _xf(c, rot, s))

    def lathe(self, mat, prof, c=(0, 0, 0), rot=(0, 0, 0), s=1.0, seg=24, **kw):
        return self.add(mat, G.lathe(prof, seg, **kw), _xf(c, rot, s))

    def cone(self, mat, c, R, H, rot=(0, 0, 0), s=1.0, seg=16):
        return self.add(mat, G.cone(R, H, seg), _xf(c, rot, s))

    def capsule(self, mat, c, r, h, rot=(0, 0, 0), s=1.0, seg=14):
        return self.add(mat, G.capsule(r, h, seg), _xf(c, rot, s))

    def torus(self, mat, c, R, a, rot=(0, 0, 0), s=1.0, seg=24, tube=10, a0=0.0, a1=360.0):
        return self.add(mat, G.torus(R, a, seg, tube, a0, a1), _xf(c, rot, s))

    def rod(self, mat, p0, p1, r, seg=10):
        """Capsule running from p0 to p1."""
        d = (p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2])
        L = (d[0] ** 2 + d[1] ** 2 + d[2] ** 2) ** 0.5
        geo = G.capsule(r, L + 2 * r, seg, 3)
        m = G.compose(G.translate(*p0), G.align_y(d), G.translate(0, -r, 0))
        return self.add(mat, geo, m)

    def smile(self, mat, c, R, a, rot=(0, 0, 0), span=80.0):
        """Small arc (like a smiling mouth) in the XY plane, facing +Z."""
        self.torus(mat, c, R, a, rot=(rot[0] + 90, rot[1], rot[2]), seg=10, tube=6, a0=-span, a1=span)
        return self

    def mirror(self, fn, *args, **kw):
        """Call a recipe helper once per side: fn(node, sx) with sx = -1 / +1."""
        for sx in (-1.0, 1.0):
            fn(self, sx, *args, **kw)
        return self
