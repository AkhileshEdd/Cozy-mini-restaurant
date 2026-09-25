#!/usr/bin/env python3
"""Generate every 3D model of Cozy Mini Restaurant as a .glb file.

    python3 tools/asset_forge/build.py              # all models
    python3 tools/asset_forge/build.py chef_cat room

Output goes to assets/models/. Only the Python standard library is needed.
"""

import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from forge.gltf import write_glb  # noqa: E402
from models import characters, food, furniture, kitchen, room  # noqa: E402

OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))

REGISTRY = {}
for module in (characters, food, kitchen, furniture, room):
    REGISTRY.update(module.MODELS)


def main(names):
    os.makedirs(OUT, exist_ok=True)
    names = names or sorted(REGISTRY)
    unknown = [n for n in names if n not in REGISTRY]
    if unknown:
        sys.exit("unknown model(s): %s\nknown: %s" % (", ".join(unknown), ", ".join(sorted(REGISTRY))))
    total = 0
    for name in names:
        t0 = time.time()
        stats = write_glb(REGISTRY[name](), os.path.join(OUT, name + ".glb"))
        total += stats["triangles"]
        print("%-16s %6d tris %5d verts %2d materials  %.2fs" % (name, stats["triangles"], stats["vertices"], stats["materials"], time.time() - t0))
    print("%d models, %d triangles -> %s" % (len(names), total, OUT))


if __name__ == "__main__":
    main(sys.argv[1:])
