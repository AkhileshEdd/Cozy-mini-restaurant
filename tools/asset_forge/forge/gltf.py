"""Minimal binary glTF 2.0 (.glb) writer for forge scenes."""

import json
import struct

from .geom import Geo
from .palette import MATERIAL_PROPS, linear_rgb

ARRAY_BUFFER = 34962
ELEMENT_ARRAY_BUFFER = 34963
FLOAT = 5126
UNSIGNED_SHORT = 5123
UNSIGNED_INT = 5125


class _Buffer:
    def __init__(self):
        self.data = bytearray()
        self.views = []
        self.accessors = []

    def _view(self, blob, target):
        while len(self.data) % 4:
            self.data.append(0)
        offset = len(self.data)
        self.data += blob
        self.views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(blob), "target": target})
        return len(self.views) - 1

    def vec3(self, values, with_bounds=False):
        blob = b"".join(struct.pack("<3f", *v) for v in values)
        acc = {"bufferView": self._view(blob, ARRAY_BUFFER), "componentType": FLOAT, "count": len(values), "type": "VEC3"}
        if with_bounds:
            acc["min"] = [min(v[i] for v in values) for i in range(3)]
            acc["max"] = [max(v[i] for v in values) for i in range(3)]
        self.accessors.append(acc)
        return len(self.accessors) - 1

    def indices(self, idx, vertex_count):
        if vertex_count < 65536:
            blob, ctype = struct.pack("<%dH" % len(idx), *idx), UNSIGNED_SHORT
        else:
            blob, ctype = struct.pack("<%dI" % len(idx), *idx), UNSIGNED_INT
        view = self._view(blob, ELEMENT_ARRAY_BUFFER)
        self.accessors.append({"bufferView": view, "componentType": ctype, "count": len(idx), "type": "SCALAR"})
        return len(self.accessors) - 1


def _material(name):
    props = MATERIAL_PROPS.get(name, {})
    r, g, b = linear_rgb(name)
    mat = {
        "name": name,
        "pbrMetallicRoughness": {
            "baseColorFactor": [r, g, b, props.get("alpha", 1.0)],
            "metallicFactor": props.get("metallic", 0.0),
            "roughnessFactor": props.get("roughness", 0.8),
        },
    }
    if "emissive" in props:
        k = props["emissive"]
        mat["emissiveFactor"] = [min(1.0, r * k), min(1.0, g * k), min(1.0, b * k)]
    if "alpha" in props:
        mat["alphaMode"] = "BLEND"
    return mat


def write_glb(root, path):
    buf = _Buffer()
    materials, mat_index = [], {}
    meshes, nodes = [], []
    stats = {"triangles": 0, "vertices": 0}

    def mat_id(name):
        if name not in mat_index:
            mat_index[name] = len(materials)
            materials.append(_material(name))
        return mat_index[name]

    def emit(node):
        entry = {"name": node.name}
        if any(abs(c) > 1e-9 for c in node.t):
            entry["translation"] = list(node.t)
        if node.parts:
            prims = []
            for mat_name in sorted(node.parts):
                geo = Geo.merge(node.parts[mat_name])
                if not geo.idx:
                    continue
                prims.append(
                    {
                        "attributes": {"POSITION": buf.vec3(geo.pos, True), "NORMAL": buf.vec3(geo.nrm)},
                        "indices": buf.indices(geo.idx, len(geo.pos)),
                        "material": mat_id(mat_name),
                        "mode": 4,
                    }
                )
                stats["triangles"] += len(geo.idx) // 3
                stats["vertices"] += len(geo.pos)
            if prims:
                meshes.append({"name": node.name, "primitives": prims})
                entry["mesh"] = len(meshes) - 1
        index = len(nodes)
        nodes.append(entry)
        kids = [emit(c) for c in node.children]
        if kids:
            entry["children"] = kids
        return index

    root_index = emit(root)
    doc = {
        "asset": {"version": "2.0", "generator": "Cozy Mini Restaurant asset forge"},
        "scene": 0,
        "scenes": [{"name": root.name, "nodes": [root_index]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": buf.accessors,
        "bufferViews": buf.views,
        "buffers": [{"byteLength": len(buf.data)}],
    }
    json_bytes = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    bin_bytes = bytes(buf.data) + b"\x00" * ((4 - len(buf.data) % 4) % 4)
    total = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(json_bytes), b"JSON"))
        f.write(json_bytes)
        f.write(struct.pack("<I4s", len(bin_bytes), b"BIN\x00"))
        f.write(bin_bytes)
    stats["materials"] = len(materials)
    return stats
