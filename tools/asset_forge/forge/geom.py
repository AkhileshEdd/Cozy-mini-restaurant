"""Procedural geometry for the Cozy asset forge.

Everything is built from a handful of soft primitives (lathe profiles and
rounded boxes) plus 4x4 transforms. Normals are analytic or averaged along
profiles, and triangle winding is always made to agree with the normals, so
model code never has to think about face orientation.
"""

import math

# ---------------------------------------------------------------------------
# 4x4 matrices (row-major lists)
# ---------------------------------------------------------------------------

IDENTITY = [[1.0, 0.0, 0.0, 0.0], [0.0, 1.0, 0.0, 0.0], [0.0, 0.0, 1.0, 0.0], [0.0, 0.0, 0.0, 1.0]]


def _mm(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def compose(*ms):
    """compose(A, B, C) applies C first, then B, then A (like A @ B @ C)."""
    r = IDENTITY
    for m in ms:
        r = _mm(r, m)
    return r


def translate(x, y, z):
    return [[1.0, 0.0, 0.0, x], [0.0, 1.0, 0.0, y], [0.0, 0.0, 1.0, z], [0.0, 0.0, 0.0, 1.0]]


def scale(x, y=None, z=None):
    if y is None:
        y = z = x
    return [[x, 0.0, 0.0, 0.0], [0.0, y, 0.0, 0.0], [0.0, 0.0, z, 0.0], [0.0, 0.0, 0.0, 1.0]]


def rot_x(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[1.0, 0.0, 0.0, 0.0], [0.0, c, -s, 0.0], [0.0, s, c, 0.0], [0.0, 0.0, 0.0, 1.0]]


def rot_y(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[c, 0.0, s, 0.0], [0.0, 1.0, 0.0, 0.0], [-s, 0.0, c, 0.0], [0.0, 0.0, 0.0, 1.0]]


def rot_z(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[c, -s, 0.0, 0.0], [s, c, 0.0, 0.0], [0.0, 0.0, 1.0, 0.0], [0.0, 0.0, 0.0, 1.0]]


def euler(x=0.0, y=0.0, z=0.0):
    """Roll (z), then pitch (x), then yaw (y)."""
    return compose(rot_y(y), rot_x(x), rot_z(z))


def align_y(d):
    """Rotation that maps +Y onto direction d."""
    L = math.sqrt(sum(c * c for c in d))
    dx, dy, dz = (c / L for c in d)
    # axis = Y x d, angle = acos(Y . d)
    ax, ay, az = dz, 0.0, -dx
    s = math.sqrt(ax * ax + az * az)
    c = dy
    if s < 1e-9:
        return IDENTITY if c > 0 else rot_x(180)
    ax, az = ax / s, az / s
    t = 1 - c
    return [
        [t * ax * ax + c, -s * az, t * ax * az, 0.0],
        [s * az, c, -s * ax, 0.0],
        [t * ax * az, s * ax, t * az * az + c, 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ]


def _normal_matrix(m):
    a = [row[:3] for row in m[:3]]
    cof = [[0.0] * 3 for _ in range(3)]
    for i in range(3):
        i1, i2 = [k for k in range(3) if k != i]
        for j in range(3):
            j1, j2 = [k for k in range(3) if k != j]
            minor = a[i1][j1] * a[i2][j2] - a[i1][j2] * a[i2][j1]
            cof[i][j] = minor if (i + j) % 2 == 0 else -minor
    det = sum(a[0][j] * cof[0][j] for j in range(3))
    sgn = 1.0 if det >= 0 else -1.0
    return [[cof[i][j] * sgn for j in range(3)] for i in range(3)]


def _normalize(v):
    L = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    if L < 1e-12:
        return (0.0, 1.0, 0.0)
    return (v[0] / L, v[1] / L, v[2] / L)


# ---------------------------------------------------------------------------
# Geometry container
# ---------------------------------------------------------------------------


class Geo:
    __slots__ = ("pos", "nrm", "idx")

    def __init__(self, pos, nrm, idx):
        self.pos = pos
        self.nrm = nrm
        self.idx = idx

    def transform(self, m):
        nm = _normal_matrix(m)
        pos = [
            (
                m[0][0] * x + m[0][1] * y + m[0][2] * z + m[0][3],
                m[1][0] * x + m[1][1] * y + m[1][2] * z + m[1][3],
                m[2][0] * x + m[2][1] * y + m[2][2] * z + m[2][3],
            )
            for (x, y, z) in self.pos
        ]
        nrm = [
            _normalize(
                (
                    nm[0][0] * x + nm[0][1] * y + nm[0][2] * z,
                    nm[1][0] * x + nm[1][1] * y + nm[1][2] * z,
                    nm[2][0] * x + nm[2][1] * y + nm[2][2] * z,
                )
            )
            for (x, y, z) in self.nrm
        ]
        g = Geo(pos, nrm, list(self.idx))
        g.fix_winding()
        return g

    def fix_winding(self):
        """Drop degenerate triangles and flip any whose face disagrees with its normals."""
        P, N, I = self.pos, self.nrm, self.idx
        out = []
        for t in range(0, len(I), 3):
            a, b, c = I[t], I[t + 1], I[t + 2]
            pa, pb, pc = P[a], P[b], P[c]
            ux, uy, uz = pb[0] - pa[0], pb[1] - pa[1], pb[2] - pa[2]
            vx, vy, vz = pc[0] - pa[0], pc[1] - pa[1], pc[2] - pa[2]
            fx, fy, fz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
            if fx * fx + fy * fy + fz * fz < 1e-18:
                continue
            nx = N[a][0] + N[b][0] + N[c][0]
            ny = N[a][1] + N[b][1] + N[c][1]
            nz = N[a][2] + N[b][2] + N[c][2]
            if fx * nx + fy * ny + fz * nz < 0:
                out += (a, c, b)
            else:
                out += (a, b, c)
        self.idx = out

    @staticmethod
    def merge(geos):
        pos, nrm, idx = [], [], []
        for g in geos:
            off = len(pos)
            pos += g.pos
            nrm += g.nrm
            idx += [i + off for i in g.idx]
        return Geo(pos, nrm, idx)


# ---------------------------------------------------------------------------
# Primitives
# ---------------------------------------------------------------------------


def lathe(profile, seg=24, a0=0.0, a1=360.0, normals=None, caps=False):
    """Revolve a (radius, y) profile around +Y.

    Walk the profile counter-clockwise in the (r, y) plane (bottom centre ->
    outward -> up -> inward) so the averaged normals face outward. Repeat a
    point to make a crease. `caps` closes partial sweeps with flat faces
    (the profile must then be convex).
    """
    n = len(profile)
    edges = []
    for i in range(n - 1):
        r0, y0 = profile[i]
        r1, y1 = profile[i + 1]
        dr, dy = r1 - r0, y1 - y0
        L = math.hypot(dr, dy)
        edges.append((dy / L, -dr / L) if L > 1e-9 else None)

    if normals is None:
        pn = []
        for i in range(n):
            acc_r = acc_y = 0.0
            for e in (edges[i - 1] if i > 0 else None, edges[i] if i < n - 1 else None):
                if e:
                    acc_r += e[0]
                    acc_y += e[1]
            L = math.hypot(acc_r, acc_y)
            nr, ny = (acc_r / L, acc_y / L) if L > 1e-9 else (0.0, 1.0)
            if profile[i][0] < 1e-9:
                nr, ny = 0.0, (1.0 if ny >= 0 else -1.0)
            pn.append((nr, ny))
    else:
        pn = normals

    pos, nrm, idx = [], [], []
    for j in range(seg + 1):
        t = math.radians(a0 + (a1 - a0) * j / seg)
        s, c = math.sin(t), math.cos(t)
        for (r, y), (nr, ny) in zip(profile, pn):
            pos.append((r * s, y, r * c))
            nrm.append((nr * s, ny, nr * c))
    for j in range(seg):
        for i in range(n - 1):
            if edges[i] is None:
                continue
            a = j * n + i
            b = (j + 1) * n + i
            c = b + 1
            d = a + 1
            idx += (a, b, c, a, c, d)

    if caps and abs(a1 - a0) < 359.999:
        for ang, sgn in ((a0, -1.0), (a1, 1.0)):
            t = math.radians(ang)
            s, c = math.sin(t), math.cos(t)
            fn = (c * sgn, 0.0, -s * sgn)
            base = len(pos)
            for (r, y) in profile:
                pos.append((r * s, y, r * c))
                nrm.append(fn)
            for k in range(1, n - 1):
                idx += (base, base + k, base + k + 1)

    g = Geo(pos, nrm, idx)
    g.fix_winding()
    return g


def sphere(r=1.0, seg=20, rings=12):
    prof, nrm = [], []
    for k in range(rings + 1):
        a = math.pi * k / rings
        prof.append((r * math.sin(a), -r * math.cos(a)))
        nrm.append((math.sin(a), -math.cos(a)))
    return lathe(prof, seg, normals=nrm)


def hemisphere(r=1.0, seg=20, rings=6, closed=True):
    """Upper half-sphere, flat side down at y=0."""
    prof, nrm = [], []
    if closed:
        prof += [(0.0, 0.0), (r, 0.0)]
        nrm += [(0.0, -1.0), (0.0, -1.0)]
    for k in range(rings + 1):
        a = (math.pi / 2) * k / rings
        prof.append((r * math.cos(a), r * math.sin(a)))
        nrm.append((math.cos(a), math.sin(a)))
    return lathe(prof, seg, normals=nrm)


def rounded_cyl_profile(R, H, bevel=0.0, steps=3, top=True, bottom=True):
    """Profile for a puck/cylinder from y=0 to y=H with optional rounded rims."""
    b = min(bevel, R, H / 2)
    prof = [(0.0, 0.0)]
    if bottom and b > 1e-6:
        for k in range(steps + 1):
            a = -math.pi / 2 + (math.pi / 2) * k / steps
            prof.append((R - b + b * math.cos(a), b + b * math.sin(a)))
    else:
        prof += [(R, 0.0), (R, 0.0)]
    if top and b > 1e-6:
        for k in range(steps + 1):
            a = (math.pi / 2) * k / steps
            prof.append((R - b + b * math.cos(a), H - b + b * math.sin(a)))
    else:
        prof += [(R, H), (R, H)]
    prof.append((0.0, H))
    return prof


def cylinder(R, H, bevel=0.0, seg=24, steps=3):
    return lathe(rounded_cyl_profile(R, H, bevel, steps), seg)


def cone(R, H, seg=16):
    return lathe([(0.0, 0.0), (R, 0.0), (R, 0.0), (0.0, H)], seg)


def capsule(r, h, seg=16, rings=5):
    """Capsule standing on y=0 with total height h (h >= 2r)."""
    h = max(h, 2 * r)
    prof, nrm = [], []
    for k in range(rings + 1):
        a = -math.pi / 2 + (math.pi / 2) * k / rings
        prof.append((r * math.cos(a), r + r * math.sin(a)))
        nrm.append((math.cos(a), math.sin(a)))
    for k in range(rings + 1):
        a = (math.pi / 2) * k / rings
        prof.append((r * math.cos(a), h - r + r * math.sin(a)))
        nrm.append((math.cos(a), math.sin(a)))
    return lathe(prof, seg, normals=nrm)


def torus(R, a, seg=24, tube=10, a0=0.0, a1=360.0):
    prof, nrm = [], []
    for k in range(tube + 1):
        t = -math.pi / 2 + 2 * math.pi * k / tube
        prof.append((R + a * math.cos(t), a * math.sin(t)))
        nrm.append((math.cos(t), math.sin(t)))
    return lathe(prof, seg, a0, a1, normals=nrm)


def _rb_coords(h, r, steps):
    base = h - r
    vals = [base + r * math.tan(math.radians(45.0 * k / steps)) for k in range(steps + 1)]
    neg = [-v for v in reversed(vals)]
    if base < 1e-6:
        return neg[:-1] + vals
    return neg + vals


def rounded_box(sx, sy, sz, r, steps=3):
    """Box centred on the origin with every edge rounded by radius r."""
    h = (sx / 2.0, sy / 2.0, sz / 2.0)
    r = max(1e-4, min(r, h[0], h[1], h[2]))
    coords = [_rb_coords(h[i], r, steps) for i in range(3)]
    lim = [h[i] - r for i in range(3)]
    pos, nrm, idx = [], [], []
    for axis in range(3):
        u, v = [k for k in range(3) if k != axis]
        cu, cv = coords[u], coords[v]
        for sgn in (-1.0, 1.0):
            base = len(pos)
            for a in cu:
                for b in cv:
                    p = [0.0, 0.0, 0.0]
                    p[axis] = sgn * h[axis]
                    p[u] = a
                    p[v] = b
                    inner = [max(-lim[i], min(lim[i], p[i])) for i in range(3)]
                    n = _normalize((p[0] - inner[0], p[1] - inner[1], p[2] - inner[2]))
                    pos.append((inner[0] + n[0] * r, inner[1] + n[1] * r, inner[2] + n[2] * r))
                    nrm.append(n)
            nv = len(cv)
            for i in range(len(cu) - 1):
                for j in range(nv - 1):
                    a = base + i * nv + j
                    b = a + nv
                    idx += (a, b, b + 1, a, b + 1, a + 1)
    g = Geo(pos, nrm, idx)
    g.fix_winding()
    return g


def quad(sx, sz):
    """Flat upward-facing rectangle centred on the origin."""
    x, z = sx / 2.0, sz / 2.0
    pos = [(-x, 0.0, -z), (x, 0.0, -z), (x, 0.0, z), (-x, 0.0, z)]
    g = Geo(pos, [(0.0, 1.0, 0.0)] * 4, [0, 1, 2, 0, 2, 3])
    g.fix_winding()
    return g
