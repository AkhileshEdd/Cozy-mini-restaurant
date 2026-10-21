#!/usr/bin/env python3
"""Builds the Google Play graphics in docs/store/ from the game's own art.

Run tools/godot/store_shots.tscn first (it renders docs/store/screenshots/).

    python3 tools/store_graphics.py

Needs Pillow.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
STORE = ROOT / "docs" / "store"
SHOTS = STORE / "screenshots"
FONTS = ROOT / "assets" / "fonts"
PEACH = (250, 215, 192, 255)
INK = (74, 53, 48, 255)
INK_SOFT = (107, 80, 72, 255)
TOMATO = (201, 79, 69, 255)


def icon_512() -> None:
    """Play wants a full square; it applies its own rounded mask."""
    icon = Image.open(ROOT / "assets" / "icons" / "icon_1024.png").convert("RGBA")
    square = Image.new("RGBA", icon.size, PEACH)
    square.alpha_composite(icon)
    square.resize((512, 512), Image.LANCZOS).save(STORE / "icon_512.png", optimize=True)


def feature_graphic() -> None:
    w, h = 1024, 500
    img = Image.new("RGBA", (w, h), PEACH)
    d = ImageDraw.Draw(img)
    for x, y, r, c in [(60, 450, 90, (253, 230, 234)), (470, 30, 60, (255, 243, 204)), (400, 480, 40, (228, 245, 236))]:
        d.ellipse((x - r, y - r, x + r, y + r), fill=c + (255,))

    cafe = Image.open(SHOTS / "phone_1_cafe.png").convert("RGBA").crop((0, 170, 1080, 1080))
    cafe = cafe.resize((round(cafe.width * 470 / cafe.height), 470), Image.LANCZOS)
    x0, y0 = w - cafe.width - 15, 15
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x0 + 4, y0 + 8, x0 + cafe.width + 4, y0 + cafe.height + 8), radius=36, fill=(74, 53, 48, 60))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(8)))
    mask = Image.new("L", cafe.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, cafe.width - 1, cafe.height - 1), radius=36, fill=255)
    img.paste(cafe, (x0, y0), mask)

    icon = Image.open(ROOT / "assets" / "icons" / "icon_1024.png").convert("RGBA").resize((150, 150), Image.LANCZOS)
    img.alpha_composite(icon, (40, 40))
    title = ImageFont.truetype(str(FONTS / "Fredoka-SemiBold.ttf"), 62)
    tagline = ImageFont.truetype(str(FONTS / "Fredoka-Medium.ttf"), 30)
    d = ImageDraw.Draw(img)
    d.text((40, 215), "Cozy Mini", font=title, fill=INK)
    d.text((40, 285), "Restaurant", font=title, fill=TOMATO)
    d.text((42, 375), "Cook · Serve · Decorate", font=tagline, fill=INK_SOFT)
    img.convert("RGB").save(STORE / "feature_graphic.png", optimize=True)


def preview() -> None:
    """A small strip of the screenshots for the README."""
    shots = sorted(SHOTS.glob("phone_*.png"))
    tw, th, gap = 240, 427, 12
    strip = Image.new("RGB", (len(shots) * (tw + gap) + gap, th + 2 * gap), PEACH[:3])
    for i, path in enumerate(shots):
        strip.paste(Image.open(path).convert("RGB").resize((tw, th), Image.LANCZOS), (gap + i * (tw + gap), gap))
    strip.save(SHOTS / "preview.png", optimize=True)


if __name__ == "__main__":
    icon_512()
    feature_graphic()
    preview()
    print("wrote", ", ".join(p.name for p in [STORE / "icon_512.png", STORE / "feature_graphic.png", SHOTS / "preview.png"]))
