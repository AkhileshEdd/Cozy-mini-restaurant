"""The café palette, taken from the art-direction sheet.

Colours are authored in sRGB hex. The glTF writer converts them to linear
values, which is what the format stores and what Godot expects on import.
"""

PALETTE = {
    # neutrals
    "cream": "FFF6EC",
    "white": "FFFFFF",
    "offwhite": "FFF8EE",
    "linen": "F3E6D8",
    "cocoa": "4A3530",
    "eye": "3A2C2A",
    "charcoal": "5A4A48",
    "steel": "D8D8E0",
    "stone": "E6DDD3",
    # wood
    "wood": "E8B98A",
    "wood_mid": "D9A273",
    "wood_light": "F0C9A0",
    "wood_dark": "C98E62",
    "trunk": "A8704A",
    # walls
    "peach": "FAD7C0",
    "peach_light": "FDE4D3",
    "peach_dark": "F7C4A8",
    # accents
    "ginger": "F4A259",
    "ginger_dark": "E08E45",
    "strawberry": "F48FA0",
    "strawberry_dark": "E07A8C",
    "pink_light": "F9B8C8",
    "pink_inner": "F7B8C4",
    "blush": "F48FA0",
    "tomato": "E8665A",
    "tomato_dark": "C94F45",
    "butter": "FFD66B",
    "butter_dark": "F2C14E",
    "mint": "9ED9B8",
    "mint_dark": "6FAF8E",
    "mint_light": "C9EEDB",
    "sky": "9CCBEB",
    "sky_dark": "7AB3DB",
    "sky_light": "DCEFFA",
    "lavender": "C6B4E8",
    "lavender_dark": "A994D6",
    "lavender_light": "E3D9F5",
    # nature
    "leaf": "7BB86F",
    "leaf_mid": "8FCB7E",
    "leaf_light": "9ED98A",
    "grass": "A8D88A",
    "grass_dark": "8CC474",
    "dirt": "B98A68",
    "dirt_dark": "9A6E52",
    "terracotta": "E08E6A",
    "terracotta_dark": "C9745A",
    # characters
    "bunny": "F6EEE8",
    "bunny_feet": "EDE1D8",
    "bear": "C58B5E",
    "bear_dark": "A8704A",
    "bear_muzzle": "EBC9A6",
    "frog": "93CE7B",
    "chick": "FFD85E",
    "chick_wing": "F7C948",
    "beak": "F29A4A",
    "panda": "F8F5F0",
    "panda_dark": "3E3844",
    # food
    "coffee": "7A4B35",
    "foam": "F3DFC5",
    "sponge": "FFE3A8",
    "berry": "E8505B",
    "pancake": "E8B070",
    "pancake_light": "EDBA7C",
    "syrup": "B8672E",
    "butter_pat": "FFE680",
    "soup": "F2A65A",
    "gold": "FFC94A",
    "gold_dark": "E0A93A",
    "cloud": "8E8699",
    "cloud_dark": "6F6878",
    # light sources
    "glow": "FFC27A",
    "bulb": "FFF1B8",
    "glass": "DCEFFA",
}

# Per-material overrides: roughness, emissive strength, alpha.
MATERIAL_PROPS = {
    "steel": {"roughness": 0.35, "metallic": 0.2},
    "coffee": {"roughness": 0.3},
    "syrup": {"roughness": 0.25},
    "soup": {"roughness": 0.35},
    "berry": {"roughness": 0.35},
    "eye": {"roughness": 0.25},
    "gold": {"roughness": 0.3, "metallic": 0.35},
    "gold_dark": {"roughness": 0.35, "metallic": 0.35},
    "glow": {"emissive": 1.4},
    "bulb": {"emissive": 1.8},
    "glass": {"roughness": 0.1, "alpha": 0.55},
    "sky_light": {"roughness": 0.3},
}


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(name):
    h = PALETTE[name]
    return tuple(int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def linear_rgb(name):
    return tuple(srgb_to_linear(c) for c in rgb(name))
